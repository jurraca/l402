defmodule L402.GRPCChannel do
    use GenServer
    require Logger

    def start_link(_) do
      GenServer.start_link(__MODULE__, [], name: __MODULE__)
    end

    def connect() do
      GenServer.call(__MODULE__, :connect)
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
    @impl true
    def init(_) do
        with {:ok, {host, port, cred}} <- get_config(),
            {:ok, mac} <- get_admin_macaroon() do
          {:ok, %{admin_mac: mac, host: host, port: port, cred: cred}}
        else
          error ->
            Logger.error(error)
            {:stop, error}
        end
    end

    @impl true
    def handle_call(:connect, _from, %{host: host, port: port, cred: cred} = state) do
      case GRPC.Stub.connect(host, port, cred: cred, adapter: GRPC.Client.Adapters.Mint, adapter_opts: [http2_opts: %{keepalive: :infinity}]) do
        {:ok, %GRPC.Channel{} = chan } -> {:reply, :ok, Map.put(state, :channel, chan)}
        _ -> {:reply, :error, state}
      end
    end

    @impl true
    def handle_call(:get, _from, state) do
      {:reply, state, state}
    end

    @impl true
    def handle_cast(:reset, %{channel: channel}) do
      case GRPC.Stub.disconnect(channel) do
        {:ok, _} -> {:noreply, nil}
        {:error, _} = err -> err
      end
    end

    @impl true
    def handle_info({:gun_down, _pid, _protocol, :normal, []}, state) do
      Logger.error("GRPC conn down via :gun_down")
      {:noreply, state}
    end

    @impl true
    def handle_info({:gun_up, _pid, _protocol}, state) do
      Logger.info("gun_up")
      {:noreply, state}
    end

    @impl true
    def handle_info({:elixir_grpc, :connection_down, pid}, state) do
      Logger.error("GRPC conn down")
      {:noreply, state}
    end

    @imple true
    def handle_info({:EXIT, pid, %Mint.TransportError{reason: reason}}, state) do
      Logger.error("Process exited with reason #{reason}")
      {:noreply, state}
    end

    @impl true
    def handle_info(msg, state) do
      Logger.info(msg)
      {:noreply, state}
    end

    def get_config() do
      host = Application.get_env(:grpc, :host)
      port = Application.get_env(:grpc, :port)
      cred = build_credentials()
      {:ok, {host, port, cred}}
    end

    defp build_credentials() do
      cert_path = Application.get_env(:l402, :cert_path)
      %GRPC.Credential{ssl: [cacertfile: Path.join(:code.priv_dir(:l402), cert_path)]}
    end

    def get_admin_macaroon() do
      mac = :l402
      |> Application.get_env(:admin_macaroon_path)
      |> read_and_encode()

      {:ok, mac}
    end

    defp read_and_encode(macaroon_path) do
      :l402
      |> :code.priv_dir()
      |> Path.join(macaroon_path) # join paths to get the app priv directory at runtime
      |> File.read!()
      |> Base.encode16()
    end
end
