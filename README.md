# NoFeeSwap Vault

NoFeeSwap is an Automated Market Making (AMM) protocol that introduces customizable liquidity curves with protocol-level security. This architecture enables zero spread between buy and sell marginal prices while ensuring that liquidity grows after every swap. This combination translates to higher trading activity, even during minor market price fluctuations, and drives greater profitability for liquidity providers (LPs).

This repository contains the protocol's vault.

## YellowPaper Reference

A detailed description of NoFeeSwap vault can be found in the [NoFeeSwap YellowPaper](https://github.com/NoFeeSwap/docs).

## Setup Instructions

To get started, first install the following system dependencies:
```bash
sudo apt update
sudo apt install build-essential python3-dev python3.12-dev python3.12-venv npm
```
Clone the repo and it submodules
```bash
git clone https://github.com/NoFeeSwap/vault.git
cd vault
git submodule update --init --depth 1
```
Install hardhat
```bash
npm install hardhat@2.24.0 --save-dev
```
Create and initialize a Python virtual environment
```bash
python3.12 -m venv nofeeswap-vault
source nofeeswap-vault/bin/activate
```
Install the Python dependencies
```bash
pip install --upgrade pip
pip install -r requirements.txt
```

## Running Tests

All of the Brownie unit tests can be run with the following command:
```bash
brownie test --network hardhat
```

## License

Copyright 2025, NoFeeSwap LLC - All rights reserved. See [LICENSE](https://github.com/NoFeeSwap/vault/blob/main/LICENSE) for details.