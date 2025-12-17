// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "forge-std/Test.sol";

import {IAToken} from "@aave-v3-core/interfaces/IAToken.sol";

import {IATokenVaultMerklRewardClaimer} from "../src/interfaces/IATokenVaultMerklRewardClaimer.sol";
import {IMerklDistributor} from "../src/dependencies/merkl/DistributorInterface.sol";

import {MockAavePoolAddressesProvider} from "./mocks/MockAavePoolAddressesProvider.sol";
import {MockAavePool} from "./mocks/MockAavePool.sol";
import {MockAToken} from "./mocks/MockAToken.sol";
import {MockDAI} from "./mocks/MockDAI.sol";
import {MockMerklDistributor} from "./mocks/MockMerklDistributor.sol";
import {ATokenVaultBaseTest} from "./ATokenVaultBaseTest.t.sol";
import "./utils/Constants.sol";

/**
 * @title ATokenVaultMerklRewardClaimerTest
 * @notice Unit test suite for claiming Merkl rewards from the ATokenVault
 */
contract ATokenVaultMerklRewardClaimerTest is ATokenVaultBaseTest {    
    MockMerklDistributor internal _merklDistributor;
    MockAavePoolAddressesProvider internal __poolAddrProvider;
    MockAavePool internal _pool;
    MockAToken internal _aDai;
    MockDAI internal _dai;
    IATokenVaultMerklRewardClaimer internal _vaultMerklRewardClaimer;

    function setUp() public override {
        // NOTE: Real DAI has non-standard permit. These tests assume tokens with standard permit
        _dai = new MockDAI();

        _aDai = new MockAToken(address(_dai));
        _pool = new MockAavePool();
        _pool.mockReserve(address(_dai), _aDai);
        __poolAddrProvider = new MockAavePoolAddressesProvider(address(_pool));

        vaultAssetAddress = address(_aDai);

        _pool.setReserveConfigMap(RESERVE_CONFIG_MAP_UNCAPPED_ACTIVE);

        _merklDistributor = new MockMerklDistributor();

        // Sets the `vault`, but we will not use the vault deployment
        _deployATokenVaultMerklRewardClaimer(address(_dai), address(__poolAddrProvider));
        _vaultMerklRewardClaimer = IATokenVaultMerklRewardClaimer(address(vault));
    }
    
    function testClaimMerklRewards() public {
        _setMerklDistributor();

        bytes32 proof = keccak256("proof1");
        (address[] memory rewardTokens, uint256[] memory amounts, bytes32[][] memory proofs) = _buildMerklRewardsClaimData(address(_dai), 1000, proof);
        address[] memory rewardTokensToForward = new address[](0);
        address destination = address(0);

        address[] memory users = new address[](rewardTokens.length);
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            users[i] = address(_vaultMerklRewardClaimer);
        }

        vm.expectCall(
            address(_merklDistributor),
            0,
            abi.encodeCall(MockMerklDistributor.claim, (users, rewardTokens, amounts, proofs))
        );
        vm.expectEmit(true, true, false, true, address(_vaultMerklRewardClaimer));
        emit IATokenVaultMerklRewardClaimer.MerklRewardsClaimed(address(_merklDistributor), rewardTokens, amounts);
        vm.prank(OWNER);
        _vaultMerklRewardClaimer.claimMerklRewards(rewardTokens, amounts, proofs, rewardTokensToForward, destination);
    }

    function testClaimMerklRewardsAndForwardPartialTokenToDestination() public {
        // Context: 2 tokens will be rewarded, but only one will be forwarded to the destination.
        _setMerklDistributor();
        
        uint256 amountOfATokenRewarded = 789 * 1e18;
        uint256 amountOfDAIRewarded = 1234 * 1e18;
        address[] memory mockRecipients = new address[](2);
        mockRecipients[0] = address(_vaultMerklRewardClaimer);
        mockRecipients[1] = address(_vaultMerklRewardClaimer);
        address[] memory mockRewardTokens = new address[](2);
        mockRewardTokens[0] = address(_aDai);
        mockRewardTokens[1] = address(_dai);
        uint256[] memory mockAmounts = new uint256[](2);
        mockAmounts[0] = amountOfATokenRewarded;
        mockAmounts[1] = amountOfDAIRewarded;
        _merklDistributor.mockTokensToSend(mockRecipients, mockRewardTokens, mockAmounts);

        _aDai.mint(address(this), address(_merklDistributor), amountOfATokenRewarded, 0);
        assertEq(_aDai.balanceOf(address(_merklDistributor)), amountOfATokenRewarded);
        _dai.mint(address(_merklDistributor), amountOfDAIRewarded);
        assertEq(_dai.balanceOf(address(_merklDistributor)), amountOfDAIRewarded);

        bytes32 proof = keccak256("proof1");
        bytes32[][] memory proofs = new bytes32[][](2);
        proofs[0] = new bytes32[](1);
        proofs[0][0] = proof;
        proofs[1] = new bytes32[](1);
        proofs[1][0] = proof;
        // Forward the DAI only to the destination. Leave the aDAI in the vault.
        address[] memory rewardTokensToForward = new address[](1);
        rewardTokensToForward[0] = address(_dai);
        address destination = makeAddr("destination");
        
        // Check that the vault does not have any aDAI.
        uint256 beforeBalanceOfAToken = _aDai.balanceOf(address(_vaultMerklRewardClaimer));
        uint256 beforeBalanceOfDAI = _dai.balanceOf(address(_vaultMerklRewardClaimer));

        vm.expectEmit(true, true, false, true, address(_vaultMerklRewardClaimer));
        emit IATokenVaultMerklRewardClaimer.MerklRewardsClaimed(address(_merklDistributor), mockRewardTokens, mockAmounts);
        vm.expectEmit(true, true, false, true, address(_vaultMerklRewardClaimer));
        emit IATokenVaultMerklRewardClaimer.MerklRewardsTokenForwarded(address(_dai), destination, amountOfDAIRewarded);
        vm.prank(OWNER);
        _vaultMerklRewardClaimer.claimMerklRewards(mockRewardTokens, mockAmounts, proofs, rewardTokensToForward, destination);

        // Check that the vault did not hold onto the DAI.
        assertEq(_dai.balanceOf(address(_vaultMerklRewardClaimer)), beforeBalanceOfDAI);
        // Check that the destination received the DAI.
        assertEq(_dai.balanceOf(destination), amountOfDAIRewarded);
        // Check that the vault did hold onto the aDAI. The aDAI balance is initialized with a virtual amount.
        assertEq(_aDai.balanceOf(address(_vaultMerklRewardClaimer)), beforeBalanceOfAToken + amountOfATokenRewarded);
    }

    function testClaimMerklRewardsAndForwardFullTokenToDestination() public {
        // Context: 2 tokens will be rewarded, and both will be forwarded to the destination.
        _setMerklDistributor();
        
        uint256 amountOfATokenRewarded = 789 * 1e18;
        uint256 amountOfDAIRewarded = 1234 * 1e18;
        address[] memory mockRecipients = new address[](2);
        mockRecipients[0] = address(_vaultMerklRewardClaimer);
        mockRecipients[1] = address(_vaultMerklRewardClaimer);
        address[] memory mockRewardTokens = new address[](2);
        mockRewardTokens[0] = address(_aDai);
        mockRewardTokens[1] = address(_dai);
        uint256[] memory mockAmounts = new uint256[](2);
        mockAmounts[0] = amountOfATokenRewarded;
        mockAmounts[1] = amountOfDAIRewarded;
        _merklDistributor.mockTokensToSend(mockRecipients, mockRewardTokens, mockAmounts);

        _aDai.mint(address(this), address(_merklDistributor), amountOfATokenRewarded, 0);
        assertEq(_aDai.balanceOf(address(_merklDistributor)), amountOfATokenRewarded);
        _dai.mint(address(_merklDistributor), amountOfDAIRewarded);
        assertEq(_dai.balanceOf(address(_merklDistributor)), amountOfDAIRewarded);

        bytes32 proof = keccak256("proof1");
        bytes32[][] memory proofs = new bytes32[][](2);
        proofs[0] = new bytes32[](1);
        proofs[0][0] = proof;
        proofs[1] = new bytes32[](1);
        proofs[1][0] = proof;
        // Forward the DAI only to the destination. Leave the aDAI in the vault.
        address[] memory rewardTokensToForward = new address[](2);
        rewardTokensToForward[0] = address(_aDai);
        rewardTokensToForward[1] = address(_dai);
        address destination = makeAddr("destination");
        
        // Check that the vault does not have any aDAI.
        uint256 beforeBalanceOfAToken = _aDai.balanceOf(address(_vaultMerklRewardClaimer));
        uint256 beforeBalanceOfDAI = _dai.balanceOf(address(_vaultMerklRewardClaimer));

        vm.expectEmit(true, true, false, true, address(_vaultMerklRewardClaimer));
        emit IATokenVaultMerklRewardClaimer.MerklRewardsClaimed(address(_merklDistributor), mockRewardTokens, mockAmounts);
        vm.expectEmit(true, true, false, true, address(_vaultMerklRewardClaimer));
        emit IATokenVaultMerklRewardClaimer.MerklRewardsTokenForwarded(address(_dai), destination, amountOfDAIRewarded);
        vm.prank(OWNER);
        _vaultMerklRewardClaimer.claimMerklRewards(mockRewardTokens, mockAmounts, proofs, rewardTokensToForward, destination);

        // Check that the destination received the DAI and aDAI.
        assertEq(_dai.balanceOf(destination), amountOfDAIRewarded);
        assertEq(_aDai.balanceOf(destination), amountOfATokenRewarded);
        // Check that the vault did not hold onto the aDAI and DAI.
        assertEq(_aDai.balanceOf(address(_vaultMerklRewardClaimer)), beforeBalanceOfAToken);
        assertEq(_dai.balanceOf(address(_vaultMerklRewardClaimer)), beforeBalanceOfDAI);
    }

    function testClaimMerklRewardsIfATokenIsRewarded() public {
        _setMerklDistributor();
        
        uint256 amountOfATokenRewarded = 789 * 1e18;
        address[] memory mockRecipients = new address[](1);
        mockRecipients[0] = address(_vaultMerklRewardClaimer);
        address[] memory mockRewardTokens = new address[](1);
        mockRewardTokens[0] = address(_aDai);
        uint256[] memory mockAmounts = new uint256[](1);
        mockAmounts[0] = amountOfATokenRewarded;
        _merklDistributor.mockTokensToSend(mockRecipients, mockRewardTokens, mockAmounts);

        _aDai.mint(address(this), address(_merklDistributor), amountOfATokenRewarded, 0);
        assertEq(_aDai.balanceOf(address(_merklDistributor)), amountOfATokenRewarded);

        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");
        uint256 amountOfDAIDepositedByUser = 100_000 * 1e18;
        _depositFromUser(user1, amountOfDAIDepositedByUser);
        _depositFromUser(user2, amountOfDAIDepositedByUser);
        uint256 user1ShareBalanceBefore = vault.balanceOf(user1);
        uint256 user2ShareBalanceBefore = vault.balanceOf(user2);
        uint256 user1ATokenBalanceBefore = vault.previewRedeem(user1ShareBalanceBefore);
        uint256 user2ATokenBalanceBefore = vault.previewRedeem(user2ShareBalanceBefore);
        uint256 vaultATokenBalanceBefore = _aDai.balanceOf(address(vault));

        // Avoid stack too deep error
        _claimMerklRewards();

        uint256 vaultATokenBalanceAfter = _aDai.balanceOf(address(vault));
        assertEq(vaultATokenBalanceAfter, vaultATokenBalanceBefore + amountOfATokenRewarded);

        uint256 user1ShareBalanceAfter = vault.balanceOf(user1);
        assertEq(user1ShareBalanceAfter, user1ShareBalanceBefore);
        uint256 user2ShareBalanceAfter = vault.balanceOf(user2);
        assertEq(user2ShareBalanceAfter, user2ShareBalanceBefore);
        uint256 user1ATokenBalanceAfter = vault.previewRedeem(user1ShareBalanceAfter);
        assertGt(user1ATokenBalanceAfter, user1ATokenBalanceBefore);
        uint256 user2ATokenBalanceAfter = vault.previewRedeem(user2ShareBalanceAfter);
        assertGt(user2ATokenBalanceAfter, user2ATokenBalanceBefore);

        // Check that emergency rescue is not allowed
        vm.expectRevert(bytes("CANNOT_RESCUE_ATOKEN"));
        vm.prank(OWNER);
        vault.emergencyRescue(address(_aDai), address(this), vaultATokenBalanceAfter);
    }

    function testClaimMerklRewardsIfUnderlyingTokenAndRescue() public {
        _setMerklDistributor();
                
        uint256 amountOfUnderlyingTokenRewarded = 789 * 1e18;
        address[] memory mockRecipients = new address[](1);
        mockRecipients[0] = address(_vaultMerklRewardClaimer);
        address[] memory mockRewardTokens = new address[](1);
        mockRewardTokens[0] = address(_dai);
        uint256[] memory mockAmounts = new uint256[](1);
        mockAmounts[0] = amountOfUnderlyingTokenRewarded;
        _merklDistributor.mockTokensToSend(mockRecipients, mockRewardTokens, mockAmounts);
        _dai.mint(address(_merklDistributor), amountOfUnderlyingTokenRewarded);

        uint256 vaultBalanceOfUnderlyingTokenBefore = _dai.balanceOf(address(vault));
        uint256 vaultBalanceOfATokenBefore = _aDai.balanceOf(address(vault));

        _claimMerklRewards();

        uint256 vaultBalanceOfUnderlyingTokenAfter = _dai.balanceOf(address(vault));
        assertEq(vaultBalanceOfUnderlyingTokenAfter, vaultBalanceOfUnderlyingTokenBefore + amountOfUnderlyingTokenRewarded);
        uint256 vaultBalanceOfATokenAfter = _aDai.balanceOf(address(vault));
        assertEq(vaultBalanceOfATokenAfter, vaultBalanceOfATokenBefore);

        // Rescue the underlying
        vm.prank(OWNER);
        vault.emergencyRescue(address(_dai), address(this), amountOfUnderlyingTokenRewarded);
        assertEq(_dai.balanceOf(address(this)), amountOfUnderlyingTokenRewarded);
        assertEq(_dai.balanceOf(address(vault)), 0);
    }

    function testClaimMerklRewardsRevertsIfNativeTokenIsRewarded() public {
        _setMerklDistributor();

        address[] memory mockRecipients = new address[](1);
        mockRecipients[0] = address(_vaultMerklRewardClaimer);
        uint256 amountOfNativeToken = 789;
        address[] memory mockRewardTokens = new address[](1);
        mockRewardTokens[0] = address(0);
        uint256[] memory mockAmounts = new uint256[](1);
        mockAmounts[0] = amountOfNativeToken;
        _merklDistributor.mockTokensToSend(mockRecipients, mockRewardTokens, mockAmounts);
        vm.deal(address(_merklDistributor), amountOfNativeToken);
        
        bytes32 proof = keccak256("proof1");
        (address[] memory rewardTokens, uint256[] memory amounts, bytes32[][] memory proofs) = _buildMerklRewardsClaimData(address(_dai), 1000, proof);
        address[] memory rewardTokensToForward = new address[](0);
        address destination = address(0);
        vm.expectRevert();
        vm.prank(OWNER);
        _vaultMerklRewardClaimer.claimMerklRewards(rewardTokens, amounts, proofs, rewardTokensToForward, destination);
    }

    function testClaimMerklRewardsRevertsIfMerklDistributorNotSet() public {
        address[] memory rewardTokens = new address[](0);
        uint256[] memory amounts = new uint256[](0);
        bytes32[][] memory proofs = new bytes32[][](0);
        address[] memory rewardTokensToForward = new address[](0);
        address destination = address(0);
        vm.prank(OWNER);
        vm.expectRevert(bytes("MERKL_DISTRIBUTOR_NOT_SET"));
        _vaultMerklRewardClaimer.claimMerklRewards(rewardTokens, amounts, proofs, rewardTokensToForward, destination);
    }

    function testClaimMerklRewardsRevertsIfArrayLengthMismatchFromTokens() public {
        _setMerklDistributor();
        bytes32 proof = keccak256("proof1");
        address[] memory rewardTokens = new address[](2);
        rewardTokens[0] = address(_dai);
        rewardTokens[1] = address(_dai);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000;
        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = new bytes32[](1);
        proofs[0][0] = proof;
        address[] memory rewardTokensToForward = new address[](0);
        address destination = address(0);
        vm.expectRevert(bytes("ARRAY_LENGTH_MISMATCH"));
        vm.prank(OWNER);
        _vaultMerklRewardClaimer.claimMerklRewards(rewardTokens, amounts, proofs, rewardTokensToForward, destination);
    }

    function testClaimMerklRewardsRevertsIfArrayLengthMismatchFromAmounts() public {
        _setMerklDistributor();
        bytes32 proof = keccak256("proof1");
        address[] memory rewardTokens = new address[](1);
        rewardTokens[0] = address(_dai);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1000;
        amounts[1] = 1000;
        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = new bytes32[](1);
        proofs[0][0] = proof;
        address[] memory rewardTokensToForward = new address[](0);
        address destination = address(0);
        vm.expectRevert(bytes("ARRAY_LENGTH_MISMATCH"));
        vm.prank(OWNER);
        _vaultMerklRewardClaimer.claimMerklRewards(rewardTokens, amounts, proofs, rewardTokensToForward, destination);
    }

    function testClaimMerklRewardsRevertsIfArrayLengthMismatchFromProofs() public {
        _setMerklDistributor();
        bytes32 proof = keccak256("proof1");
        address[] memory rewardTokens = new address[](1);
        rewardTokens[0] = address(_dai);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000;
        bytes32[][] memory proofs = new bytes32[][](2);
        proofs[0] = new bytes32[](1);
        proofs[0][0] = proof;
        proofs[1] = new bytes32[](1);
        proofs[1][0] = proof;
        address[] memory rewardTokensToForward = new address[](0);
        address destination = address(0);
        vm.expectRevert(bytes("ARRAY_LENGTH_MISMATCH"));
        vm.prank(OWNER);
        _vaultMerklRewardClaimer.claimMerklRewards(rewardTokens, amounts, proofs, rewardTokensToForward, destination);
    }

    function testClaimMerklRewardsRevertsIfNotOwner() public {
        address[] memory rewardTokens = new address[](0);
        uint256[] memory amounts = new uint256[](0);
        bytes32[][] memory proofs = new bytes32[][](0);
        address[] memory rewardTokensToForward = new address[](0);
        address destination = address(0);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        _vaultMerklRewardClaimer.claimMerklRewards(rewardTokens, amounts, proofs, rewardTokensToForward, destination);
    }

    function testClaimMerklRewardsRevertsIfMerklDistributorReverts() public {
        _setMerklDistributor();

        bytes32 proof = keccak256("proof1");
        (address[] memory rewardTokens, uint256[] memory amounts, bytes32[][] memory proofs) = _buildMerklRewardsClaimData(address(_dai), 1000, proof);
        address[] memory rewardTokensToForward = new address[](0);
        address destination = address(0);
        string memory revertReason = "revert because of insufficient balance";
        _merklDistributor.setShouldRevert(true, revertReason);
        vm.expectRevert(bytes(revertReason));
        vm.prank(OWNER);
        _vaultMerklRewardClaimer.claimMerklRewards(rewardTokens, amounts, proofs, rewardTokensToForward, destination);
    }

    function testSetMerklDistributor() public {
        vm.expectEmit(true, true, false, true, address(_vaultMerklRewardClaimer));
        emit IATokenVaultMerklRewardClaimer.MerklDistributorUpdated(address(0), address(_merklDistributor));
        vm.prank(OWNER);
        _vaultMerklRewardClaimer.setMerklDistributor(address(_merklDistributor));
        assertEq(_vaultMerklRewardClaimer.getMerklDistributor(), address(_merklDistributor));

        address newMerklDistributor = makeAddr("newMerklDistributor");
        vm.expectEmit(true, true, false, true, address(_vaultMerklRewardClaimer));
        emit IATokenVaultMerklRewardClaimer.MerklDistributorUpdated(address(_merklDistributor), newMerklDistributor);
        vm.prank(OWNER);
        _vaultMerklRewardClaimer.setMerklDistributor(newMerklDistributor);
        assertEq(_vaultMerklRewardClaimer.getMerklDistributor(), newMerklDistributor);
    }

    function testSetMerklDistributorAllowsZeroAddress() public {
        vm.prank(OWNER);
        _vaultMerklRewardClaimer.setMerklDistributor(address(_merklDistributor));
        assertEq(_vaultMerklRewardClaimer.getMerklDistributor(), address(_merklDistributor));
        vm.prank(OWNER);
        _vaultMerklRewardClaimer.setMerklDistributor(address(0));
        assertEq(_vaultMerklRewardClaimer.getMerklDistributor(), address(0));
    }

    function testSetMerklDistributorRevertsIfNotOwner() public {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        _vaultMerklRewardClaimer.setMerklDistributor(address(_merklDistributor));
    }

    function _setMerklDistributor() internal {
        vm.prank(OWNER);
        _vaultMerklRewardClaimer.setMerklDistributor(address(_merklDistributor));
    }

    function _buildMerklRewardsClaimData(
        address token,
        uint256 amount,
        bytes32 proof
    ) internal pure returns (address[] memory rewardTokens, uint256[] memory amounts, bytes32[][] memory proofs) {
        rewardTokens = new address[](1);
        rewardTokens[0] = token;
        amounts = new uint256[](1);
        amounts[0] = amount;
        proofs = new bytes32[][](1);
        proofs[0] = new bytes32[](1);
        proofs[0][0] = proof;
    }

    function _claimMerklRewards() internal {
        bytes32 proof = keccak256("proof1");
        (address[] memory rewardTokens, uint256[] memory amounts, bytes32[][] memory proofs) = _buildMerklRewardsClaimData(address(_dai), 1000, proof);
        address[] memory rewardTokensToForward = new address[](0);
        address destination = address(0);
        vm.prank(OWNER);
        _vaultMerklRewardClaimer.claimMerklRewards(rewardTokens, amounts, proofs, rewardTokensToForward, destination);
    }

    function _depositFromUser(address user, uint256 amount) internal {
        _dai.mint(user, amount);
        vm.startPrank(user);
        _dai.approve(address(vault), amount);
        vault.deposit(amount, user);
        vm.stopPrank();
    }
}
