defmodule CAStle.Hash do
  @type t :: any()

  def from(obj_or_content) do
    with obj <- CAStle.Object.wrap(obj_or_content),
         {:ok, hashed_obj} <- CAStle.Object.commit(obj) do
      {:ok, hashed_obj.hash}
    else _ ->
      :error
    end
  end

  def from!(obj_or_content) do
    case from(obj_or_content) do
      {:ok, hash} ->
        hash
      :error ->
        raise ArgumentError, "not Hashable: #{inspect(obj_or_content)}"
    end
  end

  def sigil_H(string, []), do: from!(string)
  def sigil_H(hex_string, [?r]), do:
    %CAStle.StreamHash{bits: Base.decode16!(hex_string, case: :mixed)}

  defmacro __using__(_opts) do
    quote do
      import CAStle.Hash, only: [sigil_H: 2]
    end
  end

  defdelegate to_binary_key(hash), to: CAStle.StorageKey
  defdelegate to_tuple_key(hash), to: CAStle.StorageKey

  def to_binary_key!(hash) do
    case CAStle.StorageKey.to_binary_key(hash) do
      {:ok, bin} -> bin
      :error -> raise ArgumentError, "cannot compute storage key: #{inspect(hash)}"
    end
  end

  def to_tuple_key!(hash) do
    case CAStle.StorageKey.to_tuple_key(hash) do
      {:ok, bin} -> bin
      :error -> raise ArgumentError, "cannot compute storage key: #{inspect(hash)}"
    end
  end

  def to_hex(hash, opts \\ []) do
    case CAStle.StorageKey.to_binary_key(hash) do
      {:ok, bin} ->
        root = Base.encode16(bin, opts)

        case Keyword.get(opts, :prefix, true) do
          true -> {:ok, "0x" <> root}
          false -> {:ok, root}
        end

      :error ->
        :error
    end
  end

  def to_hex!(hash, opts \\ []) do
    case to_hex(hash, opts) do
      {:ok, bin} -> bin
      :error -> raise ArgumentError, "cannot compute storage key: #{inspect(hash)}"
    end
  end

  @doc false
  defmacro defmagic(xor_value) do
    quote do
      magic_xor_value = unquote(xor_value)

      unabridged_magic =
        magic_xor_value <> String.duplicate(<<0>>, 64 - byte_size(magic_xor_value))

      for bit_width <- 1..512 do
        discard_bits =
          case rem(bit_width, 8) do
            0 -> 0
            n -> 8 - n
          end

        <<cut_magic::big-integer-size(bit_width), _::integer-size(discard_bits), _::binary>> =
          unabridged_magic

        @__bit_width bit_width
        @__cut_magic cut_magic
        @doc false
        def magic(@__bit_width), do: @__cut_magic
      end
    end
  end

  def to_string(hash) do
    case to_hex(hash, case: :lower, prefix: false) do
      {:ok, val} ->
        val

      :error ->
        raise ArgumentError, "cannot represent bitstring as hex"
    end
  end

  import Inspect.Algebra

  @doc false
  def __inspect_impl(hash, opts) do
    case to_hex(hash, prefix: false, case: :lower) do
      {:ok, hash_hex} ->
        concat([
          color("♯", :string, opts),
          maybe_elide_hex(hash_hex, opts)
        ])

      :error ->
        to_doc(hash, opts ++ [structs: false])
    end
  end

  if Mix.env() == :prod do
    defp maybe_elide_hex(hash_hex, opts) when byte_size(hash_hex) >= 16 do
      sz = byte_size(hash_hex)
      hash_start = String.slice(hash_hex, 0..1)
      hash_end = String.slice(hash_hex, (sz - 11)..(sz - 1))

      concat([
        color(hash_start, :string, opts),
        color("...", :string, opts),
        color(hash_end, :string, opts)
      ])
    end
  end

  defp maybe_elide_hex(hash_hex, opts) do
    color(hash_hex, :string, opts)
  end
end
