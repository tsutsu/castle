defprotocol CAStle.StorageKey do
  def to_tuple_key(hash)
  def to_binary_key(hash)
end

defimpl CAStle.StorageKey, for: BitString do
  def to_binary_key(b) when is_binary(b), do: {:ok, b}
  def to_binary_key(b) when is_bitstring(b) and not is_binary(b), do: :error

  def to_tuple_key(b), do: to_binary_key(b)
end
