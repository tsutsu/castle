defmodule CAStle.Adapter do
  @type config :: any()
  @type state :: any()
  @type key :: binary() | {atom(), any()}
  @type mode :: :struct | :process

  @callback init(mode(), Keyword.t()) :: {:ok, config(), state()} | :error

  @callback fetch(config(), state(), key()) :: {:ok, CAStle.Object.committed_t()} | :error

  @callback put(config(), state(), key(), CAStle.Object.committed_t()) :: state()

  @callback pop(config(), state(), key()) :: {CAStle.Object.committed_t() | nil, state()}

  @callback delete(config(), state(), key()) :: state()

  @callback member?(config(), state(), key()) :: boolean()

  @callback stream_hashes(config(), state()) :: Enumerable.t()

  @callback stream_objects(config(), state()) :: Enumerable.t()

  @callback clear(config(), state()) :: :ok
end
