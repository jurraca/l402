## Lightning Node Setup

The [Lightning](https://river.com/learn/what-is-the-lightning-network/) network is a layer-2 protocol to Bitcoin. The money being transferred is still bitcoin, but is sent via a payment channel, through which any amount of transactions can occur without incurring main chain fees for every back-and-forth.

In order to send and request payments for your web applications, you will need a working Lightning Node. This guide assumes [LND](https://github.com/lightningnetwork/lnd) since they have implemented Macaroons.

You can either: set up your own node or use a hosted solution like [Voltage](https://voltage.cloud/nodes/#).

## LN Node Setup

The easiest way get up and running is to use Nix:
`nix-shell -p lnd bitcoin`.

The [repository](https://github.com/jurraca/l402) for this module includes a `shell.nix` file with the minimum requirements to develop this application, and you can modify it to include `lnd` and `bitcoin`, and run them locally that way.

For platform-specific setup details, see:
- Setting up a Bitcoin full node [guide](https://bitcoin.org/en/full-node).
- LND's Getting Started [guide](https://docs.lightning.engineering/lightning-network-tools/lnd/run-lnd).

The first time, you'll likely want to run the node in `regtest` mode.

Write down your seed words!

## Node configuration with Nix-Bitcoin

If you plan on hosting your own node, we recommend using [nix-bitcoin](https://github.com/fort-nix/nix-bitcoin/)'s declarative configuration. It's easy because you can write the configuration once, change it in one place, and deploy it as many times as needed. A basic and thoroughly documented example lives [here](https://github.com/fort-nix/nix-bitcoin/blob/master/examples/configuration.nix).

## Hosted Node

Using a hosted node makes sense if you don't think you'll be able to secure your node, or if you don't have the infrastructure to run a bitcoin + lightning node. Downside of Voltage and other hosted nodes is that you can only run `mainnet` nodes. It's often helpful to be able to test in a either `simnet` or `regtest`.

