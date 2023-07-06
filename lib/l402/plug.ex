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

  def init(opts), do: opts

  @doc """
  Matches on the authorization header of the form Authorization "LSAT <macaroon>:<preimage>.
  No Authorization header.
  Set WWW-Authenticate: "LSAT macaroon=<mac>, invoice=<invoice>"
  """

  def call(%Plug.Conn{req_headers: [{"authorization", auth}]} = conn) do
    parse_auth(auth)
    conn
  end

  def call(%Plug.Conn{params: %{"payment" => %{"lsat" => lsat}}} = conn, _opts) do
    IO.inspect(lsat, label: "LSAT HIT")
    case valid_lsat?(lsat) do
      {:ok, msg} -> validate_preimage(msg)
      {:error, msg} -> msg
    end
    conn
    |> Conn.put_req_header("authorization", "lsat")
    |> Conn.put_status(200)
  end

  def call(%Plug.Conn{} = conn, _opts) do
    IO.inspect(conn.assigns)
    lsat = build_lsat()

    conn
    |> Conn.put_resp_header("www-authenticate", lsat)
    |> Conn.put_status(:payment_required)
  end

  def call(conn, _opts) do
    conn
  end

  def validate_preimage(%{macaroon: _mac, preimage: _preimage} = m) do
    IO.inspect(m)
  end

  defp build_lsat() do
    {:ok, channel} = Channel.get(:channel)
    mac = channel |> LND.bake_macaroon() |> Base.encode64()
    %{payment_request: invoice, r_hash: _hash} = invoice_request(channel)

    "LSAT macaroon=" <> mac <> " invoice=" <> invoice
  end

  defp invoice_request(channel) do
    case LND.create_invoice(channel) do
      {:ok, body = %Lnrpc.AddInvoiceResponse{}} -> body
      msg -> msg
    end
  end

  defp parse_auth(auth), do: auth |> IO.inspect()

  def valid_lsat?(lsat) do
    # regex to extract mac and preimage
    regex = ~r{^LSAT\s(?<mac>.+):(?<preimage>[[:alnum:]]+)$}

    case Regex.named_captures(regex, lsat) do
      %{"mac" => mac, "preimage" => preimage} -> {:ok, %{macaroon: mac, preimage: preimage}}
      _ -> {:error, "Invalid LSAT"}
    end
  end
end
