defmodule L402.Plug do
  @moduledoc """
    A Plug to handle an L402-compliant authentication flow.

    The Plug matches on the authorization header of the form "L402 <macaroon>:<preimage>".
    If no authorization header is found, a 402 response is returned with a macaroon and a Lightning invoice.
    The plug expects an "amount" in the assigns, as issuing a payment invoice would not be possible without it. You should set this value in your controller or router.
  """
  alias Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(%Conn{req_headers: [{"authorization", "L402 " <> auth}]} = conn, _opts) do
    case L402.validate_402(auth) do
      {:ok, _} ->
        Conn.put_status(conn, 200)

      _ ->
        Conn.put_status(conn, :unauthorized)
    end
  end

  # If the conn has an amount but no authorization, return a 402 with challenge.
  def call(%Conn{assigns: %{amount: amount}} = conn, _opts) do
    case L402.build_challenge(amount) do
      {:ok, {_token, l402}} ->
        conn
        |> Conn.put_resp_header("www-authenticate", l402)
        |> Conn.put_status(:payment_required)

      {:error, _} ->
        Conn.put_status(conn, :service_unavailable)
    end
  end

  # The upstream pipeline must provide an amount to build a challenge from.
  def call(conn, _opts) do
    Conn.put_status(conn, :bad_request)
  end
end
