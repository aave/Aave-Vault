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


## Vault Contract Details


### Vault Initialization

The constructor takes in the following arguments:

- An ERC20 token address which must be an asset with a market on Aave v3 on the chain on which the vault is deployed.
- The name and symbol of the share token for the aToken vault.
- An admin fee on yield earned, expressed as a fraction of 1e18.
- The address of the Aave v3 Pool Address Provider contract for the chain on which the vault is deployed. This will be used to get the address of Aave v3 Pool contract, from which the aToken corresponding to the specified ERC20 token address can be retrieved.
- The address of the Aave v3 Rewards Controller contract for the chain on which the vault is deployed. This is only used when the vault admin claims any additional rewards earned by the vault.

No additional initialization is required.

### Yield Accrual Economics

The core logic for yield accrual is contained in the internal `_accrueYield` function.

This function is called at the start of every `deposit`, `mint`, `redeem`, and `withdraw` action, to ensure that whenever new shares are minted, or existing shares are redeemed, that the vault is up-to-date on yield earned through Aave up to this point, and the portion of that yield which should accrue to the vault admin in the form of the admin fee.

In the case of more than one call to `_accrueYield` in a single block, no additional state updates concerning yield accrual or admin fees are made, with the function ending early as `block.timestamp == _lastUpdated`.


### To Write Still

 - explain accrueYield economic logic in deposit/withdraw flow
 - explain totalAssets re: deducting fees
 - deposit, depositWithSig, permitAndDepositWithSig
 - mint, mintWithSig, and why no 3rd func
 - explain approval model with withdraw vs withdrawWithSig
 - explain logic behind maxDeposit and maxMint concerning Aave v3
 - explain claiming Aave rewards for admin
 - emergency rescue for non vault aToken assets
