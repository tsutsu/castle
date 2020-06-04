defmodule CAStle.MixProject do
  use Mix.Project

  def project, do: [
    app: :castle,
    version: "0.1.0",
    elixir: "~> 1.9",
    start_permanent: Mix.env() == :prod,
    deps: deps()
  ]

  def application, do: [
    extra_applications: [:logger]
  ]

  defp deps, do: [
    {:rocksdb, github: "tsutsu/erlang-rocksdb", branch: "feature-support-erl23", optional: true}
  ]
end
