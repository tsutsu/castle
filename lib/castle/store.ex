defmodule CAStle.Store do
  defstruct [:adapter, :config, :state]

  @typep access_key :: binary() | nil

  @callback fetch(CAStle.Hash.t()) :: {:ok, CAStle.Object.committed_t()} | :error
  @callback get_and_update(CAStle.Hash.t(), Access.get_and_update_fun(access_key(), CAStle.Object.committed_t())) :: {access_key(), CAStle.Object.committed_t()}
  @callback pop(CAStle.Hash.t()) :: CAStle.Object.committed_t() | nil
  @callback insert(CAStle.Object.t()) :: CAStle.Object.committed_t()
  @callback put(CAStle.Object.t()) :: :ok
  @callback delete(CAStle.Object.t()) :: :ok
  @callback member?(CAStle.Object.t()) :: boolean()
  @callback has_key?(CAStle.Hash.t() | access_key()) :: boolean()
  @callback objects() :: Enumerable.t()
  @callback manifest() :: Enumerable.t()
  @callback clear() :: :ok

  @doc false
  defmacro __using__(opts) do
    quote(location: :keep, bind_quoted: [opts: opts]) do
      @behaviour CAStle.Store

      {otp_app, adapter, behaviours} =
        CAStle.Store.Supervisor.compile_config(__MODULE__, opts)

      @otp_app otp_app
      @adapter adapter
      @read_only opts[:read_only] || false

      def config do
        {:ok, config} = CAStle.Store.Supervisor.runtime_config(:runtime, __MODULE__, @otp_app, [])
        config
      end

      def __adapter__, do: @adapter

      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]},
          type: :supervisor
        }
      end

      def start_link(opts \\ []) do
        CAStle.Store.Supervisor.start_link(__MODULE__, @otp_app, @adapter, opts)
      end

      def stop(timeout \\ 5000) do
        Supervisor.stop(__MODULE__, :normal, timeout)
      end

      @compile inline: [get_store: 0]
      defp get_store do
        [{_pid, store}] = Registry.lookup(CAStle.Store.Registry, __MODULE__)
        store
      end

      def fetch(hash) do
        CAStle.Store.fetch(get_store(), hash)
      end

      def get_and_update(hash, value_fn) do
        {obj, _state} = CAStle.Store.get_and_update(get_store(), hash, value_fn)
        obj
      end

      def pop(hash) do
        {obj, _state} = CAStle.Store.pop(get_store(), hash)
        obj
      end

      def insert(new_obj) do
        {obj, _state} = CAStle.Store.insert(get_store(), new_obj)
        obj
      end

      def put(new_obj) do
        CAStle.Store.put(get_store(), new_obj)
        :ok
      end

      def delete(obj_or_content) do
        CAStle.Store.delete(get_store(), obj_or_content)
        :ok
      end

      def member?(obj_or_content) do
        CAStle.Store.member?(get_store(), obj_or_content)
      end

      def has_key?(hash_or_key) do
        CAStle.Store.delete(get_store(), hash_or_key)
      end

      def objects do
        CAStle.Store.objects(get_store())
      end

      def manifest do
        CAStle.Store.manifest(get_store())
      end

      def clear do
        CAStle.Store.clear(get_store())
        :ok
      end
    end
  end



  def new(opts \\ []) do
    {adapter_module, adapter_config} =
      Keyword.pop(opts, :adapter, CAStle.Adapter.Heap)

    {:ok, adapter_config, adapter_state0} =
      adapter_module.init(:struct, adapter_config)

    %__MODULE__{
      adapter: adapter_module,
      config: adapter_config,
      state: adapter_state0
    }
  end

  @behaviour Access
  def fetch(%__MODULE__{adapter: adapter, config: config, state: state}, hash) do
    key = CAStle.Hash.to_binary_key!(hash)
    adapter.fetch(config, state, key)
  end

  def get_and_update(%__MODULE__{adapter: adapter, config: config, state: state0} = store, hash, value_fn) do
    key = CAStle.Hash.to_binary_key!(hash)
    get_result = case adapter.fetch(config, state0, key) do
      {:ok, result} -> result
      :error -> nil
    end

    case value_fn.(get_result) do
      {existing_obj, new_content} ->
        hashed_new_obj =
          CAStle.Object.wrap(new_content)
          |> CAStle.Object.commit!()

        case should_overwrite(existing_obj, hashed_new_obj) do
          :ok ->
            state1 = adapter.put(config, state0, key, hashed_new_obj)
            {hashed_new_obj, %__MODULE__{store | state: state1}}

          {:collision, h1, h2} ->
            raise ArgumentError, "hash mismatch: #{inspect(h1)} and #{inspect(h2)}"
        end

      :pop ->
        {obj, state1} = adapter.pop(config, state0, key)
        {obj, %__MODULE__{store | state: state1}}
    end
  end

  defp should_overwrite(nil, %CAStle.Object{}), do: :ok
  defp should_overwrite(%CAStle.Object{hash: h}, %CAStle.Object{hash: h}), do: :ok
  defp should_overwrite(%CAStle.Object{hash: h1}, %CAStle.Object{hash: h2}), do: {:collision, h1, h2}

  def pop(%__MODULE__{adapter: adapter, config: config, state: state0} = store, hash) do
    key = CAStle.Hash.to_binary_key!(hash)
    {obj, state1} = adapter.pop(config, state0, key)
    {obj, %__MODULE__{store | state: state1}}
  end

  def insert(%__MODULE__{adapter: adapter, config: config, state: state0} = store, %CAStle.Object{hash: nil} = new_obj) do
    hashed_obj = CAStle.Object.commit!(new_obj)
    key = CAStle.Hash.to_binary_key!(hashed_obj.hash)
    state1 = adapter.put(config, state0, key, hashed_obj)
    {hashed_obj, %__MODULE__{store | state: state1}}
  end

  def insert(%__MODULE__{}, %CAStle.Object{hash: h}) when h != nil, do:
    raise ArgumentError, "unwilling to insert untrusted pre-hashed Object"

  def insert(%__MODULE__{} = store, new_content), do:
    insert(store, CAStle.Object.new(new_content))

  def put(%__MODULE__{} = store0, new_obj_or_content) do
    {_hashed_obj, store1} = insert(store0, new_obj_or_content)
    store1
  end

  def delete(%__MODULE__{adapter: adapter, config: config, state: state0} = store, %CAStle.Object{hash: hash}) when hash != nil do
    key = CAStle.Hash.to_binary_key!(hash)
    state1 = adapter.delete(config, state0, key)
    %__MODULE__{store | state: state1}
  end

  def delete(%__MODULE__{} = store, %CAStle.Object{hash: nil} = new_obj) do
    hashed_obj = CAStle.Object.commit!(new_obj)
    delete(store, hashed_obj)
  end

  def delete(%__MODULE__{} = store, new_content), do:
    delete(store, CAStle.Object.new(new_content))


  def member?(%__MODULE__{adapter: adapter, config: config, state: state}, %CAStle.Object{hash: hash}) when hash != nil do
    key = CAStle.Hash.to_binary_key!(hash)
    adapter.member?(config, state, key)
  end

  def member?(%__MODULE__{} = store, %CAStle.Object{hash: nil} = obj) do
    hashed_obj = CAStle.Object.commit!(obj)
    member?(store, hashed_obj)
  end

  def has_key?(%__MODULE__{adapter: adapter, config: config, state: state}, key) when is_binary(key), do:
    adapter.member?(config, state, key)
  def has_key?(%__MODULE__{} = store, hash), do:
    has_key?(store, CAStle.Hash.to_binary_key!(hash))

  def objects(%__MODULE__{adapter: adapter, config: config, state: state}), do:
    adapter.stream_objects(config, state)

  def manifest(%__MODULE__{adapter: adapter, config: config, state: state}) do
    adapter.stream_hashes(config, state)
    |> CAStle.Manifest.new_from_hashes()
  end

  def clear(%__MODULE__{adapter: adapter, config: config, state: state}), do:
    adapter.clear(config, state)
end

defimpl Collectable, for: CAStle.Store do
  alias CAStle.Store

  def into(%Store{} = store), do: {store, &collector/2}

  defp collector(acc, cmd)

  defp collector(store, {:cont, new_obj_or_content}),
    do: Store.put(store, new_obj_or_content)

  defp collector(store, :done), do: store
  defp collector(_acc, :halt), do: :ok
end
