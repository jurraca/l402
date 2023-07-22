defmodule L402.Server do
  use GRPC.Server, service: Lnrpc.Lightning.Service

    alias Lnrpc.Lightning.Stub
    alias L402.GRPCChannel

  def create_invoice(channel, invoice_amount) do
    Stub.add_invoice(
      channel,
      %Lnrpc.Invoice{
        value: invoice_amount,
        memo: "for access"
      },
      metadata: [macaroon: get_admin_mac()]
    )
  end

  @spec wallet_balance(GRPC.Channel.t()) ::
          {:error, GRPC.RPCError.t()} | {:ok, any} | {:ok, any, map} | GRPC.Client.Stream.t()
  def wallet_balance(channel) do
    Stub.wallet_balance(
      channel,
      %Lnrpc.WalletBalanceRequest{},
      metadata: [macaroon: get_admin_mac()]
    )
  end

  @doc """
    Request a macaroon. Pass a GRPC channel and an admin macaroon as credential
    Returns {:ok, %Lnrpc.BakeMacaroonResponse{macaroon: new_macaroon}}
  """
  def bake_macaroon(channel) do
    case build_macaroon(channel) do
      {:ok, %Lnrpc.BakeMacaroonResponse{macaroon: mac}} -> {:ok, mac}
      {:error, _} = err -> err
      msg -> msg
    end
  end

  defp build_macaroon(channel) do
    Stub.bake_macaroon(
      channel,
      %Lnrpc.BakeMacaroonRequest{
        permissions: [
          %Lnrpc.MacaroonPermission{
            entity: "invoices",
            action: "read"
          }
        ]
      },
      metadata: [macaroon: get_admin_mac()]
    )
  end

  defp get_admin_mac() do
    case GRPCChannel.get(:admin_mac) do
      {:ok, mac} -> mac
      {:error, _} = err -> err
    end
  end

  defp request(fun, channel, mac), do: fun.(channel, mac)
end
