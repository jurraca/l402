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
    l402 = "L402 macaroon=" <> token <> " invoice=" <> invoice
    {:ok, {token, l402}}
    else
        {:error, msg} -> Logger.error(msg)
        err -> err
    end
  end

  @doc """
    Request an invoice for the `amount` from a Lightning node connected via the `channel`.
  """
  def request_invoice(invoice_amount, opts \\ []) do
    {:ok, channel} = get_channel()
    case Server.create_invoice(channel, invoice_amount, opts) do
      {:ok, body = %Lnrpc.AddInvoiceResponse{}} -> body
      {:error, msg} ->
        {:error, msg}
    end
  end

  def parse("L402 " <> rest), do: parse(rest)

  def parse(l402_header) do
    l402_header
    |> String.split(":")
    |> Enum.map(&String.split(&1, "="))
    |> Enum.map(fn [k, v] -> {k,v} end)
    |> Enum.into(%{})
  end

  defp get_channel() do
    case Channel.get(:channel) do
      {:ok, nil} -> Channel.connect()
      {:ok, chan} -> {:ok, chan}
    end
  end
end
