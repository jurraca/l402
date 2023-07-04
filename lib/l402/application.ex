defmodule L402.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Starts a worker by calling: L402.Worker.start_link(arg)
      {GRPC.Server.Supervisor, endpoint: L402.Endpoint, port: 50051},
      L402.GRPCChannel
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: L402.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
