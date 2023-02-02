// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {ERC4626, SafeTransferLib, FixedPointMathLib} from "solmate/mixins/ERC4626.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {WadRayMath} from "aave/protocol/libraries/math/WadRayMath.sol";
import {DataTypes as AaveDataTypes} from "aave/protocol/libraries/types/DataTypes.sol";
import {IPoolAddressesProvider} from "aave/interfaces/IPoolAddressesProvider.sol";
import {IRewardsController} from "aave-periphery/rewards/interfaces/IRewardsController.sol";
import {IPool} from "aave/interfaces/IPool.sol";
import {IAToken} from "aave/interfaces/IAToken.sol";

// Interface
import {IATokenVault} from "./interfaces/IATokenVault.sol";

// Libraries
import {MetaTxHelpers} from "./libraries/MetaTxHelpers.sol";
import "./libraries/Constants.sol";

/**
 * @title ATokenVault
 * @author Aave Protocol
 *
 * @notice An ERC-4626 vault for ERC20 assets supported by Aave v3,
 * with a potential vault fee on yield earned.
 */
contract ATokenVault is ERC4626, Ownable, IATokenVault {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    uint256 internal constant SCALE = 1e18;
    uint256 internal constant RAY = 1e27;
    uint256 internal constant HALF_RAY = 0.5e27;
    bytes32 internal constant REWARDS_CONTROLLER_ID = 0x703c2c8634bed68d98c029c18f310e7f7ec0e5d6342c590190b3cb8b3ba54532;

    IPoolAddressesProvider public immutable POOL_ADDRESSES_PROVIDER;
    IPool public immutable AAVE_POOL;
    IAToken public immutable A_TOKEN;

    mapping(address => uint256) internal _sigNonces;

    uint256 internal _lastUpdated; // timestamp of last accrueYield action
    uint256 internal _lastVaultBalance; // total aToken incl. fees
    uint256 internal _fee; // as a fraction of 1e18
    uint256 internal _accumulatedFees; // fees accrued since last updated

    /**
     * @param underlying The underlying ERC20 asset which can be supplied to Aave
     * @param shareName The name of the share token for this vault
     * @param shareSymbol The symbol of the share token for this vault
     * @param initialFee The fee taken on yield earned, as a fraction of 1e18
     * @param poolAddressesProvider The address of the Aave v3 Pool Addresses Provider
     */
    constructor(
        ERC20 underlying,
        string memory shareName,
        string memory shareSymbol,
        uint256 initialFee,
        IPoolAddressesProvider poolAddressesProvider
    ) ERC4626(underlying, shareName, shareSymbol) {
        POOL_ADDRESSES_PROVIDER = poolAddressesProvider;
        AAVE_POOL = IPool(poolAddressesProvider.getPool());

        address aTokenAddress = AAVE_POOL.getReserveData(address(underlying)).aTokenAddress;
        require(aTokenAddress != address(0), "ASSET_NOT_SUPPORTED");
        A_TOKEN = IAToken(aTokenAddress);

        _setFee(initialFee);
        _lastUpdated = block.timestamp;
        asset.approve(address(AAVE_POOL), type(uint256).max);
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
        shares = _handleDeposit(assets, receiver, msg.sender);
    }

    /**
     * @notice Deposits a specified amount of assets into the vault, minting a corresponding amount of shares,
     * using an EIP721 signature to enable a third-party to call this function on behalf of the depositor.
     *
     * @param assets The amount of underlying asset to deposit
     * @param receiver The address to receive the shares
     * @param depositor The address from which to pull the assets for the deposit
     * @param depositSig An EIP721 signature from the depositor to allow this function to be called on their behalf
     *
     * @return shares The amount of shares minted to the receiver
     */
    function depositWithSig(
        uint256 assets,
        address receiver,
        address depositor,
        EIP712Signature calldata depositSig
    ) public returns (uint256 shares) {
        unchecked {
            MetaTxHelpers._validateRecoveredAddress(
                MetaTxHelpers._calculateDigest(
                    keccak256(
                        abi.encode(
                            DEPOSIT_WITH_SIG_TYPEHASH,
                            assets,
                            receiver,
                            depositor,
                            _sigNonces[depositor]++,
                            depositSig.deadline
                        )
                    ),
                    DOMAIN_SEPARATOR()
                ),
                depositor,
                depositSig
            );
        }
        shares = _handleDeposit(assets, receiver, depositor);
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
    function permitAndDepositWithSig(
        uint256 assets,
        address receiver,
        address depositor,
        EIP712Signature calldata permitSig,
        EIP712Signature calldata depositSig
    ) public returns (uint256 shares) {
        asset.permit(depositor, address(this), assets, permitSig.deadline, permitSig.v, permitSig.r, permitSig.s);

        unchecked {
            MetaTxHelpers._validateRecoveredAddress(
                MetaTxHelpers._calculateDigest(
                    keccak256(
                        abi.encode(
                            DEPOSIT_WITH_SIG_TYPEHASH,
                            assets,
                            receiver,
                            depositor,
                            _sigNonces[depositor]++,
                            depositSig.deadline
                        )
                    ),
                    DOMAIN_SEPARATOR()
                ),
                depositor,
                depositSig
            );
        }
        shares = _handleDeposit(assets, receiver, depositor);
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
        assets = _handleMint(shares, receiver, msg.sender);
    }

    /**
     * @notice Mints a specified amount of shares to the receiver, depositing the corresponding amount of assets,
     * using an EIP721 signature to enable a third-party to call this function on behalf of the depositor.
     *
     * @param shares The amount of shares to mint
     * @param receiver The address to receive the shares
     * @param depositor The address from which to pull the assets for the deposit
     * @param mintSig An EIP721 signature from the depositor to allow this function to be called on their behalf
     *
     * @return assets The amount of assets deposited by the receiver
     */
    function mintWithSig(
        uint256 shares,
        address receiver,
        address depositor,
        EIP712Signature calldata mintSig
    ) public returns (uint256 assets) {
        unchecked {
            MetaTxHelpers._validateRecoveredAddress(
                MetaTxHelpers._calculateDigest(
                    keccak256(
                        abi.encode(
                            MINT_WITH_SIG_TYPEHASH,
                            shares,
                            receiver,
                            depositor,
                            _sigNonces[depositor]++,
                            mintSig.deadline
                        )
                    ),
                    DOMAIN_SEPARATOR()
                ),
                depositor,
                mintSig
            );
        }
        assets = _handleMint(shares, receiver, depositor);
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
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public override returns (uint256 shares) {
        shares = _handleWithdraw(assets, receiver, owner, msg.sender);
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
        EIP712Signature calldata sig
    ) public returns (uint256 shares) {
        unchecked {
            MetaTxHelpers._validateRecoveredAddress(
                MetaTxHelpers._calculateDigest(
                    keccak256(
                        abi.encode(WITHDRAW_WITH_SIG_TYPEHASH, assets, receiver, owner, _sigNonces[owner]++, sig.deadline)
                    ),
                    DOMAIN_SEPARATOR()
                ),
                owner,
                sig
            );
        }
        shares = _handleWithdraw(assets, receiver, owner, receiver);
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
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public override returns (uint256 assets) {
        assets = _handleRedeem(shares, receiver, owner, msg.sender);
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
        EIP712Signature calldata sig
    ) public returns (uint256 assets) {
        unchecked {
            MetaTxHelpers._validateRecoveredAddress(
                MetaTxHelpers._calculateDigest(
                    keccak256(abi.encode(REDEEM_WITH_SIG_TYPEHASH, shares, receiver, owner, _sigNonces[owner]++, sig.deadline)),
                    DOMAIN_SEPARATOR()
                ),
                owner,
                sig
            );
        }
        assets = _handleRedeem(shares, receiver, owner, receiver);
    }

    /**
     * @notice Maximum amount of assets that can be deposited into the vault,
     * given Aave market limitations.
     *
     * @return Maximum amount of assets that can be deposited into the vault
     */
    function maxDeposit(address) public view override returns (uint256) {
        return _maxAssetsSuppliableToAave();
    }

    /**
     * @notice Maximum amount of shares that can be minted for the vault,
     * given Aave market limitations.
     *
     * @return Maximum amount of shares that can be minted for the vault
     */
    function maxMint(address) public view override returns (uint256) {
        return convertToShares(_maxAssetsSuppliableToAave());
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
        _accrueYield();
        _setFee(newFee);
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
        require(amount <= currentFees, "INSUFFICIENT_FEES"); // will underflow below anyway, error msg for clarity

        _accumulatedFees = currentFees - amount;
        _lastVaultBalance = A_TOKEN.balanceOf(address(this)) - amount;
        _lastUpdated = block.timestamp;

        A_TOKEN.transfer(to, amount);

        emit FeesWithdrawn(to, amount, _lastVaultBalance, _accumulatedFees);
    }

    /**
     * @notice Claims any additional Aave rewards earned from vault deposits. Only callable by the owner.
     *
     * @param to The address to receive any rewards tokens.
     *
     */
    function claimAllAaveRewards(address to) public onlyOwner {
        require(to != address(0), "CANNOT_CLAIM_TO_ZERO_ADDRESS");

        address[] memory assets = new address[](1);
        assets[0] = address(A_TOKEN);

        (address[] memory rewardsList, uint256[] memory claimedAmounts) = IRewardsController(
            POOL_ADDRESSES_PROVIDER.getAddress(REWARDS_CONTROLLER_ID)
        ).claimAllRewards(assets, to);

        emit AaveRewardsClaimed(to, rewardsList, claimedAmounts);
    }

    /**
     * @notice Allows the owner to rescue any tokens other than the vault's aToken which may have accidentally
     * been transferred to this contract
     *
     * @param token The address of the token to rescue.
     * @param to The address to receive rescued tokens.
     * @param amount The amount of tokens to transfer.
     *
     */
    function emergencyRescue(
        address token,
        address to,
        uint256 amount
    ) public onlyOwner {
        require(token != address(A_TOKEN), "CANNOT_RESCUE_ATOKEN");

        ERC20(token).transfer(to, amount);

        emit EmergencyRescue(token, to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function totalAssets() public view override returns (uint256) {
        // Report only the total assets net of fees, for vault share logic
        return A_TOKEN.balanceOf(address(this)) - getCurrentFees();
    }

    function getCurrentFees() public view returns (uint256) {
        if (block.timestamp == _lastUpdated) {
            // Accumulated fees already up to date
            return _accumulatedFees;
        } else {
            // Calculate new fees since last accrueYield
            uint256 newVaultBalance = A_TOKEN.balanceOf(address(this));
            uint256 newYield = newVaultBalance - _lastVaultBalance;
            uint256 newFees = newYield.mulDivDown(_fee, SCALE);

            return _accumulatedFees + newFees;
        }
    }

    function getSigNonce(address signer) public view returns (uint256) {
        return _sigNonces[signer];
    }

    function getLastUpdated() public view returns (uint256) {
        return _lastUpdated;
    }

    function getLastVaultBalance() public view returns (uint256) {
        return _lastVaultBalance;
    }

    function getFee() public view returns (uint256) {
        return _fee;
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _setFee(uint256 newFee) internal {
        require(newFee <= SCALE, "FEE_TOO_HIGH");

        uint256 oldFee = _fee;
        _fee = newFee;

        emit FeeUpdated(oldFee, newFee);
    }

    function _accrueYield() internal {
        // Fees are accrued and claimable in aToken form
        if (block.timestamp != _lastUpdated) {
            uint256 newVaultBalance = A_TOKEN.balanceOf(address(this));
            uint256 newYield = newVaultBalance - _lastVaultBalance;
            uint256 newFeesEarned = newYield.mulDivDown(_fee, SCALE);

            _accumulatedFees += newFeesEarned;

            _lastVaultBalance = newVaultBalance;
            _lastUpdated = block.timestamp;

            emit YieldAccrued(newYield, newFeesEarned, newVaultBalance);
        }
    }

    function _handleDeposit(
        uint256 assets,
        address receiver,
        address depositor
    ) internal returns (uint256 shares) {
        _accrueYield();

        shares = previewDeposit(assets);

        // Check for rounding error since we round down in previewDeposit.
        require(shares != 0, "ZERO_SHARES");

        // Need to transfer before minting or ERC777s could reenter.
        asset.safeTransferFrom(depositor, address(this), assets);

        // Deposit the received underlying into Aave v3
        AAVE_POOL.supply(address(asset), assets, address(this), 0);

        _lastVaultBalance += assets;

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function _handleMint(
        uint256 shares,
        address receiver,
        address depositor
    ) internal returns (uint256 assets) {
        _accrueYield();

        assets = previewMint(shares); // No need to check for rounding error, previewMint rounds up.

        // Need to transfer before minting or ERC777s could reenter.
        asset.safeTransferFrom(depositor, address(this), assets);

        // Deposit the received underlying into Aave v3
        AAVE_POOL.supply(address(asset), assets, address(this), 0);

        _lastVaultBalance = A_TOKEN.balanceOf(address(this));

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function _handleWithdraw(
        uint256 assets,
        address receiver,
        address owner,
        address allowanceTarget
    ) internal returns (uint256 shares) {
        _accrueYield();

        shares = previewWithdraw(assets); // No need to check for rounding error, previewWithdraw rounds up.

        // Check caller has allowance if not with sig
        // Check receiver has allowance if with sig
        if (allowanceTarget != owner) {
            uint256 allowed = allowance[owner][allowanceTarget]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max) allowance[owner][allowanceTarget] = allowed - shares;
        }

        _burn(owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        // Withdraw assets from Aave v3 and send to receiver
        AAVE_POOL.withdraw(address(asset), assets, receiver);
        _lastVaultBalance = A_TOKEN.balanceOf(address(this));
    }

    function _handleRedeem(
        uint256 shares,
        address receiver,
        address owner,
        address allowanceTarget
    ) internal returns (uint256 assets) {
        _accrueYield();

        // Check caller has allowance if not with sig
        // Check receiver has allowance if with sig
        if (allowanceTarget != owner) {
            uint256 allowed = allowance[owner][allowanceTarget];

            if (allowed != type(uint256).max) allowance[owner][allowanceTarget] = allowed - shares;
        }

        assets = previewRedeem(shares);

        // Check for rounding error since we round down in previewRedeem.
        require(assets != 0, "ZERO_ASSETS");

        _burn(owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        // Withdraw assets from Aave v3 and send to receiver
        AAVE_POOL.withdraw(address(asset), assets, receiver);
        _lastVaultBalance = A_TOKEN.balanceOf(address(this));
    }

    function _maxAssetsSuppliableToAave() internal view returns (uint256) {
        // returns 0 if reserve is not active, frozen, or paused
        // returns max uint256 value if supply cap is 0 (not capped)
        // returns supply cap - current amount supplied as max suppliable if there is a supply cap for this reserve

        AaveDataTypes.ReserveData memory reserveData = AAVE_POOL.getReserveData(address(asset));

        uint256 reserveConfigMap = reserveData.configuration.data;
        uint256 supplyCap = (reserveConfigMap & ~AAVE_SUPPLY_CAP_MASK) >> AAVE_SUPPLY_CAP_BIT_POSITION;
        supplyCap = supplyCap * 10**decimals; // scale supply cap by asset's decimals

        if (
            (reserveConfigMap & ~AAVE_ACTIVE_MASK == 0) ||
            (reserveConfigMap & ~AAVE_FROZEN_MASK != 0) ||
            (reserveConfigMap & ~AAVE_PAUSED_MASK != 0)
        ) {
            return 0;
        } else if (supplyCap == 0) {
            return type(uint256).max;
        } else {
            // Reserve's supply cap - current amount supplied
            // See similar logic in Aave v3 ValidationLogic library, in the validateSupply function
            // https://github.com/aave/aave-v3-core/blob/master/contracts/protocol/libraries/logic/ValidationLogic.sol#L71-L78
            return
                supplyCap -
                WadRayMath.rayMul(
                    (A_TOKEN.scaledTotalSupply() + uint256(reserveData.accruedToTreasury)),
                    reserveData.liquidityIndex
                );
        }
    }
}
