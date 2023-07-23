defmodule L402.Server do
  use GRPC.Server, service: Lnrpc.Lightning.Service

  alias Lnrpc.Lightning.Stub
  alias L402.GRPCChannel

  def create_invoice(channel, invoice_amount, opts) do
    expiry = if opts[:expiry], do: opts[:expiry], else: h24()

    with invoice <-
           %Lnrpc.Invoice{}
           |> Map.put(:value, invoice_amount)
           |> Map.put(:memo, opts[:memo])
           |> Map.put(:expiry, expiry),
         {:ok, macaroon} <- get_admin_macaroon() do
      Stub.add_invoice(
        channel,
        invoice,
        metadata: [macaroon: macaroon]
      )
    end
  end

  @spec wallet_balance(GRPC.Channel.t()) ::
          {:error, GRPC.RPCError.t()} | {:ok, any} | {:ok, any, map} | GRPC.Client.Stream.t()
  def wallet_balance(channel) do
    {:ok, macaroon} = get_admin_mac()

    Stub.wallet_balance(
      channel,
      %Lnrpc.WalletBalanceRequest{},
      metadata: [macaroon: macaroon]
    )
  end

  @doc """
    Request a macaroon. Pass a GRPC channel and an admin macaroon as credential
    Returns {:ok, %Lnrpc.BakeMacaroonResponse{macaroon: new_macaroon}}
  """
  def bake_macaroon(channel, permissions) do
    case build_macaroon(channel) do
      {:ok, %Lnrpc.BakeMacaroonResponse{macaroon: mac}} -> {:ok, mac}
      {:error, _} = err -> err
      msg -> msg
    end
  end

  defp build_macaroon(channel, permissions) do
    {:ok, macaroon} = get_admin_mac()

    Stub.bake_macaroon(
      channel,
      %Lnrpc.BakeMacaroonRequest{
        permissions: permissions
      },
      metadata: [macaroon: macaroon]
    )
  end

  defp h24(), do: DateTime.to_unix(DateTime.utc_now() + 86400)

  defp get_admin_macaroon() do
    mac =
      :l402
      |> Application.get_env(:admin_macaroon_path)
      |> read_and_encode()

    {:ok, mac}
  end

  defp read_and_encode(macaroon_path) do
    macaroon_path
    |> File.read!()
    |> Base.encode16()
  end
end
