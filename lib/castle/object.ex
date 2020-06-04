defmodule CAStle.Object do
  defstruct [:content, hash: nil]

  @opaque t() :: %__MODULE__{content: any(), hash: nil}
  @opaque committed_t() :: %__MODULE__{content: any(), hash: any()}

  def new(content) when content != nil,
    do: %__MODULE__{content: content}

  def wrap(%__MODULE__{} = obj), do: obj
  def wrap(content), do: new(content)

  def commit(%__MODULE__{hash: nil, content: content} = obj) do
    case CAStle.Hashable.hash(content) do
      {:ok, hash} -> {:ok, %__MODULE__{obj | hash: hash}}
      :error -> :error
    end
  end

  def commit!(%__MODULE__{} = obj) do
    case commit(obj) do
      {:ok, obj} ->
        obj

      :error ->
        raise ArgumentError, "not Hashable: #{inspect(obj.content)}"
    end
  end

  def new_committed(content, hash) when content != nil and hash != nil,
    do: %__MODULE__{content: content, hash: hash}
end
