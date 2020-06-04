defmodule CAStle.Adapter.Heap do
  @behaviour CAStle.Adapter

  @impl true
  def init(:struct, _opts), do: {:ok, %{}, %{}}

  @impl true
  def fetch(_config, m, k), do:
    Map.fetch(m, k)

  @impl true
  def put(_config, m, k, v), do:
    Map.put(m, k, v)

  @impl true
  def pop(_config, m, k), do:
    Map.pop(m, k)

  @impl true
  def delete(_config, m, k), do:
    Map.delete(m, k)

  @impl true
  def member?(_config, m, k), do:
    Map.has_key?(m, k)

  @impl true
  def stream_objects(_config, m), do:
    Stream.map(m, &elem(&1, 1))

  @impl true
  def stream_hashes(config, m) do
    stream_objects(config, m)
    |> Stream.map(&Map.fetch!(&1, :hash))
  end

  @impl true
  def clear(_config, _m), do:
    %{}
end
