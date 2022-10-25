// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "forge-std/Test.sol";

import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";

import {IPoolAddressesProvider} from "aave/interfaces/IPoolAddressesProvider.sol";
import {IPool} from "aave/interfaces/IPool.sol";
import {IAToken} from "aave/interfaces/IAToken.sol";

contract ATokenVault is ERC4626, Ownable {
    IPoolAddressesProvider public immutable POOL_ADDRESSES_PROVIDER;

    uint256 internal constant SCALE = 1e18;

    IPool public aavePool;
    IAToken public aToken;

    uint256 public lastUpdated;
    uint256 public lastVaultBalance;
    uint256 public fee;

    // TODO may need MasterChef accounting for staking positions

    event FeeUpdated(uint256 oldFee, uint256 newFee);

    // TODO add dynamic strings for name/symbol
    constructor(ERC20 underlying, IPoolAddressesProvider poolAddressesProvider)
        ERC4626(underlying, "Wrapped [aTKN]", "w[aTKN]")
    {
        POOL_ADDRESSES_PROVIDER = poolAddressesProvider;
        aavePool = IPool(poolAddressesProvider.getPool());
        aToken = IAToken(aavePool.getReserveData(address(underlying)).aTokenAddress);
    }

    // TODO deposit underlying into Aave on deposit/mint

    // TODO take fee on withdraw/redeem

    // TODO refactor errors
    function setFee(uint256 _newFee) public onlyOwner {
        require(_newFee < SCALE, "FEE_TOO_HIGH");

        uint256 oldFee = fee;
        fee = _newFee;

        emit FeeUpdated(oldFee, _newFee);
    }

    // TODO owner can update the address of aToken and aavePool

    // TODO return balanceOf aTokens == owned underlying
    function totalAssets() public view override returns (uint256) {
        return 0;
    }
}
