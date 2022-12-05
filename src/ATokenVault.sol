// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {ERC4626, SafeTransferLib, FixedPointMathLib} from "solmate/mixins/ERC4626.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {IPoolAddressesProvider} from "aave/interfaces/IPoolAddressesProvider.sol";
import {IRewardsController} from "aave-periphery/rewards/interfaces/IRewardsController.sol";
import {IPool} from "aave/interfaces/IPool.sol";
import {IAToken} from "aave/interfaces/IAToken.sol";

// Libraries
import {MetaTxHelpers} from "./libraries/MetaTxHelpers.sol";
import {DataTypes} from "./libraries/DataTypes.sol";
import {Errors} from "./libraries/Errors.sol";
import {Events} from "./libraries/Events.sol";

import "./libraries/Constants.sol";

/**
 * @title ATokenVault
 * @author Aave Protocol
 *
 * @notice An ERC-4626 vault for ERC20 assets supported by Aave v3,
 * with a potential vault fee on yield earned.
 */
contract ATokenVault is ERC4626, Ownable {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    IPoolAddressesProvider public immutable POOL_ADDRESSES_PROVIDER;
    IRewardsController public immutable REWARDS_CONTROLLER;

    uint256 internal constant SCALE = 1e18;

    mapping(address => uint256) public sigNonces;

    IPool public aavePool;
    IAToken public aToken;

    uint256 public lastUpdated; // timestamp of last accrueYield action
    uint256 public lastVaultBalance; // total aToken incl. fees
    uint256 public fee; // as a fraction of 1e18
    uint256 internal accumulatedFees; // fees accrued since last updated

    /**
     * @param underlying The underlying ERC20 asset which can be supplied to Aave
     * @param shareName The name of the share token for this vault
     * @param shareSymbol The symbol of the share token for this vault
     * @param initialFee The fee taken on yield earned, as a fraction of 1e18
     * @param poolAddressesProvider The address of the Aave v3 Pool Addresses Provider
     * @param rewardsController The address of the Aave v3 Rewards Controller
     */
    constructor(
        ERC20 underlying,
        string memory shareName,
        string memory shareSymbol,
        uint256 initialFee,
        IPoolAddressesProvider poolAddressesProvider,
        IRewardsController rewardsController
    ) ERC4626(underlying, shareName, shareSymbol) {
        if (initialFee > SCALE) revert Errors.FeeTooHigh();

        POOL_ADDRESSES_PROVIDER = poolAddressesProvider;
        REWARDS_CONTROLLER = rewardsController;

        aavePool = IPool(poolAddressesProvider.getPool());
        address aTokenAddress = aavePool.getReserveData(address(underlying)).aTokenAddress;
        if (aTokenAddress == address(0)) revert Errors.AssetNotSupported();
        aToken = IAToken(aTokenAddress);

        fee = initialFee;

        lastUpdated = block.timestamp;

        emit Events.FeeUpdated(0, initialFee);
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deposits a specified amount of assets into the vault, minting a corresponding amount of shares.
     *
     * @param assets The amount of underlying asset to deposit
     * @param receiver The address to receive the shares
     *
     * @return shares The amount of shares minted to the receiver
     */
    function deposit(uint256 assets, address receiver) public override returns (uint256 shares) {
        shares = _deposit(assets, receiver, msg.sender);
    }

    /**
     * @notice Deposits a specified amount of assets into the vault, minting a corresponding amount of shares,
     * using an EIP721 signature to enable a third-party to call this function on behalf of the depositor.
     *
     * @param assets The amount of underlying asset to deposit
     * @param receiver The address to receive the shares
     * @param depositor The address from which to pull the assets for the deposit
     * @param permitSig An EIP721 signature to increase depositor's allowance for vault
     * @param depositSig An EIP721 signature from the depositor to allow this function to be called on their behalf
     *
     * @return shares The amount of shares minted to the receiver
     */

    function depositWithSig(
        uint256 assets,
        address receiver,
        address depositor,
        DataTypes.EIP712Signature calldata permitSig,
        DataTypes.EIP712Signature calldata depositSig
    ) public returns (uint256 shares) {
        // Permit is allowed to fail - approval has been done separately, or token may not support permit
        try
            asset.permit(depositor, address(this), assets, permitSig.deadline, permitSig.v, permitSig.r, permitSig.s)
        {} catch {}

        // TODO alternatively could use permitSig.deadline != 0 to skip if needed
        // if (permitSig.deadline != 0)
        //     asset.permit(depositor, address(this), assets, permitSig.deadline, permitSig.v, permitSig.r, permitSig.s);

        unchecked {
            MetaTxHelpers._validateRecoveredAddress(
                MetaTxHelpers._calculateDigest(
                    keccak256(
                        abi.encode(
                            DEPOSIT_WITH_SIG_TYPEHASH,
                            assets,
                            receiver,
                            depositor,
                            sigNonces[depositor]++,
                            depositSig.deadline
                        )
                    ),
                    DOMAIN_SEPARATOR()
                ),
                depositor,
                depositSig
            );
        }
        shares = _deposit(assets, receiver, depositor);
    }

    /**
     * @notice Mints a specified amount of shares to the receiver, depositing the corresponding amount of assets.
     *
     * @param shares The amount of shares to mint
     * @param receiver The address to receive the shares
     *
     * @return assets The amount of assets deposited by the receiver
     */
    function mint(uint256 shares, address receiver) public override returns (uint256 assets) {
        assets = _mint(shares, receiver, msg.sender);
    }

    /**
     * @notice Mints a specified amount of shares to the receiver, depositing the corresponding amount of assets,
     * using an EIP721 signature to enable a third-party to call this function on behalf of the depositor.
     *
     * @param shares The amount of shares to mint
     * @param receiver The address to receive the shares
     * @param depositor The address from which to pull the assets for the deposit
     * @param permitSig An EIP721 signature to increase depositor's allowance for vault
     * @param mintSig An EIP721 signature from the depositor to allow this function to be called on their behalf
     *
     * @return assets The amount of assets deposited by the receiver
     */
    function mintWithSig(
        uint256 shares,
        address receiver,
        address depositor,
        DataTypes.EIP712Signature calldata permitSig,
        DataTypes.EIP712Signature calldata mintSig
    ) public returns (uint256 assets) {
        //yield accrued here for share conversion, will be skipped in _mint
        _accrueYield();
        assets = previewMint(shares);

        // Permit is allowed to fail - approval has been done separately, or token may not support permit
        try
            asset.permit(depositor, address(this), assets, permitSig.deadline, permitSig.v, permitSig.r, permitSig.s)
        {} catch {}

        unchecked {
            MetaTxHelpers._validateRecoveredAddress(
                MetaTxHelpers._calculateDigest(
                    keccak256(
                        abi.encode(
                            MINT_WITH_SIG_TYPEHASH,
                            shares,
                            receiver,
                            depositor,
                            sigNonces[depositor]++,
                            mintSig.deadline
                        )
                    ),
                    DOMAIN_SEPARATOR()
                ),
                depositor,
                mintSig
            );
        }
        assets = _mint(shares, receiver, depositor);
    }

    /**
     * @notice Withdraws a specified amount of assets from the vault, burning the corresponding amount of shares.
     *
     * @param assets The amount of assets to withdraw
     * @param receiver The address to receive the assets
     * @param owner The address from which to pull the shares for the withdrawal
     *
     * @return shares The amount of shares burnt in the withdrawal process
     */
    function withdraw(uint256 assets, address receiver, address owner) public override returns (uint256 shares) {
        shares = _withdraw(assets, receiver, owner);
    }

    /**
     * @notice Withdraws a specified amount of assets from the vault, burning the corresponding amount of shares,
     * using an EIP721 signature to enable a third-party to call this function on behalf of the owner.
     *
     * @param assets The amount of assets to withdraw
     * @param receiver The address to receive the assets
     * @param owner The address from which to pull the shares for the withdrawal
     * @param sig An EIP721 signature from the owner to allow this function to be called on their behalf
     *
     * @return shares The amount of shares burnt in the withdrawal process
     */
    function withdrawWithSig(
        uint256 assets,
        address receiver,
        address owner,
        DataTypes.EIP712Signature calldata sig
    ) public returns (uint256 shares) {
        unchecked {
            MetaTxHelpers._validateRecoveredAddress(
                MetaTxHelpers._calculateDigest(
                    keccak256(
                        abi.encode(WITHDRAW_WITH_SIG_TYPEHASH, assets, receiver, owner, sigNonces[owner]++, sig.deadline)
                    ),
                    DOMAIN_SEPARATOR()
                ),
                owner,
                sig
            );
        }
        shares = _withdraw(assets, receiver, owner);
    }

    /**
     * @notice Burns a specified amount of shares from the vault, withdrawing the corresponding amount of assets.
     *
     * @param shares The amount of shares to burn
     * @param receiver The address to receive the assets
     * @param owner The address from which to pull the shares for the withdrawal
     *
     * @return assets The amount of assets withdrawn by the receiver
     */
    function redeem(uint256 shares, address receiver, address owner) public override returns (uint256 assets) {
        assets = _redeem(shares, receiver, owner);
    }

    /**
     * @notice Burns a specified amount of shares from the vault, withdrawing the corresponding amount of assets,
     * using an EIP721 signature to enable a third-party to call this function on behalf of the owner.
     *
     * @param shares The amount of shares to burn
     * @param receiver The address to receive the assets
     * @param owner The address from which to pull the shares for the withdrawal
     * @param sig An EIP721 signature from the owner to allow this function to be called on their behalf
     *
     * @return assets The amount of assets withdrawn by the receiver
     */
    function redeemWithSig(
        uint256 shares,
        address receiver,
        address owner,
        DataTypes.EIP712Signature calldata sig
    ) public returns (uint256 assets) {
        unchecked {
            MetaTxHelpers._validateRecoveredAddress(
                MetaTxHelpers._calculateDigest(
                    keccak256(abi.encode(REDEEM_WITH_SIG_TYPEHASH, shares, receiver, owner, sigNonces[owner]++, sig.deadline)),
                    DOMAIN_SEPARATOR()
                ),
                owner,
                sig
            );
        }
        assets = _redeem(shares, receiver, owner);
    }

    /*//////////////////////////////////////////////////////////////
                          ONLY OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the fee the vault levies on yield earned, only callable by the owner.
     *
     * @param newFee The new fee, as a fraction of 1e18.
     */
    function setFee(uint256 newFee) public onlyOwner {
        if (newFee > SCALE) revert Errors.FeeTooHigh();

        uint256 oldFee = fee;
        fee = newFee;

        emit Events.FeeUpdated(oldFee, newFee);
    }

    /**
     * @notice Updates the Aave Pool in this vault to the latest address given by the
     * Aave Pool Addresses Provider, only callable by the owner
     *
     */
    function updateAavePool() public onlyOwner {
        address newPool = POOL_ADDRESSES_PROVIDER.getPool();
        aavePool = IPool(newPool);

        emit Events.AavePoolUpdated(newPool);
    }

    /**
     * @notice Withdraws fees earned by the vault, in the form of aTokens, to a specified address. Only callable by the owner.
     *
     * @param to The address to receive the fees
     * @param amount The amount of fees to withdraw
     *
     */
    function withdrawFees(address to, uint256 amount) public onlyOwner {
        uint256 currentFees = getCurrentFees();
        if (amount > currentFees) revert Errors.InsufficientFees(); // will underflow below anyway, error msg for clarity

        accumulatedFees = currentFees - amount;
        lastVaultBalance = aToken.balanceOf(address(this)) - amount;
        lastUpdated = block.timestamp;

        aToken.transfer(to, amount);

        emit Events.FeesWithdrawn(to, amount);
    }

    /**
     * @notice Claims any additional Aave rewards earned from vault deposits. Only callable by the owner.
     *
     * @param to The address to receive any rewards tokens.
     *
     */
    function claimAllAaveRewards(address to) public onlyOwner {
        if (to == address(0)) revert Errors.CannotSendRewardsToZeroAddress();

        address[] memory assets = new address[](1);
        assets[0] = address(aToken);

        (address[] memory rewardsList, uint256[] memory claimedAmounts) = REWARDS_CONTROLLER.claimAllRewards(assets, to);

        emit Events.AaveRewardsClaimed(to, rewardsList, claimedAmounts);
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _accrueYield() internal {
        // Fees are accrued and claimable in aToken form
        if (block.timestamp != lastUpdated) {
            uint256 newVaultBalance = aToken.balanceOf(address(this));
            uint256 newYield = newVaultBalance - lastVaultBalance;
            uint256 newFeesEarned = newYield.mulDivDown(fee, SCALE);

            accumulatedFees += newFeesEarned;

            lastVaultBalance = newVaultBalance;
            lastUpdated = block.timestamp;

            emit Events.YieldAccrued(newYield, newFeesEarned);
        }
    }

    function _deposit(uint256 assets, address receiver, address depositor) internal returns (uint256 shares) {
        _accrueYield();

        require((shares = previewDeposit(assets)) != 0, "ZERO_SHARES");

        // Need to transfer before minting or ERC777s could reenter.
        asset.safeTransferFrom(depositor, address(this), assets);

        // Approve and Deposit the received underlying into Aave v3
        asset.approve(address(aavePool), assets);
        aavePool.supply(address(asset), assets, address(this), 0);

        lastVaultBalance = aToken.balanceOf(address(this));

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function _mint(uint256 shares, address receiver, address depositor) internal returns (uint256 assets) {
        _accrueYield();

        assets = previewMint(shares);

        // Need to transfer before minting or ERC777s could reenter.
        asset.safeTransferFrom(depositor, address(this), assets);

        // Approve and Deposit the received underlying into Aave v3
        asset.approve(address(aavePool), assets);
        aavePool.supply(address(asset), assets, address(this), 0);

        lastVaultBalance = aToken.balanceOf(address(this));

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function _withdraw(uint256 assets, address receiver, address owner) internal returns (uint256 shares) {
        _accrueYield();

        shares = previewWithdraw(assets); // No need to check for rounding error, previewWithdraw rounds up.

        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
        }

        _burn(owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        // Withdraw assets from Aave v3 and send to receiver
        aavePool.withdraw(address(asset), assets, receiver);
        lastVaultBalance = aToken.balanceOf(address(this));
    }

    function _redeem(uint256 shares, address receiver, address owner) internal returns (uint256 assets) {
        _accrueYield();

        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender];

            if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
        }

        require((assets = previewRedeem(shares)) != 0, "ZERO_ASSETS");

        _burn(owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        // Withdraw assets from Aave v3 and send to receiver
        aavePool.withdraw(address(asset), assets, receiver);
        lastVaultBalance = aToken.balanceOf(address(this));
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function totalAssets() public view override returns (uint256) {
        // Report only the total assets net of fees, for vault share logic
        return aToken.balanceOf(address(this)) - getCurrentFees();
    }

    function getCurrentFees() public view returns (uint256) {
        if (block.timestamp == lastUpdated) {
            // Accumulated fees already up to date
            return accumulatedFees;
        } else {
            // Calculate new fees since last accrueYield
            uint256 newVaultBalance = aToken.balanceOf(address(this));
            uint256 newYield = newVaultBalance - lastVaultBalance;
            uint256 newFees = newYield.mulDivDown(fee, SCALE);

            return accumulatedFees + newFees;
        }
    }
}
