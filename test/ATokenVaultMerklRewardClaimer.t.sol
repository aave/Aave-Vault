// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import {stdStorage, StdStorage} from "forge-std/Test.sol";

import {IAToken} from "@aave-v3-core/interfaces/IAToken.sol";
import {IERC20} from "@openzeppelin/interfaces/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/interfaces/IERC20Metadata.sol";

import {ATokenVaultBaseTest} from "./ATokenVaultBaseTest.t.sol";

import {IATokenVaultMerklRewardClaimer} from "../src/interfaces/IATokenVaultMerklRewardClaimer.sol";
import {IATokenVault} from "../src/interfaces/IATokenVault.sol";

/**
 * @title ATokenVaultMerklRewardClaimerTest
 * @notice Test suite for claiming Merkl rewards from the ATokenVault
 * @dev Forks Ethereum mainnet to etch the ATokenVault onto an address that has claimable rewards as of the forked block
 * @dev foundry.toml must use evm_version = 'cancun' to run this test
 */
contract ATokenVaultMerklRewardClaimerTest is ATokenVaultBaseTest {
    using stdStorage for StdStorage;
    uint256 ethereumFork;
    // The block before rewards claim in tx: https://etherscan.io/tx/0x42ef6b499d1b6e96a4250f2d5a005b60173386e2ac3a3e424aa407db3da802ea
    uint256 ETHEREUM_FORK_BLOCK = 23921479; // Dec 1st 2025

    address constant MERKL_DISTRIBUTOR = 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae;
    address constant ADDRESS_WITH_CLAIMABLE_REWARDS = 0x424629A0D581B6076322A952FB43b78624dB8A15;
    address constant ETHEREUM_HORIZON_POOL_ADDRESSES_PROVIDER = 0x5D39E06b825C1F2B80bf2756a73e28eFAA128ba0;
    address constant ETHEREUM_RLUSD = 0x8292Bb45bf1Ee4d140127049757C2E0fF06317eD;
    address constant A_HOR_RWA_RLUSD = 0xE3190143Eb552456F88464662f0c0C4aC67A77eB;
    address constant WRAPPED_A_HOR_RWA_RLUSD = 0x503D751B13a71D8e69Db021DF110bfa7aE1dA889;
    IAToken constant aHorRwaRLUSD = IAToken(A_HOR_RWA_RLUSD);

    function setUp() public override {
        ethereumFork = vm.createFork(vm.envString("ETHEREUM_RPC_URL"));
        vm.selectFork(ethereumFork);
        vm.rollFork(ETHEREUM_FORK_BLOCK);

        vaultAssetAddress = address(aHorRwaRLUSD);

        // Sets the `vault`, but we will not use the vault deployment
        _deployATokenVaultMerklRewardClaimer(ETHEREUM_RLUSD, ETHEREUM_HORIZON_POOL_ADDRESSES_PROVIDER);
    }

    /*//////////////////////////////////////////////////////////////
                        ETHEREUM FORK TESTS
    //////////////////////////////////////////////////////////////*/

    function testEthereumForkWorks() public {
        assertEq(vm.activeFork(), ethereumFork);
    }

    function testEthereumForkAtExpectedBlock() public {
        assertEq(block.number, ETHEREUM_FORK_BLOCK);
    }

    function testEthereumForkBalanceOfAddressWithClaimableRewards() public {
        assertEq(ADDRESS_WITH_CLAIMABLE_REWARDS.balance, 154288817306978598);
    }

    /*//////////////////////////////////////////////////////////////
                            MERKL REWARDS CLAIM TESTS
    //////////////////////////////////////////////////////////////*/

    function testOwnerCanClaimMerklRewards() public {
        _setMerklDistributor();
        // Set the code for an address that has claimable rewards as of the fork block
        // We will use this in place of the vault deployment
        _etchVault(ADDRESS_WITH_CLAIMABLE_REWARDS);

        uint256 beforeBalanceOfAHorRwaRLUSD = IERC20(A_HOR_RWA_RLUSD).balanceOf(ADDRESS_WITH_CLAIMABLE_REWARDS);
        uint256 beforeBalanceOfWrappedAHorRwaRLUSD = IERC20(WRAPPED_A_HOR_RWA_RLUSD).balanceOf(ADDRESS_WITH_CLAIMABLE_REWARDS);
        
        (address[] memory tokens, uint256[] memory amounts, bytes32[][] memory proofs) = _buildMerklRewardsClaimData();

        vm.prank(OWNER);
        IATokenVaultMerklRewardClaimer(ADDRESS_WITH_CLAIMABLE_REWARDS).claimMerklRewards(tokens, amounts, proofs);

        // Check that the vault received the A tokens (the tokens received from claiming Merkl rewards).
        assertGt(IERC20(A_HOR_RWA_RLUSD).balanceOf(ADDRESS_WITH_CLAIMABLE_REWARDS), beforeBalanceOfAHorRwaRLUSD);
        // Check that total assets is the same as the balance of the A tokens.
        assertEq(IERC20(A_HOR_RWA_RLUSD).balanceOf(ADDRESS_WITH_CLAIMABLE_REWARDS), IATokenVault(ADDRESS_WITH_CLAIMABLE_REWARDS).totalAssets());
        // Check that the vault's balance of the wrapped aToken is unchcanged.
        assertEq(IERC20(WRAPPED_A_HOR_RWA_RLUSD).balanceOf(ADDRESS_WITH_CLAIMABLE_REWARDS), beforeBalanceOfWrappedAHorRwaRLUSD);
    }

    function testClaimMerklRewardsEmitsEvent() public {
        _setMerklDistributor();
        // Set the code for an address that has claimable rewards as of the fork block
        // We will use this in place of the vault deployment
        _etchVault(ADDRESS_WITH_CLAIMABLE_REWARDS);

        (address[] memory tokens, uint256[] memory amounts, bytes32[][] memory proofs) = _buildMerklRewardsClaimData();

        vm.prank(OWNER);
        vm.expectEmit(true, false, false, true, ADDRESS_WITH_CLAIMABLE_REWARDS);
        emit IATokenVaultMerklRewardClaimer.MerklRewardsClaimed(tokens, amounts);
        IATokenVaultMerklRewardClaimer(ADDRESS_WITH_CLAIMABLE_REWARDS).claimMerklRewards(tokens, amounts, proofs);
    }

    function testClaimMerklRewardsRevertsIfMerklDistributorNotSet() public {
        (address[] memory tokens, uint256[] memory amounts, bytes32[][] memory proofs) = _buildMerklRewardsClaimData();

        vm.prank(OWNER);
        vm.expectRevert(bytes("MERKL_DISTRIBUTOR_NOT_SET"));
        IATokenVaultMerklRewardClaimer(address(vault)).claimMerklRewards(tokens, amounts, proofs);
    }

    function testClaimMerklRewardsRevertsIfNotOwner() public {
        (address[] memory tokens, uint256[] memory amounts, bytes32[][] memory proofs) = _buildMerklRewardsClaimData();

        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        IATokenVaultMerklRewardClaimer(address(vault)).claimMerklRewards(tokens, amounts, proofs);
    }

    function testSetMerklDistributor() public {
        vm.prank(OWNER);
        IATokenVaultMerklRewardClaimer(address(vault)).setMerklDistributor(MERKL_DISTRIBUTOR);
        assertEq(IATokenVaultMerklRewardClaimer(address(vault)).getMerklDistributor(), MERKL_DISTRIBUTOR);
        
        address newMerklDistributor = makeAddr("newMerklDistributor");
        vm.prank(OWNER);
        IATokenVaultMerklRewardClaimer(address(vault)).setMerklDistributor(newMerklDistributor);
        assertEq(IATokenVaultMerklRewardClaimer(address(vault)).getMerklDistributor(), newMerklDistributor);
    }
    
    function testSetMerklDistributorEmitsEvent() public {
        vm.prank(OWNER);
        vm.expectEmit(true, false, false, true, address(vault));
        emit IATokenVaultMerklRewardClaimer.MerklDistributorUpdated(address(0), MERKL_DISTRIBUTOR);
        IATokenVaultMerklRewardClaimer(address(vault)).setMerklDistributor(MERKL_DISTRIBUTOR);
    }

    function testSetMerklDistributorRevertsIfZeroAddress() public {
        vm.prank(OWNER);
        vm.expectRevert(bytes("ZERO_ADDRESS_NOT_VALID"));
        IATokenVaultMerklRewardClaimer(address(vault)).setMerklDistributor(address(0));
    }

    function testSetMerklDistributorRevertsIfNotOwner() public {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        IATokenVaultMerklRewardClaimer(address(vault)).setMerklDistributor(MERKL_DISTRIBUTOR);
    }

    function _buildMerklRewardsClaimData() internal pure returns (address[] memory tokens, uint256[] memory amounts, bytes32[][] memory proofs) {
        tokens = new address[](1);
        tokens[0] = address(WRAPPED_A_HOR_RWA_RLUSD);

        amounts = new uint256[](1);
        amounts[0] = 108475300663546315531064;

        proofs = new bytes32[][](1);
        proofs[0] = new bytes32[](18);
        proofs[0][0] = 0xcd60c655efb4b907fcd241863868d14b469487021d66d1edfdbda9472f9a64fa;
        proofs[0][1] = 0xb8fb6ed03a4fe66e40d0393936caaf89288f0f0d45a54b2d021e6436e08d5cab;
        proofs[0][2] = 0x51da9788480e72478a3983b1fcc6417d6e2fb23f17d82402980bf7a662951ebc;
        proofs[0][3] = 0xbd1e1f1f6b3bff2c96cdaac05eef648a12d7b26aff0cb6bf2e01df739326d221;
        proofs[0][4] = 0xc3666e909b4378eb3190a55407b3992791f45947ccfb78a450618fd0d2d186ef;
        proofs[0][5] = 0xeae511fe93c29449d7dc421a00989e9b90193b1ea95a6727edfd0ac23c85b1a8;
        proofs[0][6] = 0x7cb3e28ed93250acb734cf34cf07ae533800fc0161e936ee29c20f36c66e7d4a;
        proofs[0][7] = 0x467aa2d6889230db0b841374136b586ded4697016c9cb5b9259677357c9de435;
        proofs[0][8] = 0xb1b5b41688ba77f9426265f60c5f9a922062156ab08bdde674dceebacc1c92b3;
        proofs[0][9] = 0x51dda19784b96153bcda1086489d5d6c5f17566202c92a0d911cbd2aa7a3ff7a;
        proofs[0][10] = 0x4606c269974519cf0d4fe1907baab3ca27c5eef64560408e4137eaf62d273c08;
        proofs[0][11] = 0xcc7bdca69b12e1f75d7b26045ba5e0c108de8d85bcee444ac05a02b940a20ea7;
        proofs[0][12] = 0x67cfe6ef02168544a983543b06f1823d97e78d17e67bd6833f7fc6b8e3a2cc77;
        proofs[0][13] = 0x3f2a8d6cb9b7784fe51ac5719c41e1a973856a7f89f3847b2ec5e259b6977b90;
        proofs[0][14] = 0xed9131f643d7100fcdfcebbf4abb97e7bcf31ee08f7ab8fb3230231f6f3f7533;
        proofs[0][15] = 0x4dd1263f903416095b1556a5b9473082ee23a3eda267d6f98dbdcb200ba1d648;
        proofs[0][16] = 0x5df7d74a8a29e2552ddecdd29e57b8e1daedbc786f9f9ca6d308506f14b13995;
        proofs[0][17] = 0xa8568c4dc81b1ee1667791a9567914d57f698ab8f6444fd1bd9fa88b158598c6;
    }

    function _setMerklDistributor() internal {
        vm.prank(OWNER);
        IATokenVaultMerklRewardClaimer(address(vault)).setMerklDistributor(MERKL_DISTRIBUTOR);
    }

    function _etchVault(address target) internal {
        // 1. Fix the Proxy: Copy the implementation address from 'vault' to the etched address
        // EIP-1967 Implementation slot: bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1)
        bytes32 implSlot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        bytes32 implementation = vm.load(address(vault), implSlot);
        
        vm.etch(target, address(vault).code);
        vm.store(target, implSlot, implementation);

        // 2. Fix State: Copy Owner and MerklDistributor
        // Based on forge inspect storage layout:
        // _owner is at slot 151
        uint256 ownerSlot = 151;
        vm.store(target, bytes32(ownerSlot), vm.load(address(vault), bytes32(ownerSlot)));
        // _s starts at slot 254
        // _s.merklDistributor is at slot 256 (254: balances/fees, 255: gap/fee, 256: merkl)
        uint256 merklSlot = 256;
        vm.store(target, bytes32(merklSlot), vm.load(address(vault), bytes32(merklSlot)));
    }
}
