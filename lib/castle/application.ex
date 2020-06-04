defmodule CAStle.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: CAStle.Store.Registry}
    ]

    opts = [strategy: :one_for_one, name: CAStle.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
