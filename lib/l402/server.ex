defmodule L402.Server do
  use GRPC.Server, service: Lnrpc.Lightning.Service

    alias Lnrpc.Lightning.Stub
    alias L402.GRPCChannel

  @doc """
    Request a macaroon. Pass a GRPC channel and an admin macaroon as credential
    Returns {:ok, %Lnrpc.BakeMacaroonResponse{macaroon: new_macaroon}}
  """
  def bake_macaroon(channel) do
    case build_macaroon(channel) do
      {:ok, %Lnrpc.BakeMacaroonResponse{macaroon: mac}} -> mac
      {:error, _} = err -> err
      msg -> msg
    end
  end

  def create_invoice(channel) do
    Stub.add_invoice(
      channel,
      %Lnrpc.Invoice{
        value: 10,
        memo: "for access"
      },
      metadata: [macaroon: admin_mac()]
    )
  end

  @spec wallet_balance(GRPC.Channel.t()) ::
          {:error, GRPC.RPCError.t()} | {:ok, any} | {:ok, any, map} | GRPC.Client.Stream.t()
  def wallet_balance(channel) do
    Stub.wallet_balance(
      channel,
      %Lnrpc.WalletBalanceRequest{},
      metadata: [macaroon: admin_mac()]
    )
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
      metadata: [macaroon: admin_mac()]
    )
  end

  defp admin_mac() do
    case GRPCChannel.get(:admin_mac) do
      {:ok, mac} -> mac
      {:error, _} = err -> err
    end
  end
end
