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
    uint256 public lastVaultBalance; // total aToken incl. fees
    uint256 public fee;
    uint256 public accumulatedFees;

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
        _accrueYield();

        require((shares = previewDeposit(assets)) != 0, "ZERO_SHARES");

        // Need to transfer before minting or ERC777s could reenter.
        asset.safeTransferFrom(msg.sender, address(this), assets);

        // Approve and Deposit the received underlying into Aave v3
        asset.approve(address(aavePool), assets);
        aavePool.supply(address(asset), assets, address(this), 0);

        lastVaultBalance = aToken.balanceOf(address(this));

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function mint(uint256 shares, address receiver) public override returns (uint256 assets) {
        _accrueYield();

        assets = previewMint(shares);

        // Need to transfer before minting or ERC777s could reenter.
        asset.safeTransferFrom(msg.sender, address(this), assets);

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
        _accrueYield();

        shares = previewWithdraw(assets);

        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender];
            if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
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

    // TODO add WithSig versions of deposit/mint/withdraw/redeem

    /*//////////////////////////////////////////////////////////////
                          ONLY OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setFee(uint256 _newFee) public onlyOwner {
        require(_newFee < SCALE, "VAULT: FEE TOO HIGH");

        uint256 oldFee = fee;
        fee = _newFee;

        emit FeeUpdated(oldFee, _newFee);
    }

    function updateAavePool() public onlyOwner {
        aavePool = IPool(POOL_ADDRESSES_PROVIDER.getPool());
    }

    // Fees are accrued and claimable in aToken form
    function withdrawFees(uint256 amount, address to) public onlyOwner {
        // TODO is require necessary? will underflow below but better error msg here
        require(amount <= accumulatedFees, "VAULT: INSUFFICIENT FEES");

        accumulatedFees -= amount;

        aToken.transfer(to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function totalAssets() public view override returns (uint256) {
        // Report only the total assets net of fees, for vault share logic
        // TODO add condition for new yield since accFees updated
        return aToken.balanceOf(address(this)) - accumulatedFees;
    }

    function feeSplit(uint256 amount) internal view returns (uint256 feeAmount, uint256 netAmount) {
        feeAmount = amount.mulDivUp(fee, SCALE);
        netAmount = amount - feeAmount;
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _accrueYield() internal {
        // Fees are accrued and claimable in aToken form
        if (block.timestamp != lastUpdated) {
            uint256 newVaultBalance = aToken.balanceOf(address(this));
            uint256 newYield = newVaultBalance - lastVaultBalance;

            accumulatedFees += newYield.mulDivUp(fee, SCALE);

            lastVaultBalance = newVaultBalance;
            lastUpdated = block.timestamp;
        }
    }
}
