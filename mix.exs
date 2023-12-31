defmodule L402.MixProject do
  use Mix.Project

  def project do
    [
      app: :l402,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      # docs
      name: "L402",
      description: "Plug-based implementation of the L402 spec.",
      source_url: "https://github.com/jurraca/l402",
      homepage_url: "https://docs.lightning.engineering/the-lightning-network/l402",
      docs: [
        # The main page in the docs
        main: "readme",
        extras: ["README.md", "Lightning.md"]
      ]
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
      {:plug_cowboy, "~> 2.6"},
      {:bitcoinex, "~> 0.1.7"},
      # we need macaroons v2, but the library does not support it yet.
      # PR here: https://github.com/doawoo/macaroon/pull/3
      {:macaroon, git: "https://github.com/jurraca/macaroon", branch: "v2"},
      {:jason, "~> 1.4.1"},
      {:ex_doc, "~> 0.27", only: :dev, runtime: false}
    ]
  end

  defp package() do
    [
      # This option is only needed when you don't want to use the OTP application name
      name: "L402",
      # These are the default files included in the package
      files: ~w(lib priv .formatter.exs mix.exs README* LICENSE*),
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/jurraca/l402"}
    ]
  end
end
