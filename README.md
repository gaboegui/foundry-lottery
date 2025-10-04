## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## PROJECT DESCRIPTION
This project is a decentralized lottery system implemented using Solidity smart contracts and developed with the Foundry toolkit. It features a `Raffle.sol` smart contract that allows users to enter a lottery by paying a fee, with a winner being randomly selected and awarded the prize.

## Raffle.sol Smart Contract

The `Raffle.sol` smart contract provides the core logic for the lottery. Key features include:

- **Enter Raffle**: Participants can enter the raffle by sending a specified amount of Ether.
- **Random Winner Selection**: A Chainlink VRF (Verifiable Random Function) is used to securely and verifiably select a random winner from the participants.
- **Automated Fulfillment**: Chainlink Keepers are integrated to automate the process of checking for a winner and fulfilling the lottery.
- **Prize Distribution**: The winner receives the entire pool of Ether collected from participants.
- **State Management**: The contract manages various states of the raffle, such as `OPEN`, `CALCULATING_WINNER`, to ensure proper flow and prevent reentrancy issues.

## Getting Started

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

### Deploy & Verify on Sepolia

```shell
$ forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url $SEPOLIA_RPC_URL --account sepoliaAccount2 --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY -vvvv
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

## Donations

If you found this project helpful, feel free to follow me or make a donation!

**ETH/Arbitrum/Optimism/Polygon/BSC/etc Address:** `0x2210C9bD79D0619C5d455523b260cc231f1C2F0D`

## Contact

[![Gabriel Eguiguren P. X](https://img.shields.io/badge/Twitter-1DA1F2?style=for-the-badge&logo=twitter&logoColor=white)](https://x.com/GaBoEgui)
[![Gabriel Eguiguren P. Linkedin](https://img.shields.io/badge/LinkedIn-0077B5?style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/gabrieleguiguren/)
