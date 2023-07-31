# L402

An implementation of the [L402](https://docs.lightning.engineering/the-lightning-network/l402) spec in Elixir.

TLDR: We can use Lightning to leverage the `HTTP 402 - Payment Required` status code and finally send micropayments, for any web resource, without a middleman!

The basic idea and buliding blocks:
  1) There exists a `402 - Payment Required` [status code](https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/402)
  1) We can send decentralized micropayments via Bitcoin's Lightning network
  1) [Macaroons](https://research.google/pubs/pub41892/) are cookies which allow us to generate and validate specific conditions for a user's access to a resource, without verifying them via a central server. All that's required is the issuer signing the conditions on the macaroon. It's a bearer token.

Combining these building blocks gets you the L402 standard:
`bearer money + bearer tokens = payments on the web`.

You will need a LND lightning node. Learn how to get one set up [here](./Lightning.md).

> #### Warning:
> Alpha software, use with mainnet funds at your own risk.

## Usage

The L402 workflow is implemented as a Plug.

Once it's in Hex, you will be able to add the following to your `deps`:
```elixir
{:l402, "~> 0.1.0"}
```
(The Macaroons dependency does not support the V2 macaroons format. Once that's merged, we'll be able to add this project to Hex.)

You'll need a working LND node to connect to.
To configure it, you'll need:
- a macaroon that allows you to get invoices from your node
- the TLS certificate issued with your node, to ensure we're talking to the right GRPC server
- the node's host and port

Add these to your app's config as follows;
```elixir
config :l402,
    admin_macaroon_path: "asdfasdfasdf",
    cert_path: "/path/to/tls.cert"
```

The GRPC host config defaults to `127.0.0.1:10009`, but you can override it:

```elixir
config :grpc,
    host: "MY_HOST",
    port: 10011
```

You can add `L402.Plug` to your router or controllers, since both are plugs already:

```elixir
defmodule MyApp.Router do
  use MyAppWeb, :router

  pipeline :browser do
    ...
  end

  pipeline :pay do
    plug L402.Plug
  end

  scope "/", MyAppWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/", MyAppWeb do
    pipe_through :pay

    post "/paid-endpoint", MyApp.PaymentController, :pay
  end
end
```
or in a `Controller`:

```elixir
defmodule MyAppWeb.PaymentController do
  use MyAppWeb, :controller

  plug L402.Plug

  def pay(conn, params) do
    ...
    render(conn, :index)
  end
end
```

The plug will be invoked before the action is called. However, you can also choose to invoke it in a controller action, for example to fetch payment information for a given resource:

```elixir
defmodule MyAppWeb.PaymentController do
  use MyAppWeb, :controller

  def pay(conn, %{service_id: service_id}) do
    {:ok, amount} = fetch_amount(service_id)
    conn
    |> assign(:amount, amount)
    |> Plug.run([{L402.Plug, {}}])
    |> render(:index)
  end
end
```

## Authentication Flow

A user must provide a macaroon and a proof of payment (a preimage) which uniquely identifies the service and the capabilities the service provides to the user.
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

## Architecture and Resources

Three things are needed:[Lightning](https://lightning.network/), [macaroons](https://github.com/lightningnetwork/lnd/blob/master/docs/macaroons.md), and [GRPC](https://grpc.io/). We use GRPC to communicate with our Lightning node.
- The `GRPCChannel` module handles the connection with the Lightning node.
- The `Macaroons` module creates, decodes, and verifies macaroons.
- The `L402.build_challenge/2` function is the main entrypoint, returning an L402 header.
