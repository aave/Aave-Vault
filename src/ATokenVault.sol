// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {ERC4626Upgradeable} from "@openzeppelin-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import {SafeERC20Upgradeable} from "@openzeppelin-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IERC20Upgradeable} from "@openzeppelin-upgradeable/interfaces/IERC20Upgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {MathUpgradeable} from "@openzeppelin-upgradeable/utils/math/MathUpgradeable.sol";
import {IPoolAddressesProvider} from "@aave-v3-core/interfaces/IPoolAddressesProvider.sol";
import {IPool} from "@aave-v3-core/interfaces/IPool.sol";
import {IAToken} from "@aave-v3-core/interfaces/IAToken.sol";
import {DataTypes as AaveDataTypes} from "@aave-v3-core/protocol/libraries/types/DataTypes.sol";
import {WadRayMath} from "@aave-v3-core/protocol/libraries/math/WadRayMath.sol";
import {IRewardsController} from "@aave-v3-periphery/rewards/interfaces/IRewardsController.sol";
import {IATokenVault} from "./interfaces/IATokenVault.sol";
import {MetaTxHelpers} from "./libraries/MetaTxHelpers.sol";
import "./libraries/Constants.sol";
import {ATokenVaultStorage} from "./ATokenVaultStorage.sol";

/**
 * @title ATokenVault
 * @author Aave Protocol
 * @notice An ERC-4626 vault for Aave V3, with support to add a fee on yield earned.
 */
contract ATokenVault is ERC4626Upgradeable, OwnableUpgradeable, EIP712Upgradeable, ATokenVaultStorage, IATokenVault {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using MathUpgradeable for uint256;

    /// @inheritdoc IATokenVault
    IPoolAddressesProvider public immutable POOL_ADDRESSES_PROVIDER;

    /// @inheritdoc IATokenVault
    IPool public immutable AAVE_POOL;

    /// @inheritdoc IATokenVault
    IAToken public immutable ATOKEN;

    /// @inheritdoc IATokenVault
    IERC20Upgradeable public immutable UNDERLYING;

    /// @inheritdoc IATokenVault
    uint16 public immutable REFERRAL_CODE;

    /**
     * @dev Constructor,
     * @param underlying The underlying ERC20 asset which can be supplied to Aave
     * @param referralCode The Aave referral code to use for deposits from this vault
     * @param poolAddressesProvider The address of the Aave v3 Pool Addresses Provider
     */
    constructor(
        address underlying,
        uint16 referralCode,
        IPoolAddressesProvider poolAddressesProvider
    ) {
        _disableInitializers();
        POOL_ADDRESSES_PROVIDER = poolAddressesProvider;
        AAVE_POOL = IPool(poolAddressesProvider.getPool());
        REFERRAL_CODE = referralCode;
        UNDERLYING = IERC20Upgradeable(underlying);

        address aTokenAddress = AAVE_POOL.getReserveData(address(underlying)).aTokenAddress;
        require(aTokenAddress != address(0), "ASSET_NOT_SUPPORTED");
        ATOKEN = IAToken(aTokenAddress);
    }

    /**
     * @notice Initializes the vault, setting the initial parameters and initializing inherited contracts.
     * @dev It requires an initial non-zero deposit to prevent a frontrunning attack (in underlying atokens). Note
     * that care should be taken to provide a non-trivial amount, but this depends on the underlying asset's decimals.
     * @dev It does not initialize the OwnableUpgradeable contract to avoid setting the proxy admin as the owner.
     * @param owner The owner to set
     * @param initialFee The initial fee to set, expressed in wad, where 1e18 is 100%
     * @param shareName The name to set for this vault
     * @param shareSymbol The symbol to set for this vault
     * @param initialLockDeposit The initial amount of underlying assets to deposit
     */
    function initialize(
        address owner,
        uint256 initialFee,
        string memory shareName,
        string memory shareSymbol,
        uint256 initialLockDeposit
    ) external initializer {
        require(initialLockDeposit != 0, "ZERO_INITIAL_LOCK_DEPOSIT");
        _transferOwnership(owner);
        __ERC4626_init(UNDERLYING);
        __ERC20_init(shareName, shareSymbol);
        __EIP712_init(shareName, "1");
        _setFee(initialFee);

        UNDERLYING.safeApprove(address(AAVE_POOL), type(uint256).max);

        _handleDeposit(initialLockDeposit, address(this), msg.sender, false);
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IATokenVault
    function deposit(uint256 assets, address receiver)
        public
        override(ERC4626Upgradeable, IATokenVault)
        returns (uint256 shares)
    {
        shares = _handleDeposit(assets, receiver, msg.sender, false);
    }

    /// @inheritdoc IATokenVault
    function depositATokens(uint256 assets, address receiver) public returns (uint256 shares) {
        shares = _handleDeposit(assets, receiver, msg.sender, true);
    }

    /// @inheritdoc IATokenVault
    function depositWithSig(
        uint256 assets,
        address receiver,
        address depositor,
        EIP712Signature calldata sig
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
                            sig.deadline
                        )
                    ),
                    _domainSeparatorV4()
                ),
                depositor,
                sig
            );
        }
        shares = _handleDeposit(assets, receiver, depositor, false);
    }

    /// @inheritdoc IATokenVault
    function depositATokensWithSig(
        uint256 assets,
        address receiver,
        address depositor,
        EIP712Signature calldata sig
    ) public returns (uint256 shares) {
        unchecked {
            MetaTxHelpers._validateRecoveredAddress(
                MetaTxHelpers._calculateDigest(
                    keccak256(
                        abi.encode(
                            DEPOSIT_ATOKENS_WITH_SIG_TYPEHASH,
                            assets,
                            receiver,
                            depositor,
                            _sigNonces[depositor]++,
                            sig.deadline
                        )
                    ),
                    _domainSeparatorV4()
                ),
                depositor,
                sig
            );
        }
        shares = _handleDeposit(assets, receiver, depositor, true);
    }

    /// @inheritdoc IATokenVault
    function mint(uint256 shares, address receiver) public override(ERC4626Upgradeable, IATokenVault) returns (uint256 assets) {
        assets = _handleMint(shares, receiver, msg.sender, false);
    }

    /// @inheritdoc IATokenVault
    function mintWithATokens(uint256 shares, address receiver) public returns (uint256 assets) {
        assets = _handleMint(shares, receiver, msg.sender, true);
    }

    /// @inheritdoc IATokenVault
    function mintWithSig(
        uint256 shares,
        address receiver,
        address depositor,
        EIP712Signature calldata sig
    ) public returns (uint256 assets) {
        unchecked {
            MetaTxHelpers._validateRecoveredAddress(
                MetaTxHelpers._calculateDigest(
                    keccak256(
                        abi.encode(MINT_WITH_SIG_TYPEHASH, shares, receiver, depositor, _sigNonces[depositor]++, sig.deadline)
                    ),
                    _domainSeparatorV4()
                ),
                depositor,
                sig
            );
        }
        assets = _handleMint(shares, receiver, depositor, false);
    }

    /// @inheritdoc IATokenVault
    function mintWithATokensWithSig(
        uint256 shares,
        address receiver,
        address depositor,
        EIP712Signature calldata sig
    ) public returns (uint256 assets) {
        unchecked {
            MetaTxHelpers._validateRecoveredAddress(
                MetaTxHelpers._calculateDigest(
                    keccak256(
                        abi.encode(
                            MINT_WITH_ATOKENS_WITH_SIG_TYPEHASH,
                            shares,
                            receiver,
                            depositor,
                            _sigNonces[depositor]++,
                            sig.deadline
                        )
                    ),
                    _domainSeparatorV4()
                ),
                depositor,
                sig
            );
        }
        assets = _handleMint(shares, receiver, depositor, true);
    }

    /// @inheritdoc IATokenVault
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public override(ERC4626Upgradeable, IATokenVault) returns (uint256 shares) {
        shares = _handleWithdraw(assets, receiver, owner, msg.sender, false);
    }

    /// @inheritdoc IATokenVault
    function withdrawATokens(
        uint256 assets,
        address receiver,
        address owner
    ) public returns (uint256 shares) {
        shares = _handleWithdraw(assets, receiver, owner, msg.sender, true);
    }

    /// @inheritdoc IATokenVault
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
                    _domainSeparatorV4()
                ),
                owner,
                sig
            );
        }
        shares = _handleWithdraw(assets, receiver, owner, owner, false);
    }

    /// @inheritdoc IATokenVault
    function withdrawATokensWithSig(
        uint256 assets,
        address receiver,
        address owner,
        EIP712Signature calldata sig
    ) public returns (uint256 shares) {
        unchecked {
            MetaTxHelpers._validateRecoveredAddress(
                MetaTxHelpers._calculateDigest(
                    keccak256(
                        abi.encode(
                            WITHDRAW_ATOKENS_WITH_SIG_TYPEHASH,
                            assets,
                            receiver,
                            owner,
                            _sigNonces[owner]++,
                            sig.deadline
                        )
                    ),
                    _domainSeparatorV4()
                ),
                owner,
                sig
            );
        }
        shares = _handleWithdraw(assets, receiver, owner, owner, true);
    }

    /// @inheritdoc IATokenVault
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public override(ERC4626Upgradeable, IATokenVault) returns (uint256 assets) {
        assets = _handleRedeem(shares, receiver, owner, msg.sender, false);
    }

    /// @inheritdoc IATokenVault
    function redeemAsATokens(
        uint256 shares,
        address receiver,
        address owner
    ) public returns (uint256 assets) {
        assets = _handleRedeem(shares, receiver, owner, msg.sender, true);
    }

    /// @inheritdoc IATokenVault
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
                    _domainSeparatorV4()
                ),
                owner,
                sig
            );
        }
        assets = _handleRedeem(shares, receiver, owner, owner, false);
    }

    /// @inheritdoc IATokenVault
    function redeemWithATokensWithSig(
        uint256 shares,
        address receiver,
        address owner,
        EIP712Signature calldata sig
    ) public returns (uint256 assets) {
        unchecked {
            MetaTxHelpers._validateRecoveredAddress(
                MetaTxHelpers._calculateDigest(
                    keccak256(
                        abi.encode(
                            REDEEM_WITH_ATOKENS_WITH_SIG_TYPEHASH,
                            shares,
                            receiver,
                            owner,
                            _sigNonces[owner]++,
                            sig.deadline
                        )
                    ),
                    _domainSeparatorV4()
                ),
                owner,
                sig
            );
        }
        assets = _handleRedeem(shares, receiver, owner, owner, true);
    }

    /// @inheritdoc IATokenVault
    function maxDeposit(address) public view override(ERC4626Upgradeable, IATokenVault) returns (uint256) {
        return _maxAssetsSuppliableToAave();
    }

    /// @inheritdoc IATokenVault
    function maxMint(address) public view override(ERC4626Upgradeable, IATokenVault) returns (uint256) {
        return convertToShares(_maxAssetsSuppliableToAave());
    }

    /// @inheritdoc IATokenVault
    function domainSeparator() public view returns (bytes32) {
        return _domainSeparatorV4();
    }

    /*//////////////////////////////////////////////////////////////
                          ONLY OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IATokenVault
    function setFee(uint256 newFee) public onlyOwner {
        _accrueYield();
        _setFee(newFee);
    }

    /// @inheritdoc IATokenVault
    function withdrawFees(address to, uint256 amount) public onlyOwner {
        uint256 claimableFees = getClaimableFees();
        require(amount <= claimableFees, "INSUFFICIENT_FEES"); // will underflow below anyway, error msg for clarity

        _accumulatedFees = uint128(claimableFees - amount);
        _lastVaultBalance = uint128(ATOKEN.balanceOf(address(this)) - amount);
        _lastUpdated = uint40(block.timestamp);

        ATOKEN.transfer(to, amount);

        emit FeesWithdrawn(to, amount, _lastVaultBalance, _accumulatedFees);
    }

    /// @inheritdoc IATokenVault
    function claimRewards(address to) public onlyOwner {
        require(to != address(0), "CANNOT_CLAIM_TO_ZERO_ADDRESS");

        address[] memory assets = new address[](1);
        assets[0] = address(ATOKEN);
        (address[] memory rewardsList, uint256[] memory claimedAmounts) = IRewardsController(
            POOL_ADDRESSES_PROVIDER.getAddress(REWARDS_CONTROLLER_ID)
        ).claimAllRewards(assets, to);

        emit RewardsClaimed(to, rewardsList, claimedAmounts);
    }

    /// @inheritdoc IATokenVault
    function emergencyRescue(
        address token,
        address to,
        uint256 amount
    ) public onlyOwner {
        require(token != address(ATOKEN), "CANNOT_RESCUE_ATOKEN");

        IERC20Upgradeable(token).safeTransfer(to, amount);

        emit EmergencyRescue(token, to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IATokenVault
    function totalAssets() public view override(ERC4626Upgradeable, IATokenVault) returns (uint256) {
        // Report only the total assets net of fees, for vault share logic
        return ATOKEN.balanceOf(address(this)) - getClaimableFees();
    }

    /// @inheritdoc IATokenVault
    function getClaimableFees() public view returns (uint256) {
        if (block.timestamp == _lastUpdated) {
            // Accumulated fees already up to date
            return _accumulatedFees;
        } else {
            // Calculate new fees since last accrueYield
            uint256 newVaultBalance = ATOKEN.balanceOf(address(this));
            uint256 newYield = newVaultBalance - _lastVaultBalance;
            uint256 newFees = newYield.mulDiv(_fee, SCALE, MathUpgradeable.Rounding.Down);

            return _accumulatedFees + newFees;
        }
    }

    /// @inheritdoc IATokenVault
    function getSigNonce(address signer) public view returns (uint256) {
        return _sigNonces[signer];
    }

    /// @inheritdoc IATokenVault
    function getLastUpdated() public view returns (uint256) {
        return _lastUpdated;
    }

    /// @inheritdoc IATokenVault
    function getLastVaultBalance() public view returns (uint256) {
        return _lastVaultBalance;
    }

    /// @inheritdoc IATokenVault
    function getFee() public view returns (uint256) {
        return _fee;
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _setFee(uint256 newFee) internal {
        require(newFee <= SCALE, "FEE_TOO_HIGH");

        uint256 oldFee = _fee;
        _fee = uint64(newFee);

        emit FeeUpdated(oldFee, newFee);
    }

    function _accrueYield() internal {
        if (block.timestamp != _lastUpdated) {
            uint256 newVaultBalance = ATOKEN.balanceOf(address(this));
            uint256 newYield = newVaultBalance - _lastVaultBalance;
            uint256 newFeesEarned = newYield.mulDiv(_fee, SCALE, MathUpgradeable.Rounding.Down);

            _accumulatedFees += uint128(newFeesEarned);
            _lastVaultBalance = uint128(newVaultBalance);
            _lastUpdated = uint40(block.timestamp);

            emit YieldAccrued(newYield, newFeesEarned, newVaultBalance);
        }
    }

    function _handleDeposit(
        uint256 assets,
        address receiver,
        address depositor,
        bool asAToken
    ) internal returns (uint256 shares) {
        require(assets <= maxDeposit(receiver), "DEPOSIT_EXCEEDS_MAX");
        _accrueYield();
        shares = previewDeposit(assets);
        require(shares != 0, "ZERO_SHARES"); // Check for rounding error since we round down in previewDeposit.
        _baseDeposit(assets, shares, depositor, receiver, asAToken);
    }

    function _handleMint(
        uint256 shares,
        address receiver,
        address depositor,
        bool asAToken
    ) internal returns (uint256 assets) {
        require(shares <= maxMint(receiver), "MINT_EXCEEDS_MAX");
        _accrueYield();
        assets = previewMint(shares); // No need to check for rounding error, previewMint rounds up.
        _baseDeposit(assets, shares, depositor, receiver, asAToken);
    }

    function _handleWithdraw(
        uint256 assets,
        address receiver,
        address owner,
        address allowanceTarget,
        bool asAToken
    ) internal returns (uint256 shares) {
        _accrueYield();
        require(assets <= maxWithdraw(owner), "WITHDRAW_EXCEEDS_MAX");
        shares = previewWithdraw(assets); // No need to check for rounding error, previewWithdraw rounds up.
        _baseWithdraw(assets, shares, owner, receiver, allowanceTarget, asAToken);
    }

    function _handleRedeem(
        uint256 shares,
        address receiver,
        address owner,
        address allowanceTarget,
        bool asAToken
    ) internal returns (uint256 assets) {
        _accrueYield();
        require(shares <= maxRedeem(owner), "REDEEM_EXCEEDS_MAX");
        assets = previewRedeem(shares);
        require(assets != 0, "ZERO_ASSETS"); // Check for rounding error since we round down in previewRedeem.
        _baseWithdraw(assets, shares, owner, receiver, allowanceTarget, asAToken);
    }

    function _maxAssetsSuppliableToAave() internal view returns (uint256) {
        // returns 0 if reserve is not active, frozen, or paused
        // returns max uint256 value if supply cap is 0 (not capped)
        // returns supply cap - current amount supplied as max suppliable if there is a supply cap for this reserve

        AaveDataTypes.ReserveData memory reserveData = AAVE_POOL.getReserveData(address(UNDERLYING));

        uint256 reserveConfigMap = reserveData.configuration.data;
        uint256 supplyCap = (reserveConfigMap & ~AAVE_SUPPLY_CAP_MASK) >> AAVE_SUPPLY_CAP_BIT_POSITION;

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
            // https://github.com/aave/aave-v3-core/blob/a00f28e3ad7c0e4a369d8e06e0ac9fd0acabcab7/contracts/protocol/libraries/logic/ValidationLogic.sol#L71-L78
            return
                (supplyCap * 10**decimals()) -
                WadRayMath.rayMul(
                    (ATOKEN.scaledTotalSupply() + uint256(reserveData.accruedToTreasury)),
                    reserveData.liquidityIndex
                );
        }
    }

    function _baseDeposit(
        uint256 assets,
        uint256 shares,
        address depositor,
        address receiver,
        bool asAToken
    ) private {
        // Need to transfer before minting or ERC777s could reenter.
        if (asAToken) {
            ATOKEN.transferFrom(depositor, address(this), assets);
        } else {
            UNDERLYING.safeTransferFrom(depositor, address(this), assets);
            AAVE_POOL.supply(address(UNDERLYING), assets, address(this), REFERRAL_CODE);
        }

        _lastVaultBalance += uint128(assets);
        _mint(receiver, shares);

        emit Deposit(depositor, receiver, assets, shares);
    }

    function _baseWithdraw(
        uint256 assets,
        uint256 shares,
        address owner,
        address receiver,
        address allowanceTarget,
        bool asAToken
    ) private {
        if (allowanceTarget != owner) {
            _spendAllowance(owner, allowanceTarget, shares);
        }

        _lastVaultBalance -= uint128(assets);
        _burn(owner, shares);

        // Withdraw assets from Aave v3 and send to receiver
        if (asAToken) {
            ATOKEN.transfer(receiver, assets);
        } else {
            AAVE_POOL.withdraw(address(UNDERLYING), assets, receiver);
        }

        emit Withdraw(allowanceTarget, receiver, owner, assets, shares);
    }
}
