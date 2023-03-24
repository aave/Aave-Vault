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

### Accounting for Fees in `totalAssets`

The `totalAssets` function is used to calculate the amount of shares to be issued or redeemed, given an amount of underling assets to be deposited or withdrawn from the vault. As such, it is necessary to deduct any fees which are held in the vault, and thus reflected in the vault's aToken balance, but which are not attributable to shareholders.

### Use of EIP-721 Signatures and Permit

Each of the `deposit`, `mint`, `redeem`, and `withdraw` functions have a corresponding `depositWithSig`, `mintWithSig`, `redeemWithSig`, and `withdrawWithSig` function, which allow users to sign a message using the EIP-712 standard, and pass that signature to a third party to execute the action on their behalf. This is intended to create a better UX by passing the gas costs from the user to the third party - likely the vault admin.

Note that in `depositWithSig` and `mintWithSig`, the user would still have to approve the vault contract to transfer their tokens, in order for these functions to not revert.

To further alleviate this UX issue, the vault also includes a `permitAndDepositWithSig` function, which allows a user to sign two messages - a `permit` message to handle the ERC20 approval, and the `depositWithSig` message to handle the deposit. The third party can then execute the deposit action on behalf of the user, including the ERC20 approval, in a single transaction.

### Allowance Model in `withdraw` and `redeem`

In the `withdraw` and `redeem` functions, the allowance model follows the standard model from Solmate's ERC4626 contract - the `owner` must have approved the caller to spend their vault shares, redeeming them for the underlying assets, which then get transferred to the `receiver` address.

However, in the `withdrawWithSig` and `redeemWithSig` functions, the allowance model is slightly different. In these functions, the `owner` must have approved the `receiver` address to spend their vault shares. This ensures that any third party can call these functions on the owner's behalf without the owner knowing or approving the address of this third party caller, because the the assets will still be transferred to the `receiver` address, which the owner has approved.

### Limitations to `maxDeposit` and `maxMint`

The [ERC-4626 standard](https://eips.ethereum.org/EIPS/eip-4626) defines the `maxDeposit` and `maxMint` functions as follows:

> maxDeposit: Maximum amount of the underlying asset that can be deposited into the Vault for the receiver, through a deposit call.

and

> maxMint: Maximum amount of shares that can be minted for the receiver, through a mint call.

Therefore, any supply amount limitations that affect the Aave v3 market for the vault's underlying asset should be reflected in these functions. This logic is implemented `_maxAssetsSuppliableToAave` which returns the maximum amount of the underlying asset that can be supplied to Aave v3, taking into account any supply caps, and if the market is active, frozen, or paused.

## License
All rights Reserved © AaveCo