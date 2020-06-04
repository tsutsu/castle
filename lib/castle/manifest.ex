defmodule CAStle.Manifest do
  defstruct [:hash, :members]

  alias CAStle.CommutativeHash, as: CommHash

  def new(enum \\ []) do
    Enum.map(enum, &Map.fetch!(&1, :hash))
    |> new_from_hashes()
  end

  def new_from_hashes(enum \\ []) do
    members =
      Map.new(enum, fn hash ->
        key = CAStle.Hash.to_binary_key!(hash)
        {key, hash}
      end)

    hash =
      Enum.map(members, &elem(&1, 0))
      |> Enum.into(CommHash.new(256))

    %__MODULE__{members: members, hash: hash}
  end

  def put(manifest, object)
  def put(%__MODULE__{} = manifest, %{hash: hash}), do: put_hash(manifest, hash)

  def put_hash(%__MODULE__{members: members0, hash: hash0} = manifest, hash) do
    key = CAStle.Hash.to_binary_key!(hash)

    case Map.has_key?(members0, key) do
      true ->
        manifest

      false ->
        members1 = Map.put(members0, key, hash)
        hash1 = CommHash.add(hash0, key)
        %__MODULE__{manifest | members: members1, hash: hash1}
    end
  end

  def delete(manifest, object)
  def delete(%__MODULE__{} = manifest, %{hash: hash}), do: delete_hash(manifest, hash)

  def delete_hash(%__MODULE__{members: members0, hash: hash0} = manifest, hash) do
    key = CAStle.Hash.to_binary_key!(hash)

    case Map.has_key?(members0, key) do
      true ->
        members1 = Map.delete(members0, key)
        hash1 = CommHash.sub(hash0, key)
        %__MODULE__{manifest | members: members1, hash: hash1}

      false ->
        manifest
    end
  end
end
