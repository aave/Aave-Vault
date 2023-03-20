// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./utils/Constants.sol";
import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IPoolAddressesProvider} from "@aave-v3-core/interfaces/IPoolAddressesProvider.sol";
import {IPool} from "@aave-v3-core/interfaces/IPool.sol";
import {MockAavePool} from "./mocks/MockAavePool.sol";
import {MockAToken} from "./mocks/MockAToken.sol";
import {ATokenVaultForkBaseTest} from "./ATokenVaultForkBaseTest.t.sol";
import {ATokenVault} from "../src/ATokenVault.sol";

contract ATokenVaultForkTest is ATokenVaultForkBaseTest {
    /*//////////////////////////////////////////////////////////////
                        POLYGON FORK TESTS
    //////////////////////////////////////////////////////////////*/

    // Fuzzing
    function test_fuzzDepositWithdrawSameAmount(uint256 amount) public {
        vm.assume(amount > 1); // 0 reverts due to zero shares, 1 reverts due to -2 underflow
        vm.assume(amount <= _maxDaiSuppliableToAave());
        _depositFromUser(ALICE, amount);
        _withdrawFromUser(ALICE, 0);
        assertGt(dai.balanceOf(ALICE), amount - 2);
        assertLt(dai.balanceOf(ALICE), amount + 2);
    }

    // function test_fuzz
    function test_fuzzDepositAfterTransferAndWithdrawSameAmount(uint256 transferAmount, uint256 amount) public {
        // Transfer: Assume the transfer amount is greater than zero and less than or equal to the amount Aave can handle
        // less the amount to deposit.
        // Deposit: Assume the deposit is non-zero and less than the amount Aave can handle.
        vm.assume(transferAmount > 0);
        vm.assume(amount > 1);
        vm.assume(amount <= _maxDaiSuppliableToAave());
        vm.assume(transferAmount <= _maxDaiSuppliableToAave() - amount);
        _transferFromUser(OWNER, transferAmount);

        // Assume the deposit is greater than the amount needed for one share.
        vm.assume(amount > vault.convertToAssets(1));

        _depositFromUser(ALICE, amount);
        _withdrawFromUser(ALICE, 0);
        assertGt(dai.balanceOf(ALICE), amount - 2);
        assertLt(dai.balanceOf(ALICE), amount + 2);
    }
}
