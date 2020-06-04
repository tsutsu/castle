# CAStle

CAStle is a Content-Addressable Storage ADT for Elixir.

CAStle doesn't attempt to replicate the semantics of any particular existing
object store, e.g. Git or Amazon S3. Instead, CAStle provides a toolkit of
abstractions for building object stores.


## Usage

You have two options. You can create a `CAStle.Store` directly, e.g.:

```elixir
iex> store = CAStle.Store.new(adapter: CAStle.Adapter.ETS)
iex> obj1 = CAStle.Store.insert_stream(store, "foo")
iex> obj2 = CAStle.Store.fetch(store, obj1.hash)
iex> obj1 == obj2
true
iex> CAStle.Stream.to_binary(obj1)
"foo"
```

Or, you can `use CAStle.Store` in a module of your project, much like you
would `use Ecto.Repo` with Ecto:

```elixir
# in lib/my_app/object_store.ex
defmodule MyApp.ObjectStore do
  use CAStle.Store,
    otp_app: :my_app,
    adapter: CAStle.Adapter.GitObjectsDir

  def init(_type, config) do
    repo_path = System.get_env("GIT_REPO_PATH")
    {:ok, Keyword.put(config, :path, String.join([repo_path, ".git", "objects"])}
  end
end

# then, in your code:
obj = MyApp.ObjectStore.insert_stream("foo")
^obj = MyApp.ObjectStore.fetch(obj.hash)
```


## Content Types

CAStle can hold onto content of arbitrary type. CAStle stores create
`CAStle.Object`s by taking in arbitrary Erlang terms, and then passing them
to the `CAStle.Hashable.hash/1` protocol function to derive a hash for them. To
enable your own structs to be stored into a CAStle store, they just needs to
implement `CAStle.Hashable`.

A content struct can also choose to implement `CAStle.Encoder`, if it wishes to
supply a custom encoding of its contents; but this is usually unnecessary, as
the default (`term_to_binary/1`) encoding serves well as a structural-identity
encoding for *almost* all Erlang terms.


## Storage Adapters

CAStle has various storage adapters:

* **CAStle.Adapter.Heap** — a simple functional-persistent ADT, which you must
  pass between CAStle operations. This is the fastest adapter if your operations
  are private to a single Erlang process, and it also allows you to do clever
  things by holding onto multiple copies of the store. This store is also used
  as an *interchange format* between some CAStle operations.

* **CAStle.Adapter.ETS** — an ADT backed by a collection of anonymous ETS tables,
  much like Erlang's `:digraph` module. This adapter is good for coordination
  between ephemeral Erlang processes on the same node.

* **CAStle.Adapter.ETFs** — an ADT backed by the
  [ETFs](https://hex.pm/packages/etfs) library, which combines ETS tables
  with streaming Erlang [ETF](http://erlang.org/doc/apps/erts/erl_ext_dist.html)
  disk persistence. This adapter is good for the same situations as the ETS
  adapter, with the added benefit of durability between node restarts. This
  adapter exclusively locks its backing ETFs file while open; the file cannot be
  shared between nodes.

* **CAStle.Adapter.GitObjectsDir** — an ADT backed by a directory of
  hash-named files, in the same format as a Git `.git/objects` directory. This
  adapter is good for multi-node coordination; for reducing write amplification
  when small changes are persisted; and, as a bonus, the backing directory can
  be introspected via Git's own plumbing commands. This adapter is *not*
  intended to be used to manipulate existing Git repositories; it has no
  understanding of other Git storage abstractions like packfiles.

* **CAStle.Adapter.RocksDB** — an ADT backed by a RocksDB file on disk. This
  adapter is good for production workloads when one node is acting as a CAS
  server which other nodes query. Very fast, but heavyweight — requires that
  [erlang-rocksdb](https://gitlab.com/barrel-db/erlang-rocksdb) be installed,
  which requires NIF compilation.


## Commutative Hashing and `CAStle.Manifest`

Rather than applying a universal hashing algorithm to a uniform serialization
of objects, CAStle has per-type content hashing strategies.

Among other benefits, this allows CAStle to express types with *setwise identity*
by using a *commutative hash*.

A good example of the usefulness of commutative hashing is BitTorrent. A
BitTorrent "swarm" is a set of nodes polling one-another to exchange *pieces* of
a fileset. Each *piece* is a fixed-size serialized binary holding a
self-contained description of a part of a file in the fileset: the file index,
the position within the file, the length of the content, and the content itself.

Each BitTorrent piece is, thus, *self-describing* — you can recover the sequence
that the pieces belong in simply by having all the pieces themselves, much like
you have all you need to put a jigsaw puzzle back together when you have the
puzzle pieces themselves. Thus, any container data-structure holding the same
set of *pieces* could be said to be semantically equivalent to any other container
data-structure holding the same set. A *commutative hash* allows us to recognize
this property, and deduplicate such data-structures.

To demonstrate concretely:

```elixir
[a, b, c, d] =
  Enum.map(["foo", "bar", "baz", "quux"], &:crypto.hash(:sha256, &1))

c_hash = &Enum.into(&1, CAStle.CommutativeHash.new(256))

c_hash.([a, b, c, d])
# => ♯e8dad82e3b81897297bc9a91195d7172bea04eaa14b125e3c6563678e9c3989f

c_hash.([c_hash.([a, b]), c_hash.([c, d])])
# => ♯e8dad82e3b81897297bc9a91195d7172bea04eaa14b125e3c6563678e9c3989f

c_hash.([c_hash.([a, c]), c_hash.([b, d])])
# => ♯e8dad82e3b81897297bc9a91195d7172bea04eaa14b125e3c6563678e9c3989f

c_hash.([c_hash.([a]), c_hash.([b, c, d])])
# => ♯e8dad82e3b81897297bc9a91195d7172bea04eaa14b125e3c6563678e9c3989f
```

(If you're curious: the *commutative hash* operation is simply addition modulo
the input hash size — that's the `256` in the above.)

CAStle has an object type, `CAStle.Manifest`, which represents this kind of
setwise identity. A Manifest can contain other Manifests, and other object types
(which are treated as leaves); any tree of Manifest objects will hash to a value
unique to the particular leaf objects it contains, regardless of the structure
of the Manifest tree itself.

```elixir
store = CAStle.Store.new(adapter: CAStle.Adapter.ETS)

[obj_a, obj_b, obj_c, obj_d] =
  Enum.map(["foo", "bar", "baz", "quux"], &CAStle.Store.insert(store, &1))

mani_abcd1 = CAStle.Store.manifest(store)

mani_abcd2 = CAStle.Manifest.new([obj_a, obj_b, obj_c, obj_d])

mani_ab = CAStle.Manifest.new([obj_a, obj_b])
mani_cd = CAStle.Manifest.new([obj_c, obj_d])
mani_abcd3 = CAStle.Manifest.new([mani_ab, mani_cd])

mani_ac = CAStle.Manifest.new([obj_a, obj_c])
mani_bd = CAStle.Manifest.new([obj_b, obj_d])
mani_abcd4 = CAStle.Manifest.new([mani_ac, mani_bd])

mani_abc = CAStle.Manifest.new([obj_a, obj_b, obj_c])
mani_d = CAStle.Manifest.new([obj_d])
mani_abcd5 = CAStle.Manifest.new([mani_abc, mani_d])

[abcd_hash] =
  [mani_abcd1, mani_abcd2, mani_abcd3, mani_abcd4, mani_abcd5]
  |> Enum.map(&(&1.hash))
  |> Enum.uniq()
```

Also, unlike plain commutative hashes, Manifests track set membership to ensure
that leaves can't be double-counted:

```elixir
mani_abb = CAStle.Manifest.new([mani_ab, obj_b])

[ab_hash] = Enum.uniq([mani_ab.hash, mani_abb.hash])
```
