defmodule L402 do
  @moduledoc """
    Build, parse, validate an L402-compliant header.
  """

  alias L402.GRPCChannel, as: Channel
  alias L402.{Macaroons, Server}
  alias Bitcoinex.LightningNetwork, as: LNUtils
  alias Macaroon.Types.Macaroon
  alias L402.Macaroons

  require Logger

  @doc """
    Builds a L402 challenge from an invoice amount and `opts`. See `Lnrpc.Invoice` for a full list of options to pass.
  """
  def build_challenge(invoice_amount, opts \\ []) do
    with %{payment_request: invoice} <- request_invoice(invoice_amount, opts),
         {:ok, %{payment_hash: payment_hash}} <- LNUtils.decode_invoice(invoice) do
      {:ok, token} = Macaroons.build(caveats: [payment_hash: payment_hash])
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
      {:ok, body = %Lnrpc.AddInvoiceResponse{}} ->
        body

      {:error, msg} ->
        {:error, msg}
    end
  end

  def parse("L402 " <> rest), do: parse(rest)

  def parse(l402_header) do
    l402_header
    |> String.split(":")
    |> Enum.map(&String.split(&1, "="))
    |> Enum.map(fn [k, v] -> {k, v} end)
    |> Enum.into(%{})
  end

  @doc """
  Parse an L402 header. The macaroon is a base64 encoded bearer token. The preimage is hex-encoded.
  In order for the authorization to be valid, the payment hash included in the macaroon issued by the server must match the sha256 hash of the proof of payment provided by the client.
  """
  def validate_402("L402 " <> rest), do: validate_402(rest)

  def validate_402(rest) do
    with [macaroon, preimage] <- String.split(rest, ":"),
         {:ok, binary_mac} <- Base.url_decode64(macaroon) do
      hashed_preimage = :crypto.hash(preimage, :sha256)

      case Macaroons.decode(binary_mac) do
        {:ok, %{payment_hash: payment_hash} = decoded} ->
          validate_challenge(decoded, payment_hash, hashed_preimage)

        {:error, _} = err ->
          err
      end
    else
      _err -> {:error, "Wrong format for L402 header, got #{rest}"}
    end
  end

  def valid_preimage?(preimage, invoice) do
    with {:ok, %{payment_hash: payment_hash}} <- LNUtils.decode_invoice(invoice),
         hashed_preimage <- :crypto.hash(preimage, :sha256) do
      payment_hash == hashed_preimage
    end
  end

  defp validate_challenge(%Macaroon{caveats: caveats}, payment_hash, client_hash) do
    if payment_hash != client_hash do
      {:error, "Preimage doesn't match provided payment hash"}
    else
      Macaroons.verify_payment_hash(caveats, payment_hash)
    end
  end

  defp get_channel() do
    case Channel.get(:channel) do
      {:ok, nil} -> Channel.connect()
      {:ok, chan} -> {:ok, chan}
    end
  end
end
