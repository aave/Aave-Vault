// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "forge-std/Test.sol";

import {ERC4626, SafeTransferLib, FixedPointMathLib} from "solmate/mixins/ERC4626.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";

import {IPoolAddressesProvider} from "aave/interfaces/IPoolAddressesProvider.sol";
import {IPool} from "aave/interfaces/IPool.sol";
import {IAToken} from "aave/interfaces/IAToken.sol";

contract ATokenVault is ERC4626, Ownable {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    IPoolAddressesProvider public immutable POOL_ADDRESSES_PROVIDER;

    uint256 internal constant SCALE = 1e18;

    IPool public aavePool;
    IAToken public aToken;

    uint256 public lastUpdated;
    uint256 public lastVaultBalance;
    uint256 public fee;
    address public feeCollector;

    // TODO may need MasterChef accounting for staking positions
    // Current fee mechanism doesn't account for yield since deposit,
    // Just takes a cut of shares - users may recieve less than deposited

    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event FeeTaken(uint256 shares);

    // TODO add dynamic strings for name/symbol
    constructor(ERC20 underlying, IPoolAddressesProvider poolAddressesProvider)
        ERC4626(underlying, "Wrapped [aTKN]", "w[aTKN]")
    {
        POOL_ADDRESSES_PROVIDER = poolAddressesProvider;
        aavePool = IPool(poolAddressesProvider.getPool());
        aToken = IAToken(aavePool.getReserveData(address(underlying)).aTokenAddress);
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    function deposit(uint256 assets, address receiver) public override returns (uint256 shares) {
        // Check for rounding error since we round down in previewDeposit.
        require((shares = previewDeposit(assets)) != 0, "ZERO_SHARES");

        // Need to transfer before minting or ERC777s could reenter.
        asset.safeTransferFrom(msg.sender, address(this), assets);

        // Approve and Deposit the received underlying into Aave v3
        asset.approve(address(aavePool), assets);
        aavePool.supply(address(asset), assets, address(this), 0);

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function mint(uint256 shares, address receiver) public override returns (uint256 assets) {
        assets = previewMint(shares); // No need to check for rounding error, previewMint rounds up.

        // Need to transfer before minting or ERC777s could reenter.
        asset.safeTransferFrom(msg.sender, address(this), assets);

        // Approve and Deposit the received underlying into Aave v3
        asset.approve(address(aavePool), assets);
        aavePool.supply(address(asset), assets, address(this), 0);

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    // TODO take fee on withdraw/redeem

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public override returns (uint256 shares) {
        shares = previewWithdraw(assets);

        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender];
            if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
        }

        uint256 netSharesToBurn;
        uint256 assetsReceived;

        // Only take fee if share owner is not feeCollector, otherwise recursive fee
        if (owner != feeCollector && fee > 0) {
            uint256 feeShares;
            (feeShares, netSharesToBurn) = feeSplit(shares);
            assetsReceived = convertToAssets(netSharesToBurn);

            // Takes fee in form of vault shares
            transferFrom(owner, feeCollector, feeShares);

            emit FeeTaken(feeShares);
        } else {
            netSharesToBurn = shares;
            assetsReceived = assets;
        }

        _burn(owner, netSharesToBurn);

        emit Withdraw(msg.sender, receiver, owner, assetsReceived, shares);

        // Withdraw assets from Aave v3 and send to receiver
        aavePool.withdraw(address(asset), assetsReceived, receiver);
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public override returns (uint256 assets) {
        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender];
            if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
        }

        require((assets = previewRedeem(shares)) != 0, "ZERO_ASSETS");

        uint256 netSharesToBurn;
        uint256 assetsReceived;

        // Only take fee if share owner is not feeCollector, otherwise recursive fee
        if (owner != feeCollector && fee > 0) {
            uint256 feeShares;
            (feeShares, netSharesToBurn) = feeSplit(shares);
            assetsReceived = convertToAssets(netSharesToBurn);

            // Takes fee in form of vault shares
            transferFrom(owner, feeCollector, feeShares);

            emit FeeTaken(feeShares);
        } else {
            netSharesToBurn = shares;
            assetsReceived = assets;
        }

        _burn(owner, netSharesToBurn);

        emit Withdraw(msg.sender, receiver, owner, assetsReceived, shares);

        // Withdraw assets from Aave v3 and send to receiver
        aavePool.withdraw(address(asset), assetsReceived, receiver);
    }

    // TODO add WithSig versions of deposit/mint/withdraw/redeem

    // TODO refactor errors
    function setFee(uint256 _newFee) public onlyOwner {
        require(_newFee < SCALE, "FEE_TOO_HIGH");

        uint256 oldFee = fee;
        fee = _newFee;

        emit FeeUpdated(oldFee, _newFee);
    }

    // TODO owner can update the address of aToken and aavePool

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function totalAssets() public view override returns (uint256) {
        return aToken.balanceOf(address(this));
    }

    function feeSplit(uint256 amount) internal view returns (uint256 feeAmount, uint256 netAmount) {
        feeAmount = amount.mulDivUp(fee, SCALE);
        netAmount = amount - feeAmount;
    }
}
