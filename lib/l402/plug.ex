defmodule L402.Plug do
  @moduledoc """
    A Plug to handle an L402-compliant authentication flow.
  """
  alias Plug.Conn
  alias L402.Server, as: LND
  alias L402.Macaroons
  require Logger

  def init(opts), do: opts

  @doc """
  Matches on the authorization header of the form Authorization "L402 <macaroon>:<preimage>".
  If no Authorization header is found, we issue a macaroon and a Lightning invoice, with a 402 response.
  The plug expects an "amount" in the assigns: you should set this value in your controller for the resource calling this plug.
  Default is to forbid access.
  """
  def call(%Plug.Conn{req_headers: [{"authorization", auth}]} = conn, _opts) do
    case validate_402(l402) do
        {:ok, _} ->
          Conn.put_status(conn, 200)
        _ -> Conn.put_status(conn, :forbidden)
    end
  end

  def call(%Plug.Conn{assigns: %{amount: amount}} = conn, _opts) do
    {macaroon, l402} = L402.build_challenge(amount)
    conn
    #|> Conn.put_resp_cookie("my-cookie", macaroon)
    |> Conn.put_resp_header("www-authenticate", l402)
    |> Conn.put_status(:payment_required)
  end

  def call(conn, _opts), do: Conn.put_status(conn, :forbidden)

  def validate_402("L402" <> rest), do: validate_402(rest)
  def validate_402(rest) do
    [macaroon, preimage] = String.split(rest, ":")
    binary_mac = Base.url_decode64(macaroon)
    hashed_preimage = :crypto.hash(preimage, :sha256)
    case Macaroons.get_payment_hash_from_macaroon(binary_mac) do
        {:ok, payment_hash} ->
          if payment_hash != hashed_preimage do
            {:error, "Preimage doesn't match provided payment_hash"}
          else
            Macaroons.verify_caveats(binary_mac, payment_hash)
          end
        {:error, _} = err -> err
    end
  end

  def validate_402(data) do
    {:error, "Wrong format for L402 header, got #{data}"}
  end
end
