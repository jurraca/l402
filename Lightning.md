## Lightning Node Setup

The [Lightning](https://river.com/learn/what-is-the-lightning-network/) network is a layer-2 protocol to Bitcoin. The money being transferred is still bitcoin, but is sent via a payment channel, through which any amount of transactions can occur without incurring main chain fees for every back-and-forth.

In order to send and request payments for your web applications, you will need a working Lightning Node. This guide assumes [LND](https://github.com/lightningnetwork/lnd) since they have implemented Macaroons.

You can either: set up your own node or use a hosted solution like [Voltage](https://voltage.cloud/nodes/#).

## LN Node Setup

- Download Bitcoin
- Download LND

On startup
- create a wallet, write down the seed.
- check that your node is up by running `lncli -regtest getinfo`

## Hosted Node

Using a hosted node makes sense if you don't think you'll be able to secure your node, or if you don't have the infrastructure to run a bitcoin + lightning node. Downside of Voltage and other hosted nodes is that you can only run `mainnet` nodes. It's often helpful to be able to test in a either `simnet` or `regtest`.

Just sign up, they will provide your GRPC credentials (TLS cert and macaroon).

