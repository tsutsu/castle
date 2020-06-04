defmodule CAStle.Stream do
  defstruct bytes: <<>>,
            hash: nil

  alias CAStle.StreamHash

  def new(bin, hash \\ nil)
  def new(bin, nil) when is_binary(bin), do: %__MODULE__{bytes: bin}

  def new(bin, hash) when is_binary(bin) and is_binary(hash),
    do: %__MODULE__{bytes: bin, hash: StreamHash.new(hash)}

  def new(bin, %StreamHash{} = hash) when is_binary(bin),
    do: %__MODULE__{bytes: bin, hash: hash}

  def with_hash(%__MODULE__{hash: %StreamHash{}} = blob, _hasher), do: blob

  def with_hash(%__MODULE__{hash: nil, bytes: bin} = blob, hasher),
    do: %__MODULE__{blob | hash: StreamHash.new(hasher.(bin))}
end
