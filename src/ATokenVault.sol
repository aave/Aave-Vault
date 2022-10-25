// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "forge-std/Test.sol";

import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";

import {IPoolAddressesProvider} from "aave/interfaces/IPoolAddressesProvider.sol";
// import {IPoolDataProvider} from "../interfaces/IPoolDataProvider.sol";
import {IPool} from "aave/interfaces/IPool.sol";

contract ATokenVault is ERC4626, Ownable {
    uint256 internal constant SCALE = 1e18;

    uint256 public lastUpdated;
    uint256 public lastVaultBalance;
    uint256 public fee;

    event FeeUpdated(uint256 oldFee, uint256 newFee);

    // TODO add dynamic strings for name/symbol
    constructor(ERC20 aToken) ERC4626(aToken, "Wrapped [aTKN]", "w[aTKN]") {}

    // TODO take fee on withdraw/redeem

    // TODO refactor errors
    function setFee(uint256 _newFee) public onlyOwner {
        require(_newFee < SCALE, "FEE_TOO_HIGH");

        uint256 oldFee = fee;
        fee = _newFee;

        emit FeeUpdated(oldFee, _newFee);
    }

    function totalAssets() public view override returns (uint256) {
        return 0;
    }
}
