// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "forge-std/Test.sol";

import {IAToken} from "@aave-v3-core/interfaces/IAToken.sol";

import {IATokenVaultMerklRewardClaimer} from "../src/interfaces/IATokenVaultMerklRewardClaimer.sol";

import {MockAavePoolAddressesProvider} from "./mocks/MockAavePoolAddressesProvider.sol";
import {MockAavePool} from "./mocks/MockAavePool.sol";
import {MockAToken} from "./mocks/MockAToken.sol";
import {MockDAI} from "./mocks/MockDAI.sol";
import {MockMerklDistributor} from "./mocks/MockMerklDistributor.sol";
import {ATokenVaultBaseTest} from "./ATokenVaultBaseTest.t.sol";
import "./utils/Constants.sol";

/**
 * @title ATokenVaultMerklRewardsClaimerTest
 * @notice Unit test suite for claiming Merkl rewards from the ATokenVault
 */
contract ATokenVaultMerklRewardsClaimerTest is ATokenVaultBaseTest {    
    MockMerklDistributor merklDistributor;
    MockAavePoolAddressesProvider poolAddrProvider;
    MockAavePool pool;
    MockAToken aDai;
    MockDAI dai;
    IATokenVaultMerklRewardClaimer vaultMerklRewardClaimer;

    function setUp() public override {
        // NOTE: Real DAI has non-standard permit. These tests assume tokens with standard permit
        dai = new MockDAI();

        aDai = new MockAToken(address(dai));
        pool = new MockAavePool();
        pool.mockReserve(address(dai), aDai);
        poolAddrProvider = new MockAavePoolAddressesProvider(address(pool));

        vaultAssetAddress = address(aDai);

        pool.setReserveConfigMap(RESERVE_CONFIG_MAP_UNCAPPED_ACTIVE);

        merklDistributor = new MockMerklDistributor();

        // Sets the `vault`, but we will not use the vault deployment
        _deployATokenVaultMerklRewardClaimer(address(dai), address(poolAddrProvider));
        vaultMerklRewardClaimer = IATokenVaultMerklRewardClaimer(address(vault));
    }
    
    function testClaimMerklRewards() public {
        _setMerklDistributor();

        bytes32 proof = keccak256("proof1");
        (address[] memory rewardTokens, uint256[] memory amounts, bytes32[][] memory proofs) = _buildMerklRewardsClaimData(address(dai), 1000, proof);

        vm.prank(OWNER);
        vaultMerklRewardClaimer.claimMerklRewards(rewardTokens, amounts, proofs);
        
        assertEq(merklDistributor.getLastUsers().length, 1);
        assertEq(merklDistributor.getLastUsers()[0], address(vaultMerklRewardClaimer));
        assertEq(merklDistributor.getLastTokens().length, 1);
        assertEq(merklDistributor.getLastTokens()[0], address(dai));
        assertEq(merklDistributor.getLastAmounts().length, 1);
        assertEq(merklDistributor.getLastAmounts()[0], 1000);
        assertEq(merklDistributor.getLastProofs().length, 1);
        assertEq(merklDistributor.getLastProofs()[0][0], proof);
    }

    function testClaimMerklRewardsEmitsEvent() public {
        _setMerklDistributor();

        bytes32 proof = keccak256("proof1");
        (address[] memory rewardTokens, uint256[] memory amounts, bytes32[][] memory proofs) = _buildMerklRewardsClaimData(address(dai), 1000, proof);
        vm.prank(OWNER);
        vm.expectEmit(true, false, false, true, address(vaultMerklRewardClaimer));
        emit IATokenVaultMerklRewardClaimer.MerklRewardsClaimed(rewardTokens, amounts);
        vaultMerklRewardClaimer.claimMerklRewards(rewardTokens, amounts, proofs);
    }

    function testClaimMerklRewardsRevertsIfMerklDistributorNotSet() public {
        bytes32 proof = keccak256("proof1");
        (address[] memory rewardTokens, uint256[] memory amounts, bytes32[][] memory proofs) = _buildMerklRewardsClaimData(address(dai), 1000, proof);
        vm.prank(OWNER);
        vm.expectRevert(bytes("MERKL_DISTRIBUTOR_NOT_SET"));
        vaultMerklRewardClaimer.claimMerklRewards(rewardTokens, amounts, proofs);
    }

    function testClaimMerklRewardsRevertsIfNotOwner() public {
        bytes32 proof = keccak256("proof1");
        (address[] memory rewardTokens, uint256[] memory amounts, bytes32[][] memory proofs) = _buildMerklRewardsClaimData(address(dai), 1000, proof);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultMerklRewardClaimer.claimMerklRewards(rewardTokens, amounts, proofs);
    }

    function testClaimMerklRewardsRevertsIfMerklDistributorReverts() public {
        _setMerklDistributor();

        bytes32 proof = keccak256("proof1");
        (address[] memory rewardTokens, uint256[] memory amounts, bytes32[][] memory proofs) = _buildMerklRewardsClaimData(address(dai), 1000, proof);
        string memory revertReason = "revert because of insufficient balance";
        merklDistributor.setShouldRevert(true, revertReason);
        vm.expectRevert(bytes(revertReason));
        vm.prank(OWNER);
        vaultMerklRewardClaimer.claimMerklRewards(rewardTokens, amounts, proofs);
    }

    function testSetMerklDistributor() public {
        vm.prank(OWNER);
        vaultMerklRewardClaimer.setMerklDistributor(address(merklDistributor));
        assertEq(vaultMerklRewardClaimer.getMerklDistributor(), address(merklDistributor));
    }

    function testSetMerklDistributorEmitsEvent() public {
        vm.prank(OWNER);
        vm.expectEmit(true, false, false, true, address(vaultMerklRewardClaimer));
        emit IATokenVaultMerklRewardClaimer.MerklDistributorUpdated(address(0), address(merklDistributor));
        vaultMerklRewardClaimer.setMerklDistributor(address(merklDistributor));

        address newMerklDistributor = makeAddr("newMerklDistributor");
        vm.prank(OWNER);
        vm.expectEmit(true, false, false, true, address(vaultMerklRewardClaimer));
        emit IATokenVaultMerklRewardClaimer.MerklDistributorUpdated(address(merklDistributor), newMerklDistributor);
        vaultMerklRewardClaimer.setMerklDistributor(newMerklDistributor);
    }

    function testSetMerklDistributorAllowsZeroAddress() public {
        vm.prank(OWNER);
        vaultMerklRewardClaimer.setMerklDistributor(address(merklDistributor));
        assertEq(vaultMerklRewardClaimer.getMerklDistributor(), address(merklDistributor));
        vm.prank(OWNER);
        vaultMerklRewardClaimer.setMerklDistributor(address(0));
        assertEq(vaultMerklRewardClaimer.getMerklDistributor(), address(0));
    }

    function testSetMerklDistributorRevertsIfNotOwner() public {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vaultMerklRewardClaimer.setMerklDistributor(address(merklDistributor));
    }

    function _setMerklDistributor() internal {
        vm.prank(OWNER);
        vaultMerklRewardClaimer.setMerklDistributor(address(merklDistributor));
    }

    function _buildMerklRewardsClaimData(address token, uint256 amount, bytes32 proof) internal returns (address[] memory rewardTokens, uint256[] memory amounts, bytes32[][] memory proofs) {
        rewardTokens = new address[](1);
        rewardTokens[0] = token;
        amounts = new uint256[](1);
        amounts[0] = amount;
        proofs = new bytes32[][](1);
        proofs[0] = new bytes32[](1);
        proofs[0][0] = proof;
    }
}
