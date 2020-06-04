defmodule CAStle.Adapter.RocksDB do
  @behaviour CAStle.Adapter

  @impl true
  def init(mode, opts \\ []) when mode in [:struct, :process] do
    db_path =
      Keyword.fetch!(opts, :path)
      |> String.to_charlist()

    {:ok, db} = :rocksdb.open(db_path, [create_if_missing: true])
    {:ok, %{db: db}, nil}
  end

  @impl true
  def fetch(%{db: db}, nil, k) do
    case :rocksdb.get(db, k, []) do
      {:ok, enc_obj} ->
        {:ok, decode_object(enc_obj)}
      :not_found ->
        :error
      {:error, other_err} ->
        raise RuntimeError, "RocksDB error: #{inspect(other_err)}"
    end
  end

  @impl true
  def put(%{db: db}, nil, k, v), do:
    :rocksdb.put(db, k, encode_object(v), [])

  @impl true
  def pop(%{db: db}, nil, k) do
    prev = case fetch(db, nil, k) do
      {:ok, val} -> val
      :error -> nil
    end
    :rocksdb.delete(db, k, [])
    {prev, nil}
  end

  @impl true
  def delete(%{db: db}, nil, k) do
    :rocksdb.delete(db, k, [])
    nil
  end

  @impl true
  def member?(%{db: db}, nil, k) do
    case :rocksdb.get(db, k, []) do
      {:ok, _enc_obj} ->
        true
      :not_found ->
        false
      {:error, other_err} ->
        raise RuntimeError, "RocksDB error: #{inspect(other_err)}"
    end
  end

  @impl true
  def stream_objects(%{db: db}, nil) do
    Stream.resource(
      fn ->
        {:ok, snap} = :rocksdb.snapshot(db)
        {:ok, it} = :rocksdb.iterator(db, [snapshot: snap])
        {snap, it, :first}
      end,
      fn {snap, it, it_op} ->
        case :rocksdb.iterator_move(it, it_op) do
          {:ok, _k, enc_obj} ->
            {[decode_object(enc_obj)], {snap, it, :next}}
          {:error, :invalid_iterator} ->
            {:halt, {snap, it, nil}}
          {:error, :iterator_closed} ->
            {:halt, {snap, it, nil}}
        end
      end,
      fn {snap, it, _} ->
        :rocksdb.iterator_close(it)
        :rocksdb.release_snapshot(snap)
      end
    )
  end

  @impl true
  def stream_hashes(config, m) do
    stream_objects(config, m)
    |> Stream.map(&Map.fetch!(&1, :hash))
  end

  @impl true
  def clear(%{db: db}, nil) do
    batch = :rocksdb.fold_keys(db, &[{:delete, &1} | &2], [], [])
    :rocksdb.write(db, batch, [])
    nil
  end


  defp encode_object(%CAStle.Object{hash: h, content: c}), do:
    :erlang.term_to_binary({h, c})

  defp decode_object(bin) when is_binary(bin) do
    {h, c} = :erlang.binary_to_term(bin)
    %CAStle.Object{hash: h, content: c}
  end
end
