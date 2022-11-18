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

    function deposit(uint256 assets, address receiver) public override returns (uint256 shares) {
        shares = _deposit(assets, receiver, msg.sender);
    }

    function depositWithSig(
        uint256 assets,
        address receiver,
        address depositor,
        DataTypes.EIP712Signature calldata sig
    ) public returns (uint256 shares) {
        unchecked {
            MetaTxHelpers._validateRecoveredAddress(
                MetaTxHelpers._calculateDigest(
                    keccak256(
                        abi.encode(DEPOSIT_WITH_SIG_TYPEHASH, assets, receiver, depositor, sigNonces[depositor]++, sig.deadline)
                    ),
                    DOMAIN_SEPARATOR()
                ),
                depositor,
                sig
            );
        }
        shares = _deposit(assets, receiver, depositor);
    }

    function _deposit(
        uint256 assets,
        address receiver,
        address depositor
    ) internal returns (uint256 shares) {
        _accrueYield();

        // TODO replace with custom error
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

    function mint(uint256 shares, address receiver) public override returns (uint256 assets) {
        assets = _mint(shares, receiver, msg.sender);
    }

    function mintWithSig(
        uint256 shares,
        address receiver,
        address depositor,
        DataTypes.EIP712Signature calldata sig
    ) public returns (uint256 assets) {
        unchecked {
            MetaTxHelpers._validateRecoveredAddress(
                MetaTxHelpers._calculateDigest(
                    keccak256(
                        abi.encode(MINT_WITH_SIG_TYPEHASH, shares, receiver, depositor, sigNonces[depositor]++, sig.deadline)
                    ),
                    DOMAIN_SEPARATOR()
                ),
                depositor,
                sig
            );
        }
        assets = _mint(shares, receiver, depositor);
    }

    function _mint(
        uint256 shares,
        address receiver,
        address depositor
    ) internal returns (uint256 assets) {
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

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public override returns (uint256 shares) {
        shares = _withdraw(assets, receiver, owner, false);
    }

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
        shares = _withdraw(assets, receiver, owner, true);
    }

    function _withdraw(
        uint256 assets,
        address receiver,
        address owner,
        bool withSig
    ) internal returns (uint256 shares) {
        _accrueYield();

        shares = previewWithdraw(assets); // No need to check for rounding error, previewWithdraw rounds up.

        // Check caller has allowance if not with sig
        // Check receiver has allowance if with sig
        address allowanceTarget = withSig ? receiver : msg.sender;

        if (allowanceTarget != owner) {
            uint256 allowed = allowance[owner][allowanceTarget]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max) allowance[owner][allowanceTarget] = allowed - shares;
        }

        _burn(owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        // Withdraw assets from Aave v3 and send to receiver
        aavePool.withdraw(address(asset), assets, receiver);
        lastVaultBalance = aToken.balanceOf(address(this));
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public override returns (uint256 assets) {
        assets = _redeem(shares, receiver, owner, false);
    }

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
        assets = _redeem(shares, receiver, owner, true);
    }

    function _redeem(
        uint256 shares,
        address receiver,
        address owner,
        bool withSig
    ) internal returns (uint256 assets) {
        _accrueYield();

        // Check caller has allowance if not with sig
        // Check receiver has allowance if with sig
        address allowanceTarget = withSig ? receiver : msg.sender;

        if (allowanceTarget != owner) {
            uint256 allowed = allowance[owner][allowanceTarget];

            if (allowed != type(uint256).max) allowance[owner][allowanceTarget] = allowed - shares;
        }

        require((assets = previewRedeem(shares)) != 0, "ZERO_ASSETS");

        _burn(owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        // Withdraw assets from Aave v3 and send to receiver
        aavePool.withdraw(address(asset), assets, receiver);
        lastVaultBalance = aToken.balanceOf(address(this));
    }

    /*//////////////////////////////////////////////////////////////
                          ONLY OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setFee(uint256 _newFee) public onlyOwner {
        if (_newFee > SCALE) revert Errors.FeeTooHigh();

        uint256 oldFee = fee;
        fee = _newFee;

        emit Events.FeeUpdated(oldFee, _newFee);
    }

    function updateAavePool() public onlyOwner {
        address newPool = POOL_ADDRESSES_PROVIDER.getPool();
        aavePool = IPool(newPool);

        emit Events.AavePoolUpdated(newPool);
    }

    // Fees are accrued and claimable in aToken form
    function withdrawFees(address to, uint256 amount) public onlyOwner {
        uint256 currentFees = getCurrentFees();
        if (amount > currentFees) revert Errors.InsufficientFees(); // will underflow below anyway, error msg for clarity

        accumulatedFees = currentFees - amount;
        lastVaultBalance = aToken.balanceOf(address(this)) - amount;
        lastUpdated = block.timestamp;

        aToken.transfer(to, amount);

        emit Events.FeesWithdrawn(to, amount);
    }

    function claimAllAaveRewards(address to) public onlyOwner {
        if (to == address(0)) revert Errors.CannotSendRewardsToZeroAddress();

        address[] memory assets = new address[](1);
        assets[0] = address(aToken);

        (address[] memory rewardsList, uint256[] memory claimedAmounts) = REWARDS_CONTROLLER.claimAllRewards(assets, to);

        emit Events.AaveRewardsClaimed(to, rewardsList, claimedAmounts);
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
}
