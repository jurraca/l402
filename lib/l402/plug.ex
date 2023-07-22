defmodule L402.Plugs.Main do
  @moduledoc """
      Plug to handle an LSAT-compliant authentication flow.
      If no mac, instruct LND to create one.
      Respond to client with mac and invoice in authenticate header.
      Client pays invoice, receives preimage.
      User responds with mac and preimage via Authorization field.
  """
  alias Plug.Conn
  alias L402.GRPCChannel, as: Channel
  alias L402.Server, as: LND
  alias L402.Macaroons
  alias Bitcoinex.LightningNetwork, as: LNUtils
  require Logger

  def init(opts), do: opts

  @doc """
  Matches on the authorization header of the form Authorization "L402 <macaroon>:<preimage>.
  No Authorization header.
  Set WWW-Authenticate: "L402 macaroon=<mac>, invoice=<invoice>"
  """
  def call(%Plug.Conn{req_headers: [{"authorization", auth}]} = conn) do
    IO.inspect(auth, label: "Auth, clause 1")
    validate_402(auth)
    conn
  end

  def call(%Plug.Conn{params: %{"L402" => l402}} = conn, _opts) do
    case validate_402(l402) |> IO.inspect() do
        {:ok, _} ->
            conn
            |> Conn.put_req_header("authorization", "L402")
            |> Conn.put_status(200)
        _ -> conn |> call([])
    end
  end

  def call(%Plug.Conn{} = conn, _opts) do
    {token, l402} = build_challenge()
    conn
    |> Conn.put_resp_cookie("my-cookie", token)
    |> Conn.put_resp_header("www-authenticate", l402)
    |> Conn.put_status(:payment_required)
  end

  def call(conn, _opts) do
    conn
  end

  def build_challenge(invoice_amount) do
    with %{channel: channel} <- Channel.connect(),
      %{payment_request: invoice} <- invoice_request(channel, invoice_amount),
      {:ok, %{payment_hash: payment_hash}} <- LNUtils.decode_invoice(invoice) do
    {:ok, token} = Macaroons.build([caveats: [payment_hash: payment_hash]])
    l402 = "L402 token=" <> token <> " invoice=" <> invoice
    {token, l402}
    else
        error -> Logger.error(error)
    end
  end

  defp invoice_request(channel, invoice_amount) do
    case LND.create_invoice(channel, invoice_amount) do
      {:ok, body = %Lnrpc.AddInvoiceResponse{}} -> body
      msg -> msg
    end
  end

  def validate_402("L402 " <> rest) do
    [macaroon, preimage] = String.split(rest, ":")
    binary_mac = Base.url_decode64(macaroon)
    hashed_preimage = :crypto.hash(preimage, :sha256)
    case Mac.get_payment_hash_from_macaroon(binary_mac) do
        {:ok, payment_hash} ->
          if payment_hash != hashed_preimage do
            {:error, "Preimage doesn't match provided payment_hash"}
          else
            Mac.verify_caveats(binary_mac, payment_hash)
          end
        {:error, _} = err -> err
    end
  end

  def validate_402(data) do
    {:error, "Wrong format for L402 header, got #{data}"}
  end

  defp get_payment_hash_from_jwt(jwt) do
    case Token.verify_and_validate(jwt) do
        {:ok, %{payment_hash: hash}} -> {:ok, hash}
        {:ok, _} -> {:error, "JWT must contain payment hash"}
        _ -> {:error, "Invalid JWT"}
    end
  end
end
