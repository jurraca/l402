defmodule L402 do
  @moduledoc """
    Minimum public API for services to interact with the protocol.
    `build_challenge/2` is the main entrypoint.
  """

  alias L402.GRPCChannel, as: Channel
  alias L402.{Macaroons, Server}
  alias Bitcoinex.LightningNetwork, as: LNUtils


  require Logger

  @doc """
    Builds a L402 challenge from an invoice amount and `opts`. See `Lnrpc.Invoice` for a full list of options to pass.
  """
  def build_challenge(invoice_amount, opts \\ []) do
    with %{payment_request: invoice} <- request_invoice(invoice_amount, opts),
      {:ok, %{payment_hash: payment_hash}} <- LNUtils.decode_invoice(invoice) do
    {:ok, token} = Macaroons.build([caveats: [payment_hash: payment_hash]])
    l402 = "L402 token=" <> token <> " invoice=" <> invoice
    {:ok, {token, l402}}
    else
        {:error, msg} -> Logger.error(msg)
        err -> err
    end
  end

  @doc """
    Request an invoice for the `amount` from a Lightning node connected via the `channel`.
  """
  def request_invoice(invoice_amount, opts) do
    case get_channel() |> Server.create_invoice(invoice_amount, opts) do
      {:ok, body = %Lnrpc.AddInvoiceResponse{}} -> body
      {:error, _msg} ->
        {:error, "could not fetch invoice from LND"}
    end
  end

  defp get_channel() do
    case Channel.get(:channel) do
      {:ok, nil} -> Channel.connect()
      {:ok, chan} -> {:ok, chan}
    end
  end
end
