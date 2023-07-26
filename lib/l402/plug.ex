defmodule L402.Plug do
  @moduledoc """
    A Plug to handle an L402-compliant authentication flow.

    The Plug matches on the authorization header of the form "L402 <macaroon>:<preimage>".
    If no authorization header is found, a 402 response is returned with a token and a Lightning invoice.
    The plug expects an "amount" in the assigns, as issuing a payment invoice would not be possible without it. You should set this value in your controller or router.
  """
  alias Plug.Conn
  alias L402.Macaroons
  alias Macaroon.Types.Macaroon
  require Logger

  def init(opts), do: opts

  def call(%Plug.Conn{req_headers: [{"authorization", "L402 " <> auth}]} = conn, _opts) do
    case validate_402(auth) do
      {:ok, _} ->
        Conn.put_status(conn, 200)

      _ ->
        Conn.put_status(conn, :unauthorized)
    end
  end

  # If the conn has an amount but no authorization, return a 402 with challenge.
  def call(%Plug.Conn{assigns: %{amount: amount}} = conn, _opts) do
    case L402.build_challenge(amount) do
      {:ok, {_token, l402}} ->
        conn
        |> Conn.put_resp_header("www-authenticate", l402)
        |> Conn.put_status(:payment_required)

      {:error, _} ->
        Conn.put_status(conn, :service_unavaible)
    end
  end

  # The upstream pipeline must provide an amount to build a challenge from.
  def call(conn, _opts) do
    Conn.put_status(conn, :bad_request)
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
        {:ok, %{payment_hash: payment_hash} = decoded} -> validate_challenge(decoded, payment_hash, hashed_preimage)
        {:error, _} = err -> err
      end
    else
      _err -> {:error, "Wrong format for L402 header, got #{rest}"}
    end
  end

  defp validate_challenge(%Macaroon{caveats: caveats}, payment_hash, client_hash) do
    if payment_hash != client_hash do
      {:error, "Preimage doesn't match provided payment hash"}
    else
      Macaroons.verify_payment_hash(caveats, payment_hash)
    end
  end
end
