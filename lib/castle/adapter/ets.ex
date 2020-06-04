defmodule CAStle.Adapter.ETS do
  @behaviour CAStle.Adapter

  @default_ets_opts [
    :set,
    :public,
    read_concurrency: true,
    write_concurrency: true
  ]

  @impl true
  def init(mode, opts \\ []) when mode in [:struct, :process] do
    {table_name, ets_opts} = case Keyword.fetch(opts, :table_name) do
      {:ok, name} -> {name, [:named_table]}
      :error -> {:anonymous_table, []}
    end
    ets_opts = ets_opts ++ @default_ets_opts
    table_ref = :ets.new(table_name, ets_opts)


    {:ok, %{tid: table_ref}, nil}
  end

  @impl true
  def fetch(%{tid: tid}, nil, k) do
    case :ets.lookup(tid, k) do
      [{^k, v}] -> {:ok, v}
      [] -> :error
    end
  end

  @impl true
  def put(%{tid: tid}, nil, k, v) do
    :ets.insert(tid, {k, v})
    nil
  end

  @impl true
  def pop(%{tid: tid}, nil, k) do
    case :ets.take(tid, k) do
      [{^k, v}] -> {v, nil}
      [] -> {nil, nil}
    end
  end

  @impl true
  def delete(%{tid: tid}, nil, k) do
    :ets.delete(tid, k)
    nil
  end

  @impl true
  def member?(%{tid: tid}, nil, k) do
    case :ets.select_count(tid, [{{k, :_}, [], [true]}]) do
      0 -> false
      1 -> true
    end
  end

  @stream_chunk_size 100

  @impl true
  def stream_objects(%{tid: tid}, nil) do
    match_spec = [{{:_, :"$1"}, [], [:"$1"]}]
    Stream.resource(
      fn ->
        :ets.safe_fixtable(tid, true)
        :ets.select(tid, match_spec, @stream_chunk_size)
      end,
      fn
        {matches, continuation} ->
          next = :ets.select(continuation)
          {matches, next}
        :"$end_of_table" ->
          {:halt, tid}
      end,
      &:ets.safe_fixtable(&1, false)
    )
  end

  @impl true
  def stream_hashes(config, m) do
    stream_objects(config, m)
    |> Stream.map(&Map.fetch!(&1, :hash))
  end

  @impl true
  def clear(%{tid: tid}, nil) do
    :ets.delete_all_objects(tid)
    nil
  end
end
