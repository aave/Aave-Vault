[![Foundry][foundry-badge]][foundry]

[foundry]: https://getfoundry.sh/
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg

# Aave Vault

An ERC-4626 vault which allows users to deposit/withdraw ERC-20 tokens supported by Aave v3, manages the supply and withdrawal of these assets in Aave, and allows a vault manager to take a fee on yield earned.

## Instructions

To compile/build the project, run `forge build`.

To run the test suite, run `forge test`.

## Tests

Some of the tests rely on an RPC connection for forking network state. Make sure you have an `.env` file in the root directory of the repo with the following keys and values:

```
POLYGON_RPC_URL=[Your favourite Polygon RPC URL]
AVALANCHE_RPC_URL=[Your favourite Avalanche RPC URL]
```

The fork tests all use Polygon, except tests for claiming Aave rewards, which use Avalanche.

This test suite also includes a16z's [ERC-4626 Property Tests](https://a16zcrypto.com/generalized-property-tests-for-erc4626-vaults/), which are in the `ATokenVaultProperties.t.sol` file. These tests do not use a forked network state but rather use mock contracts, found in the `test/mocks` folder.

## Deployment

To deploy the vault contract, first check that the deployment parameters in `script/Deploy.s.sol` are configured correctly, then check that your `.env` file contains these keys:

```
POLYGON_RPC_URL=xxx
MUMBAI_RPC_URL=xxx
ETHERSCAN_API_KEY=xxx
PRIVATE_KEY=xxx
```

Then run:

```bash
source .env
```

Then run one of the following commands:

Mumbai Testnet:

```bash
forge script script/Deploy.s.sol:Deploy --rpc-url $MUMBAI_RPC_URL --broadcast --verify --legacy -vvvv
```

Polygon Mainnet:

```bash
forge script script/Deploy.s.sol:Deploy --rpc-url $POLYGON_RPC_URL --broadcast --verify --legacy -vvvv
```

## Audits

You can find all audit reports under the audits folder

- [01-03-2023 OpenZeppelin](./audits/01-03-2023_OpenZeppelin_Wrapped_AToken_Vault.pdf)
- [03-03-2023 PeckShield](./audits/03-03-2023_Peckshield_Wrapped_AToken_Vault.pdf)
- [18-06-2023 Certora](./certora/report/Aave-Vault-Formal-Verification.pdf)


## License

All Rights Reserved © Aave Labs
