defmodule L402 do
  @moduledoc """
    An implementation of the L402 spec as a Plug.
    A user must provide a macaroon (a fancy cookie) and a proof of payment (a preimage) which uniquely identifies the service and the capabilities the service provides to the user.
    We gate a given resource with a Lightning payment. If the user can provide a proof of payment for an invoice, they get access.
    Flow works like this:
      - user hits the resource.
      - The service checks its `authorization` header for a valid L402 header.
      - If the user doesn't have one, we create the L402 and set the `www-authenticate` header to `L402 macaroon:preimage`.
      - The service returns this header with a 402 - Payment Required status code.
      - The client receives this response and handles it. The frontend could show the user this invoice to pay, or, if the user has a webLN-enabled extension, the invoice can be paid automatically within that context.
      - The user pays the invoice and gets a "proof of payment": the preimage.
      - The user supplies that proof of payment in a second request to the resource.
      - The service validates the proof of payment, and the user gets access to the service.

    `build_challenge/2` is the main entrypoint.
  """

  @doc """
    Builds a L402 challenge from an invoice amount and `opts`. See `Lnrpc.Invoice` for a full list of options to pass.
  """
  def build_challenge(invoice_amount, opts \\ []) do

    with {:ok, channel} <- get_channel(),
      %{payment_request: invoice} <- invoice_request(channel, invoice_amount, opts),
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
  def invoice_request(channel, invoice_amount, opts) do
    case LND.create_invoice(channel, invoice_amount, opts) do
      {:ok, body = %Lnrpc.AddInvoiceResponse{}} -> body
      {:error, msg} ->
        {:error, "could not fetch invoice from LND"}
    end
  end

  defp get_channel() do
    case Channel.get(:channel) do
      {:ok, nil} -> Channel.connect()
      {:ok, chan} -> {:ok, chan}
    else
  end
end
