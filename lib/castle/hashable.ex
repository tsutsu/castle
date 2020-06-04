defprotocol CAStle.Hashable do
  def hash(content)
end

defimpl CAStle.Hashable, for: BitString do
  def hash(bin) when is_binary(bin), do: {:ok, CAStle.StreamHash.new(:crypto.hash(:sha256, bin))}
  def hash(bin) when is_bitstring(bin) and not is_binary(bin), do: :error
end
