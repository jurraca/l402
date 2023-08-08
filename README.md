# L402

An implementation of the [L402](https://docs.lightning.engineering/the-lightning-network/l402) spec in Elixir.

TLDR: We can use Lightning to leverage the `HTTP 402 - Payment Required` status code and finally send micropayments, for any web resource, without a middleman!

The basic idea and building blocks:
  1) There exists a `402 - Payment Required` HTTP [status code](https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/402)
  1) We can send decentralized micropayments via Bitcoin's Lightning network
  1) [Macaroons](https://research.google/pubs/pub41892/) are cookies which allow us to generate and validate specific conditions for a user's access to a resource, without verifying them via a central server. All that's required is the issuer signing the conditions on the macaroon. It's a bearer token.

Combining these building blocks gets you the L402 standard:
`bearer money + bearer tokens = payments on the web`.

You will need a LND lightning node. Learn how to get one set up [here](./Lightning.md).

> #### Warning:
> Alpha software, use with mainnet funds at your own risk.

## Usage

The L402 workflow is implemented as a [Plug](https://hexdocs.pm/plug/1.14.2/readme.html).

Once it's in Hex, you will be able to add the following to your `deps`:
```elixir
{:l402, "~> 0.1.0"}
```
(The Macaroons dependency does not support the V2 macaroons format. Once that's merged, we'll be able to add this project to Hex.)

To configure your application to use this Plug, you'll need:
- a Lightning node
- a macaroon that authorizes you to get invoices from your node
- the TLS certificate issued with your node, to ensure we're talking to the right GRPC server
- the node's host and port

Add these to your app's config as follows;
```elixir
config :l402,
    admin_macaroon_path: "/path/to/invoices.macaroon",
    cert_path: "/path/to/tls.cert"
```

The GRPC host config defaults to `127.0.0.1:10009`, but you can override it:

```elixir
config :grpc,
    host: "MY_HOST",
    port: 10011
```

You can add `L402.Plug` to your router or controllers, since both are themselves plugs:

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

## Architecture and Resources

### Macaroons

Generating a macaroon for a user declares the resources on your server which your user has access to. They get access to these resources by fulfilling the payment challenge embedded in the macaroon. This construction enables the provider to require nothing but a simple payment and a macaroon, and no longer need to support traditional payment systems, authentication systems, and user data stores to ensure that their service will not be abused.

Macaroons are portable: a user should be able to submit a macaroon to another web resource, and if it fulfills the conditions set in the caveat, they should be able to access the resource. Like a ticket.

Macaroons are signed by the issuer, and do not rely on a central server for validation. Anyone can deserialize a macaroon and ensure for themselves that it was not tampered with.

Macaroons can be updated. If a user wants to upgrade their capabilities, they can request a new macaroon from the service.

### Auth flow

A user must provide a macaroon and a proof of payment (a preimage) which uniquely identifies the service and the capabilities the service provides to the user.

In practice, the flow might look like this:
   - user GETs the resource.
   - The service checks its `authorization` header for a valid L402 header.
   - If the user doesn't have one, we create the L402 and set the `www-authenticate` header to `L402 macaroon:invoice`.
   - The service returns this header with a `402 - Payment Required` status code.
   - The client receives this response and handles it. The frontend could show the user this invoice to pay, or, if the user has a [webLN](https://www.webln.guide/introduction/readme)-enabled extension, the invoice can be paid automatically within that context.
   - The user pays the invoice and gets a "proof of payment": the preimage.
   - The user supplies that proof of payment in a second request to the resource.
   - The service validates the proof of payment, and the user gets access to the service.

### Resources

Three things are needed:[Lightning](https://lightning.network/), [macaroons](https://github.com/lightningnetwork/lnd/blob/master/docs/macaroons.md), and [GRPC](https://grpc.io/). We use GRPC to communicate with our Lightning node.
- The `GRPCChannel` module handles the connection with the Lightning node.
- The `Macaroons` module creates, decodes, and verifies macaroons.
- The `L402.build_challenge/2` function is the main entrypoint, returning an L402 header.
