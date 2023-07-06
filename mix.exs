defmodule L402.MixProject do
  use Mix.Project

  def project do
    [
      app: :l402,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {L402.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:protobuf, "~> 0.12.0"},
      {:grpc, "~> 0.6"},
      {:plug_cowboy, "~> 2.6"}
    ]
  end
end
