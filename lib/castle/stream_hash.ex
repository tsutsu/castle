defmodule CAStle.StreamHash do
  defstruct [:bits]

  def new(%__MODULE__{} = h), do: h
  def new(rb) when is_bitstring(rb) and bit_size(rb) >= 1, do: %__MODULE__{bits: rb}

  def new_from_hex("0x" <> hb), do: new_from_hex(hb)

  def new_from_hex(hb) when is_binary(hb) and rem(byte_size(hb), 2) == 0,
    do: %__MODULE__{bits: Base.decode16!(hb, case: :mixed)}
end

defimpl CAStle.StorageKey, for: CAStle.StreamHash do
  def to_binary_key(%CAStle.StreamHash{bits: bits}) when is_binary(bits), do: {:ok, bits}
  def to_binary_key(%CAStle.StreamHash{}), do: :error

  def to_tuple_key(%CAStle.StreamHash{} = hash), do: to_binary_key(hash)
end

defimpl String.Chars, for: CAStle.StreamHash do
  def to_string(%CAStle.StreamHash{} = hash), do: CAStle.Hash.to_string(hash)
end

defimpl Inspect, for: CAStle.StreamHash do
  def inspect(%CAStle.StreamHash{} = hash, opts), do: CAStle.Hash.__inspect_impl(hash, opts)
end
