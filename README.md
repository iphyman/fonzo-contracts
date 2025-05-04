# Fonzo.fun

Fonzo.fun is a trading protocol for decentralized and permissionless peer to pool prediction trading built on the Flare blockchain, leveraging Flare Time Series Oracle version 2.

The protocol is designed to be fully decentralized without the need for an offchain operator for matching and settlement. All trading happens completely onchain.

## Architecture

Fonzo.fun uses a singleton-style architecture, where all market state is managed in the `FonzoMarket.sol` contract. The following entry point functions are available for anyone or smart contracts or wallets to call;

- `bearish` - to open a bear position in a market
- `bullish` - to open a bull position in a market
- `settle` - to collect rewards due in a market
- `initializeMarket` - to initialize a new market
- `resolve` - to settle a market using FTSOV2 Oracle

Detailed call signatures can be found on the contract interface with documentations.

## How We use Flare Tech

Flare Times Series Oracle acts as a vital infrastructure component that provides us with decentralized, block-latency data feeds to accurately settle market predictions completely on-chain.

This near real time price feeds provided by the FTSO are essential for the core functioning of Fonzo prediction market, a platform that allow users to bet on the outcome of future events.

To see how we use FTSO in our smart contract please see the implementation of `resolve` function in the `FonzoMarket.sol` contract.

## Demo And Links

- [Demo App](https://fonzo.vercel.app/)
- [Frontend](https://github.com/iphyman/fonzo-ui)
- [Video Demo](https://youtu.be/0fNIGvA4Oyc)

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

Before deployment, you should copy and .env.example to .env file on the root folder and update accordingly.

```shell
$ bash deploy.sh -k <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
