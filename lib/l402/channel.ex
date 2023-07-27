defmodule L402.GRPCChannel do
  @moduledoc """
    A GenServer which handles the state of our connection the LND node's GRPC server.
  """

    use GenServer
    require Logger

    def start_link(_) do
      GenServer.start_link(__MODULE__, [], name: __MODULE__)
    end

    @doc """
    GRPC connections are not meant to be long lived, unless requests are occuring. If the connection closes, it is not started again unless `get_channel/0` is called, usually in the process of building a request to the Lightning backend.
    """
    def connect() do
      case GenServer.call(__MODULE__, :connect) do
        %{channel: channel} -> {:ok, channel}
        err -> err
      end
    end

    def disconnect() do
      GenServer.cast(__MODULE__, :disconnect)
    end

    def get() do
      GenServer.call(__MODULE__, :get)
    end

    def get(:channel) do
      %{channel: channel} = get()
      {:ok, channel}
    end

    # Server

    @doc """
    The server connects when the application is loaded via the `Mint` adapter.
    """
    @impl true
    def init(_) do
        with {:ok, {host, port, cred}} <- get_config() do
          state = %{host: host, port: port, cred: cred}
          {:ok, state, {:continue, nil}}
        else
          error ->
            Logger.error(error)
            {:stop, error}
        end
    end

    @impl true
    def handle_continue(_arg, %{host: _host, port: _port, cred: _cred} = state) do
      case connect(state) do
        {:ok, new_state } -> {:noreply, new_state }
        _ -> {:stop, "could not connect to GRPC Server with provided credentials", state}
      end
    end

    @impl true
    def handle_call(:connect, _from, state) do
      case connect(state) do
        {:ok, new_state } -> {:reply, new_state, new_state }
        _ -> {:stop, "could not connect to GRPC Server with provided credentials", state}
      end
    end

    @impl true
    def handle_call(:get, _from, state) do
      {:reply, state, state}
    end

    @impl true
    def handle_cast(:disconnect, %{channel: channel} = state) do
      {:ok, _} = GRPC.Stub.disconnect(channel)
      Logger.info("Disconnected channel.")
      new_state = Map.put(state, :channel, nil)
      {:noreply, new_state}
    end

    @impl true
    def handle_cast(:disconnect, state) do
      Logger.info("Got disconnect but no channel running.")
      {:noreply, state}
    end

    @impl true
    def handle_info({:gun_down, _pid, _protocol, :normal, []}, state) do
      Logger.error("GRPC conn down via :gun_down")
      case connect(state) do
        {:ok, new_state } -> {:noreply, new_state }
        _ -> {:stop, "could not connect to GRPC Server with provided credentials", state}
      end
    end

    @impl true
    def handle_info({:gun_up, _pid, _protocol}, state) do
      Logger.info("gun_up")
      {:noreply, state}
    end

    @impl true
    def handle_info({:elixir_grpc, :connection_down, _pid}, state) do
      Logger.error("GRPC conn down. Disconnecting.")
      GRPC.Stub.disconnect(state.channel)
      new_state = Map.put(state, :channel, nil)
      {:noreply, new_state}
    end

    @impl true
    def handle_info({:EXIT, _pid, %Mint.TransportError{reason: reason}}, state) do
      Logger.error("GRPC Channel process exited with reason #{reason}")
      {:noreply, state}
    end

    @impl true
    def handle_info({:EXIT, _pid, :normal}, state) do
      Logger.info("Normal shutdown.")
      {:noreply, state}
    end

    @impl true
    def handle_info(msg, state) do
      Logger.info(msg)
      {:noreply, state}
    end

    def connect(%{host: host, port: port, cred: cred} = state) do
     case connect!(host, port, cred) do
        {:ok, %GRPC.Channel{} = chan } ->
          Logger.info("GRPC Channel connected.")
          new_state = Map.put(state, :channel, chan)
          {:ok, new_state}
        {:error, _} = err -> err
      end
    end

    defp connect!(host, port, cred) do
      GRPC.Stub.connect(host, port, cred: cred, adapter: GRPC.Client.Adapters.Mint, adapter_opts: [http2_opts: %{keepalive: :infinity}])
    end

    @doc """
    Get config values, and build a GRPC credential from the certificate path.
    """
    def get_config() do
      host = Application.get_env(:grpc, :host)
      port = Application.get_env(:grpc, :port)
      cred = build_credentials()
      {:ok, {host, port, cred}}
    end

    defp build_credentials() do
      cert_path = Application.get_env(:l402, :cert_path)
      GRPC.Credential.new([ssl: [cacertfile: cert_path]])
    end
end
