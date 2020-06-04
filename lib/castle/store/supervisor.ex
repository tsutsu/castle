defmodule CAStle.Store.Supervisor do
  @moduledoc false
  use Supervisor

  @doc """
  Starts the store supervisor.
  """
  def start_link(store, otp_app, adapter, opts) do
    {:ok, opts} = runtime_config(:supervisor, store, otp_app, opts)

    {:ok, config, maybe_child_spec} = adapter.init(:process, [store: store] ++ opts)

    child_specs = case maybe_child_spec do
      nil -> []
      spec -> [spec]
    end

    config = Map.merge(config, %{store: store})

    store_struct = %CAStle.Store{adapter: adapter, config: config, state: nil}

    reg_key = {:via, Registry, {CAStle.Store.Registry, store, store_struct}}

    Supervisor.start_link(__MODULE__, child_specs, [name: reg_key])
  end

  @doc false
  def init(child_specs) do
    Supervisor.init(child_specs, strategy: :one_for_one, max_restarts: 0)
  end

  @doc """
  Retrieves the compile time configuration.
  """
  def compile_config(_store, opts) do
    otp_app = Keyword.fetch!(opts, :otp_app)
    adapter = opts[:adapter]

    unless adapter do
      raise ArgumentError, "missing :adapter option on use CAStle.Store"
    end

    with {:error, _} <- Code.ensure_compiled(adapter) do
      raise ArgumentError, "adapter #{inspect adapter} was not compiled, " <>
                           "ensure it is correct and it is included as a project dependency"
    end

    behaviours =
      for {:behaviour, behaviours} <- adapter.__info__(:attributes),
          behaviour <- behaviours,
          do: behaviour

    unless CAStle.Adapter in behaviours do
      raise ArgumentError,
            "expected :adapter option given to CAStle.Store to list CAStle.Adapter as a behaviour"
    end

    {otp_app, adapter, behaviours}
  end

  @doc """
  Retrieves the runtime configuration.
  """
  def runtime_config(type, store, otp_app, opts) do
    config = Application.get_env(otp_app, store, [])
    config = [otp_app: otp_app] ++ Keyword.merge(config, opts)
    store_init(type, store, config)
  end

  defp store_init(type, store, config) do
    if Code.ensure_loaded?(store) and function_exported?(store, :init, 2) do
      store.init(type, config)
    else
      {:ok, config}
    end
  end
end
