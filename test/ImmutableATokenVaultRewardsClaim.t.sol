// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import {IAToken} from "@aave-v3-core/interfaces/IAToken.sol";
import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";
import {IRewardsController} from "@aave-v3-periphery/rewards/interfaces/IRewardsController.sol";
import {ImmutableATokenVaultBaseTest} from "./ImmutableATokenVaultBaseTest.t.sol";

// Separate test suite for claiming Aave rewards
// This is because we need to fork Avalanche mainnet
// as rewards can't be detected at previous blocks on Polygon

contract ImmutableATokenVaultRewardsClaimTest is ImmutableATokenVaultBaseTest {
    uint256 avalancheFork;
    uint256 AVALANCHE_FORK_BLOCK = 21000000; // Oct 13th 2022
    uint256 THIRTY_DAYS = 2592000; // 1 month of rewards

    IAToken aUSDC;

    function setUp() public override {
        avalancheFork = vm.createFork(vm.envString("AVALANCHE_RPC_URL"));
        vm.selectFork(avalancheFork);
        vm.rollFork(AVALANCHE_FORK_BLOCK);

        aUSDC = IAToken(AVALANCHE_AUSDC);

        vaultAssetAddress = address(aUSDC);

        _deploy(AVALANCHE_USDC, AVALANCHE_POOL_ADDRESSES_PROVIDER, 10e6);
    }

    /*//////////////////////////////////////////////////////////////
                            AVALANCHE FORK TESTS
        //////////////////////////////////////////////////////////////*/

    function testAvalancheForkWorks() public {
        assertEq(vm.activeFork(), avalancheFork);
    }

    function testAvalancheForkAtExpectedBlock() public {
        assertEq(block.number, AVALANCHE_FORK_BLOCK);
    }

    /*//////////////////////////////////////////////////////////////
                            AAVE REWARDS CLAIM TESTS
    //////////////////////////////////////////////////////////////*/

    function testNonOwnerCannotClaimAaveRewards() public {
        vm.startPrank(ALICE);
        vm.expectRevert(ERR_NOT_OWNER);
        vault.claimRewards(ALICE);
        vm.stopPrank();
    }

    function testOwnerCannotClaimAaveRewardsToZeroAddress() public {
        vm.startPrank(OWNER);
        vm.expectRevert(ERR_CANNOT_CLAIM_TO_ZERO_ADDRESS);
        vault.claimRewards(address(0));
        vm.stopPrank();
    }

    // Simulate 1 month of AVALANCHE_WAVAX rewards on 100 000 USDC deposited in Aave v3
    // From Oct 13th 2022 to Nov 12th 2022
    function testOwnerCanClaimAaveRewards() public {
        uint256 amount = 100_000e6; // 100 000 USDC

        address[] memory rewardAssets;
        uint256[] memory rewardAmounts;
        address[] memory aUsdcArray = new address[](1);
        aUsdcArray[0] = AVALANCHE_AUSDC;

        _depositFromUser(ALICE, amount);

        skip(THIRTY_DAYS);

        (rewardAssets, rewardAmounts) = IRewardsController(AVALANCHE_REWARDS_CONTROLLER).getAllUserRewards(
            aUsdcArray,
            address(vault)
        );
        assertEq(ERC20(AVALANCHE_WAVAX).balanceOf(OWNER), 0); // Owner has no AVALANCHE_WAVAX before claiming

        vm.startPrank(OWNER);
        vault.claimRewards(OWNER);
        vm.stopPrank();

        assertEq(ERC20(AVALANCHE_WAVAX).balanceOf(OWNER), rewardAmounts[0]); // Owner has some AVALANCHE_WAVAX after claiming
        assertGt(ERC20(AVALANCHE_WAVAX).balanceOf(OWNER), ONE); // Check rewards > 1 AVALANCHE_WAVAX (should be approx 3.8 AVALANCHE_WAVAX)
        assertEq(AVALANCHE_WAVAX, rewardAssets[0]);
    }

    function testClaimRewardsEmitsEvent() public {
        uint256 amount = 100_000e6; // 100 000 USDC

        address[] memory rewardAssets;
        uint256[] memory rewardAmounts;
        address[] memory aUsdcArray = new address[](1);
        aUsdcArray[0] = AVALANCHE_AUSDC;

        _depositFromUser(ALICE, amount);

        skip(THIRTY_DAYS);

        (rewardAssets, rewardAmounts) = IRewardsController(AVALANCHE_REWARDS_CONTROLLER).getAllUserRewards(
            aUsdcArray,
            address(vault)
        );

        vm.startPrank(OWNER);
        vm.expectEmit(true, false, false, true, address(vault));
        emit RewardsClaimed(OWNER, rewardAssets, rewardAmounts);
        vault.claimRewards(OWNER);
        vm.stopPrank();
    }

    function _depositFromUser(address user, uint256 amount) public {
        deal(AVALANCHE_USDC, user, amount);
        vm.startPrank(user);
        ERC20(AVALANCHE_USDC).approve(address(vault), amount);
        vault.deposit(amount, user);
        vm.stopPrank();
    }
}
