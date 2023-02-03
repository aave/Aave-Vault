// // SPDX-License-Identifier: MIT
// pragma solidity 0.8.10;

// import "forge-std/Test.sol";
// import {ATokenVaultBaseTest} from "./ATokenVaultBaseTest.t.sol";

// import {ATokenVault} from "../src/ATokenVault.sol";
// import {IAToken} from "aave/interfaces/IAToken.sol";
// import {ERC20} from "solmate/tokens/ERC20.sol";
// import {IPoolAddressesProvider} from "aave/interfaces/IPoolAddressesProvider.sol";
// import {IRewardsController} from "aave-periphery/rewards/interfaces/IRewardsController.sol";
// import {IPool} from "aave/interfaces/IPool.sol";

// // AVALANCHE addresses
// address constant AVAX_USDC = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;
// address constant AVAX_AUSDC = 0x625E7708f30cA75bfd92586e17077590C60eb4cD;
// address constant WAVAX = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;

// address constant AVALANCHE_POOL_ADDRESSES_PROVIDER = 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb;
// address constant AVALANCHE_REWARDS_CONTROLLER = 0x929EC64c34a17401F460460D4B9390518E5B473e;

// // Separate test suite for claiming Aave rewards
// // This is because we need to fork Avalanche mainnet
// // as rewards can't be detected at previous blocks on Polygon

// contract ATokenVaultRewardsClaimTest is ATokenVaultBaseTest {
//     uint256 avalancheFork;
//     uint256 AVLANCHE_FORK_BLOCK = 21000000; // Oct 13th 2022
//     uint256 THIRTY_DAYS = 2592000; // 1 month of rewards

//     ERC20 usdc; //NOTE: USDC has 6 decimal places, not 18
//     IAToken aUSDC;

//     function setUp() public override {
//         avalancheFork = vm.createFork(vm.envString("AVALANCHE_RPC_URL"));
//         vm.selectFork(avalancheFork);
//         vm.rollFork(AVLANCHE_FORK_BLOCK);

//         aUSDC = IAToken(AVAX_AUSDC);

//         vaultAssetAddress = address(aUSDC);

//         _deploy(AVAX_USDC, AVALANCHE_POOL_ADDRESSES_PROVIDER);
//         vm.stopPrank();
//     }

//     /*//////////////////////////////////////////////////////////////
//                         AVALANCHE FORK TESTS
//     //////////////////////////////////////////////////////////////*/

//     function testAvalancheForkWorks() public {
//         assertEq(vm.activeFork(), avalancheFork);
//     }

//     function testAvalancheForkAtExpectedBlock() public {
//         assertEq(block.number, AVLANCHE_FORK_BLOCK);
//     }

//     /*//////////////////////////////////////////////////////////////
//                         AAVE REWARDS CLAIM TESTS
//     //////////////////////////////////////////////////////////////*/

//     function testNonOwnerCannotClaimAaveRewards() public {
//         vm.startPrank(ALICE);
//         vm.expectRevert(ERR_NOT_OWNER);
//         vault.claimAllAaveRewards(ALICE);
//         vm.stopPrank();
//     }

//     function testOwnerCannotClaimAaveRewardsToZeroAddress() public {
//         vm.startPrank(OWNER);
//         vm.expectRevert(ERR_CANNOT_CLAIM_TO_ZERO_ADDRESS);
//         vault.claimAllAaveRewards(address(0));
//         vm.stopPrank();
//     }

//     // Simulate 1 month of wAVAX rewards on 100 000 USDC deposited in Aave v3
//     // From Oct 13th 2022 to Nov 12th 2022
//     function testOwnerCanClaimAaveRewards() public {
//         uint256 amount = 100_000e6; // 100 000 USDC

//         address[] memory rewardAssets;
//         uint256[] memory rewardAmounts;
//         address[] memory aUsdcArray = new address[](1);
//         aUsdcArray[0] = AVAX_AUSDC;

//         _depositFromUser(ALICE, amount);

//         skip(THIRTY_DAYS);

//         (rewardAssets, rewardAmounts) =
//             IRewardsController(AVALANCHE_REWARDS_CONTROLLER).getAllUserRewards(aUsdcArray, address(vault));

//         assertEq(ERC20(WAVAX).balanceOf(OWNER), 0); // Owner has no wAVAX before claiming

//         vm.startPrank(OWNER);
//         vault.claimAllAaveRewards(OWNER);
//         vm.stopPrank();

//         assertEq(ERC20(WAVAX).balanceOf(OWNER), rewardAmounts[0]); // Owner has some wAVAX after claiming
//         assertGt(ERC20(WAVAX).balanceOf(OWNER), ONE); // Check rewards > 1 wAVAX (should be approx 3.8 wAVAX)
//         assertEq(WAVAX, rewardAssets[0]);
//     }

//     function testClaimAllAaveRewardsEmitsEvent() public {
//         uint256 amount = 100_000e6; // 100 000 USDC

//         address[] memory rewardAssets;
//         uint256[] memory rewardAmounts;
//         address[] memory aUsdcArray = new address[](1);
//         aUsdcArray[0] = AVAX_AUSDC;

//         _depositFromUser(ALICE, amount);

//         skip(THIRTY_DAYS);

//         (rewardAssets, rewardAmounts) =
//             IRewardsController(AVALANCHE_REWARDS_CONTROLLER).getAllUserRewards(aUsdcArray, address(vault));

//         vm.startPrank(OWNER);
//         vm.expectEmit(true, false, false, true, address(vault));
//         emit AaveRewardsClaimed(OWNER, rewardAssets, rewardAmounts);
//         vault.claimAllAaveRewards(OWNER);
//         vm.stopPrank();
//     }

//     function _depositFromUser(address user, uint256 amount) public {
//         deal(address(usdc), user, amount);

//         vm.startPrank(user);
//         usdc.approve(address(vault), amount);
//         vault.deposit(amount, user);
//         vm.stopPrank();
//     }
// }
