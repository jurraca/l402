defmodule L402.GRPCChannel do
    use GenServer
    require Logger

    def start_link(_) do
      GenServer.start_link(__MODULE__, [], name: __MODULE__)
    end

    def init(_) do
        with {:ok, %GRPC.Channel{} = channel} <- get_channel(),
            {:ok, mac} <- get_admin_macaroon() do
          {:ok, %{admin_mac: mac, channel: channel}}
        end
    end

    def get() do
      GenServer.call(__MODULE__, :get)
    end

    def get(:admin_mac) do
      %{admin_mac: mac} = get()
      {:ok, mac}
    end

    def get(:channel) do
      %{channel: channel} = get()
      {:ok, channel}
    end

    def reset() do
      GenServer.cast(__MODULE__, :reset)
    end

    # Server

    def handle_call(:get, _from, state) do
      {:reply, state, state}
    end

    def handle_cast(:reset, %{channel: channel}) do
      case GRPC.Stub.disconnect(channel) do
        {:ok, _} -> {:noreply, nil}
        {:error, _} = err -> err
      end
    end

    def handle_info(msg) do
      IO.inspect(msg, label: "PID !!")
    end

    def handle_info(_, state) do
      {:noreply, state}
    end

    def get_channel() do
      host = Application.get_env(:grpc, :host)
      port = Application.get_env(:grpc, :port)
      GRPC.Stub.connect(host, port, cred: build_credentials(), adapter_opts: %{http2_opts: %{keepalive: :infinity}})
    end

    defp build_credentials() do
      cert_path = Application.get_env(:l402, :cert_path)
      %GRPC.Credential{ssl: [cacertfile: cert_path]}
    end

    defp get_admin_macaroon() do
      {:ok, :lngrpc
      |> Application.get_env(:admin_macaroon_path)
      |> encode_16()
    }
    end

    defp encode_16(macaroon_path) do
      macaroon_path
      |> File.read!()
      |> Base.encode16()
    end
end
