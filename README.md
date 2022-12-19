[![Foundry][foundry-badge]][foundry]

[foundry]: https://getfoundry.sh/
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg

# Wrapped aToken Vault

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

## Topics for Debate

- Use of permit in `depositWithSig` and `mintWithSig`
    - The `main` branch does not include permit in these functions and assumes approval will be handled separately with relayers and a permit sig, or with the user calling `approve()` beforehand.
    - The [add-permit](https://github.com/aave/wrapped-atoken-vault/pull/19) branch does include versions of these functions with permit included, inside a `try-catch` block. This enables the withSig functions to still be used with tokens that either do not support permit at all, or use a non-standard version of permit (e.g. DAI).


## To Change

- `depositWithSig` and `mintWithSig` should take the aToken as well as the normal underlying asset.
- Allowance in `_withdraw` and `_redeem` should only check if caller has allowance. No withSig boolean flag needed. 
