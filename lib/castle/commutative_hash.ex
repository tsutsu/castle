defmodule CAStle.CommutativeHash do
  require Bitwise
  import CAStle.Hash, only: [defmagic: 1]

  defmagic("CommHash")

  defstruct [:bit_width, :modulus, value: 0]

  def new(bit_width) when is_integer(bit_width) and bit_width >= 1 do
    modulus = Bitwise.bsl(1, bit_width)
    %__MODULE__{bit_width: bit_width, modulus: modulus}
  end

  def add(%__MODULE__{bit_width: bw, modulus: m, value: a} = state, %__MODULE__{
        bit_width: bw,
        modulus: m,
        value: b
      }),
      do: %__MODULE__{state | value: add_with_wrap(m, a, b)}

  def add(%__MODULE__{} = state, b) when is_binary(b), do: add(state, :binary.decode_unsigned(b))

  def add(%__MODULE__{modulus: m, value: a} = state, b) when is_integer(b) and b >= 0,
    do: %__MODULE__{state | value: add_with_wrap(m, a, b)}

  def sub(%__MODULE__{bit_width: bw, modulus: m, value: a} = state, %__MODULE__{
        bit_width: bw,
        modulus: m,
        value: b
      }),
      do: %__MODULE__{state | value: sub_with_wrap(m, a, b)}

  def sub(%__MODULE__{} = state, b) when is_binary(b), do: sub(state, :binary.decode_unsigned(b))

  def sub(%__MODULE__{modulus: m, value: a} = state, b) when is_integer(b) and b >= 0,
    do: %__MODULE__{state | value: sub_with_wrap(m, a, b)}

  defp add_with_wrap(m, a, b) do
    rem(a + b, m)
  end

  defp sub_with_wrap(m, a, b) when b <= m do
    rem(a - b + m, m)
  end
end

defimpl CAStle.StorageKey, for: CAStle.CommutativeHash do
  require Bitwise
  alias CAStle.CommutativeHash

  def to_binary_key(%CommutativeHash{bit_width: sz, value: v}) when rem(sz, 8) == 0 do
    mangled_v = Bitwise.bxor(v, CommutativeHash.magic(sz))
    <<mangled_v::size(sz)>>
  end
  def to_binary_key(%CommutativeHash{}), do: :error

  def to_tuple_key(%CommutativeHash{} = chash), do:
    to_binary_key(chash)
end

defimpl Collectable, for: CAStle.CommutativeHash do
  alias CAStle.CommutativeHash

  def into(%CommutativeHash{} = state), do: {state, &collector/2}

  defp collector(acc, cmd)

  defp collector(state, {:cont, %CommutativeHash{} = v}),
    do: CommutativeHash.add(state, v)

  defp collector(state, {:cont, v}) when is_binary(v) or (is_integer(v) and v >= 0),
    do: CommutativeHash.add(state, v)

  defp collector(state, :done), do: state
  defp collector(_acc, :halt), do: :ok
end

defimpl String.Chars, for: CAStle.CommutativeHash do
  def to_string(%CAStle.CommutativeHash{} = hash), do: CAStle.Hash.to_string(hash)
end

defimpl Inspect, for: CAStle.CommutativeHash do
  def inspect(%CAStle.CommutativeHash{} = hash, opts),
    do: CAStle.Hash.__inspect_impl(hash, opts)
end
