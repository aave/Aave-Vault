// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import {MockATokenVault} from "./mocks/MockATokenVault.sol";
import {MockDAI} from "./mocks/MockDAI.sol";
import {ATokenVaultRevenueSplitterOwner} from "../src/ATokenVaultRevenueSplitterOwner.sol";
import {IATokenVault} from "../src/interfaces/IATokenVault.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";

contract ATokenVaultRevenueSplitterOwnerTest is Test {

    address owner;

    MockDAI aToken;

    MockDAI rewardAssetI;
    MockDAI rewardAssetII;

    MockATokenVault vault;

    address recipientI;
    address recipientII;
    address recipientIII;

    uint16 shareI;
    uint16 shareII;
    uint16 shareIII;

    ATokenVaultRevenueSplitterOwner.Recipient[] recipients;

    ATokenVaultRevenueSplitterOwner revenueSplitterOwner;

    function setUp() public {
        owner = address(this);

        aToken = new MockDAI();

        rewardAssetI = new MockDAI();
        rewardAssetII = new MockDAI();

        vault = new MockATokenVault(address(aToken), owner);

        recipientI = makeAddr("recipientI");
        recipientII = makeAddr("recipientII");
        recipientIII = makeAddr("recipientIII");

        shareI = 1000; // 10.00%
        shareII = 2000; // 20.00%
        shareIII = 7000; // 70.00%

        recipients.push(ATokenVaultRevenueSplitterOwner.Recipient({
            addr: recipientI,
            shareInBps: shareI
        }));
        recipients.push(ATokenVaultRevenueSplitterOwner.Recipient({
            addr: recipientII,
            shareInBps: shareII
        }));
        recipients.push(ATokenVaultRevenueSplitterOwner.Recipient({
            addr: recipientIII,
            shareInBps: shareIII
        }));

        revenueSplitterOwner = new ATokenVaultRevenueSplitterOwner(address(vault), owner, recipients);

        vault.transferOwnership(address(revenueSplitterOwner));
    }

    function test_constructor_setsParametersCorrectly(address someVault, address someOwner) public {
        vm.assume(someOwner != address(0));

        revenueSplitterOwner = new ATokenVaultRevenueSplitterOwner(someVault, someOwner, recipients);

        assertEq(address(revenueSplitterOwner.VAULT()), someVault);
        assertEq(revenueSplitterOwner.owner(), someOwner);
        ATokenVaultRevenueSplitterOwner.Recipient[] memory returnedRecipients = revenueSplitterOwner.getRecipients();
        assertEq(returnedRecipients.length, recipients.length);
        for (uint256 i = 0; i < recipients.length; i++) {
            assertEq(returnedRecipients[i].addr, recipients[i].addr);
            assertEq(returnedRecipients[i].shareInBps, recipients[i].shareInBps);
        }
    }

    function test_constructor_revertsUponEmptyRecipients() public {
        ATokenVaultRevenueSplitterOwner.Recipient[] memory emptyRecipients =
            new ATokenVaultRevenueSplitterOwner.Recipient[](0);

        vm.expectRevert("MISSING_RECIPIENTS");
        new ATokenVaultRevenueSplitterOwner(address(vault), owner, emptyRecipients);
    }

    function test_constructor_revertsIfSomeRecipientShareIsZero() public {
        recipients[0].shareInBps = 0;

        vm.expectRevert("BPS_SHARE_CANNOT_BE_ZERO");
        new ATokenVaultRevenueSplitterOwner(address(vault), owner, recipients);
    }

    function test_constructor_revertsIfRecipientsSumExceedsTotalBpsSum() public {
        // Sum of shares (50.00% + 30.00% + 30.00% = 110.00%) exceeds the expected 100.00%
        recipients[0].shareInBps = 5_000; // 50.00%
        recipients[1].shareInBps = 3_000; // 30.00%
        recipients[2].shareInBps = 3_000; // 30.00%

        vm.expectRevert("WRONG_BPS_SUM");
        new ATokenVaultRevenueSplitterOwner(address(vault), owner, recipients);
    }

    function test_constructor_revertsIfRecipientsSumIsLessThanTotalBpsSum() public {
        // Sum of shares (10.00% + 20.00% + 30.00% = 60.00%) is less than the expected 100.00%
        recipients[0].shareInBps = 5_000; // 10.00%
        recipients[1].shareInBps = 3_000; // 20.00%
        recipients[2].shareInBps = 3_000; // 30.00%

        vm.expectRevert("WRONG_BPS_SUM");
        new ATokenVaultRevenueSplitterOwner(address(vault), owner, recipients);
    }

    function test_withdrawFees_withdrawsAllFeesToOwnerContract(uint256 amount) public {
        vault.mockFees(amount);

        assertEq(aToken.balanceOf(address(revenueSplitterOwner)), 0);

        vm.expectCall(
            address(vault),
            abi.encodeWithSelector(IATokenVault.withdrawFees.selector, address(revenueSplitterOwner), amount)
        );
        revenueSplitterOwner.withdrawFees();

        assertEq(aToken.balanceOf(address(revenueSplitterOwner)), amount);
    }

    function test_withdrawFees_canBeCalledByAnyone(address msgSender, uint256 amount) public {
        vault.mockFees(amount);

        assertEq(aToken.balanceOf(address(revenueSplitterOwner)), 0);

        vm.expectCall(
            address(vault),
            abi.encodeWithSelector(IATokenVault.withdrawFees.selector, address(revenueSplitterOwner), amount)
        );

        vm.prank(msgSender);
        revenueSplitterOwner.withdrawFees();

        assertEq(aToken.balanceOf(address(revenueSplitterOwner)), amount);
    }

    function test_claimRewards_claimsAllRewardsToOwnerContract(uint256 amountRewardI, uint256 amountRewardII) public {
        address[] memory rewardAssets = new address[](2);
        rewardAssets[0] = address(rewardAssetI);
        rewardAssets[1] = address(rewardAssetII);

        uint256[] memory rewardAmounts = new uint256[](2);
        rewardAmounts[0] = amountRewardI;
        rewardAmounts[1] = amountRewardII;

        vault.mockRewards(rewardAssets, rewardAmounts);

        assertEq(rewardAssetI.balanceOf(address(revenueSplitterOwner)), 0);
        assertEq(rewardAssetII.balanceOf(address(revenueSplitterOwner)), 0);

        vm.expectCall(
            address(vault),
            abi.encodeWithSelector(IATokenVault.claimRewards.selector, address(revenueSplitterOwner))
        );

        revenueSplitterOwner.claimRewards();

        assertEq(rewardAssetI.balanceOf(address(revenueSplitterOwner)), amountRewardI);
        assertEq(rewardAssetII.balanceOf(address(revenueSplitterOwner)), amountRewardII);
    }

    function test_claimRewards_canBeCalledByAnyone(address msgSender, uint256 amountRewardI, uint256 amountRewardII) public {
        address[] memory rewardAssets = new address[](2);
        rewardAssets[0] = address(rewardAssetI);
        rewardAssets[1] = address(rewardAssetII);

        uint256[] memory rewardAmounts = new uint256[](2);
        rewardAmounts[0] = amountRewardI;
        rewardAmounts[1] = amountRewardII;

        vault.mockRewards(rewardAssets, rewardAmounts);

        assertEq(rewardAssetI.balanceOf(address(revenueSplitterOwner)), 0);
        assertEq(rewardAssetII.balanceOf(address(revenueSplitterOwner)), 0);

        vm.expectCall(
            address(vault),
            abi.encodeWithSelector(IATokenVault.claimRewards.selector, address(revenueSplitterOwner))
        );

        vm.prank(msgSender);
        revenueSplitterOwner.claimRewards();

        assertEq(rewardAssetI.balanceOf(address(revenueSplitterOwner)), amountRewardI);
        assertEq(rewardAssetII.balanceOf(address(revenueSplitterOwner)), amountRewardII);
    }

    function test_emergencyRescue_nonOwnerCallReverts(
        address msgSender,
        address assetToRescue,
        address to,
        uint256 amount
    ) public {
        vm.assume(msgSender != owner);

        vm.prank(msgSender);
        vm.expectRevert("Ownable: caller is not the owner");
        revenueSplitterOwner.emergencyRescue(assetToRescue, to, amount);
    }

    function test_emergencyRescue(address assetToRescue, address to, uint256 amount) public {
        vm.expectCall(
            address(vault),
            abi.encodeWithSelector(IATokenVault.emergencyRescue.selector, assetToRescue, to, amount)
        );

        revenueSplitterOwner.emergencyRescue(assetToRescue, to, amount);
    }

    function test_setFee_nonOwnerCallReverts(address msgSender, uint256 newFee) public {
        vm.assume(msgSender != owner);

        vm.prank(msgSender);
        vm.expectRevert("Ownable: caller is not the owner");
        revenueSplitterOwner.setFee(newFee);
    }

    function test_setFee(uint256 newFee) public {
        vm.expectCall(
            address(vault),
            abi.encodeWithSelector(IATokenVault.setFee.selector, newFee)
        );

        revenueSplitterOwner.setFee(newFee);
    }

    function test_transferVaultOwnership_nonOwnerCallReverts(address msgSender, address newVaultOwner) public {
        vm.assume(newVaultOwner != address(0));
        vm.assume(msgSender != owner);

        vm.prank(msgSender);
        vm.expectRevert("Ownable: caller is not the owner");
        revenueSplitterOwner.transferVaultOwnership(newVaultOwner);
    }

    function test_transferVaultOwnership_setsTheRightNewVaultOwner(address newVaultOwner) public {
        vm.assume(newVaultOwner != address(0));

        vm.expectCall(
            address(vault),
            abi.encodeWithSelector(Ownable.transferOwnership.selector, newVaultOwner)
        );

        revenueSplitterOwner.transferVaultOwnership(newVaultOwner);

        assertEq(Ownable(address(vault)).owner(), newVaultOwner);
    }

    function test_transferVaultOwnership_claimRewardsAndWithdrawFees(
        address newVaultOwner,
        uint256 feesToWithdraw,
        uint256 rewardsToClaimI,
        uint256 rewardsToClaimII
    ) public {
        vm.assume(newVaultOwner != address(0));

        vault.mockFees(feesToWithdraw);

        address[] memory rewardAssets = new address[](2);
        rewardAssets[0] = address(rewardAssetI);
        rewardAssets[1] = address(rewardAssetII);
        uint256[] memory rewardAmounts = new uint256[](2);
        rewardAmounts[0] = rewardsToClaimI;
        rewardAmounts[1] = rewardsToClaimII;
        vault.mockRewards(rewardAssets, rewardAmounts);

        vm.expectCall(
            address(vault),
            abi.encodeWithSelector(Ownable.transferOwnership.selector, newVaultOwner)
        );

        vm.expectCall(
            address(vault),
            abi.encodeWithSelector(IATokenVault.claimRewards.selector, address(revenueSplitterOwner))
        );

        vm.expectCall(
            address(vault),
            abi.encodeWithSelector(IATokenVault.withdrawFees.selector, address(revenueSplitterOwner), feesToWithdraw)
        );

        assertEq(rewardAssetI.balanceOf(address(revenueSplitterOwner)), 0);
        assertEq(rewardAssetII.balanceOf(address(revenueSplitterOwner)), 0);
        assertEq(aToken.balanceOf(address(revenueSplitterOwner)), 0);

        revenueSplitterOwner.transferVaultOwnership(newVaultOwner);

        assertEq(Ownable(address(vault)).owner(), newVaultOwner);
        assertEq(rewardAssetI.balanceOf(address(revenueSplitterOwner)), rewardsToClaimI);
        assertEq(rewardAssetII.balanceOf(address(revenueSplitterOwner)), rewardsToClaimII);
        assertEq(aToken.balanceOf(address(revenueSplitterOwner)), feesToWithdraw);
    }

    function test_transferOwnership_nonOwnerCallReverts(address msgSender, address newOwner) public {
        vm.assume(newOwner != address(0));
        vm.assume(msgSender != owner);

        vm.prank(msgSender);
        vm.expectRevert("Ownable: caller is not the owner");
        revenueSplitterOwner.transferOwnership(newOwner);

        assertEq(revenueSplitterOwner.owner(), owner);
    }

    function test_transferOwnership(address newOwner) public {
        vm.assume(newOwner != address(0));

        revenueSplitterOwner.transferOwnership(newOwner);

        assertEq(revenueSplitterOwner.owner(), newOwner);
    }
}
