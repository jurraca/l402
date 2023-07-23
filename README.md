# L402

An implementation of the [L402](https://docs.lightning.engineering/the-lightning-network/l402) spec in Elixir.

The L402 workflow is implemented as a Plug.

## Usage

Add the following to your `deps`:
```elixir
{:l402, "~> 0.0.1"}

```

You'll need a working LND node to connect to.
To configure it, you'll need:
    - a macaroon that allows you to get invoices from your node.
    - the TLS certificate issued with your node, to ensure we're talking to the right GRPC server.
    - the node's host and port.

Add these to your app's config as follows;
```elixir

config :l402,
    admin_macaroon_path: "asdfasdfasdf",
    cert_path: "/path/to/tls.cert"

```

## Authentication Flow

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

# Architecture and Resources

Three things are needed: Lightning, macaroons, and GRPC.
We use GRPC to communicate with our Lightning node.
The `GRPCChannel` module handles the connection with the node.
The `Macaroons` module creates, decodes, and verifies macaroons.
The `L402.build_challenge/2` function is the main entrypoint.

