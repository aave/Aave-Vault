// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import {MockATokenVault} from "./mocks/MockATokenVault.sol";
import {MockDAI} from "./mocks/MockDAI.sol";
import {ATokenVaultRevenueSplitterOwner} from "../src/ATokenVaultRevenueSplitterOwner.sol";
import {IATokenVault} from "../src/interfaces/IATokenVault.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {MockReentrant} from "./mocks/MockReentrant.sol";

contract ATokenVaultRevenueSplitterOwnerTest is Test {

    event RecipientSet(address indexed recipient, uint16 shareInBps);
    event RevenueSplit(address indexed recipient, address indexed asset, uint256 amount);

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

        shareI = 1_000; // 10.00%
        shareII = 2_000; // 20.00%
        shareIII = 7_000; // 70.00%

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

    function test_splitRevenue_distributesRevenueToAllRecipientsAccordingToTheirShares() public {
        MockDAI assetToSplit = new MockDAI();
        uint256 amountToSplit = 250_000;

        assertEq(assetToSplit.balanceOf(address(revenueSplitterOwner)), 0);
        assertEq(assetToSplit.balanceOf(address(recipientI)), 0);
        assertEq(assetToSplit.balanceOf(address(recipientII)), 0);
        assertEq(assetToSplit.balanceOf(address(recipientIII)), 0);

        assetToSplit.mint(address(revenueSplitterOwner), amountToSplit);

        assertEq(assetToSplit.balanceOf(address(revenueSplitterOwner)), amountToSplit);

        address[] memory assetsToSplit = new address[](1);
        assetsToSplit[0] = address(assetToSplit);

        revenueSplitterOwner.splitRevenue(assetsToSplit);

        assertEq(assetToSplit.balanceOf(address(revenueSplitterOwner)), 0);
        assertEq(assetToSplit.balanceOf(address(recipientI)), 25_000);
        assertEq(assetToSplit.balanceOf(address(recipientII)), 50_000);
        assertEq(assetToSplit.balanceOf(address(recipientIII)), 175_000);
    }

    function test_splitRevenue_distributesRevenueToAllRecipientsAccordingToTheirShares_MultipleAssets() public {
        MockDAI assetToSplitI = new MockDAI();
        MockDAI assetToSplitII = new MockDAI();

        address[] memory assetsToSplit = new address[](2);
        assetsToSplit[0] = address(assetToSplitI);
        assetsToSplit[1] = address(assetToSplitII);

        assertEq(assetToSplitI.balanceOf(address(revenueSplitterOwner)), 0);

        assertEq(assetToSplitI.balanceOf(address(recipientI)), 0);
        assertEq(assetToSplitI.balanceOf(address(recipientII)), 0);
        assertEq(assetToSplitI.balanceOf(address(recipientIII)), 0);

        assertEq(assetToSplitII.balanceOf(address(recipientI)), 0);
        assertEq(assetToSplitII.balanceOf(address(recipientII)), 0);
        assertEq(assetToSplitII.balanceOf(address(recipientIII)), 0);

        uint256 amountToSplitI = 250_000;
        assetToSplitI.mint(address(revenueSplitterOwner), amountToSplitI);
        assertEq(assetToSplitI.balanceOf(address(revenueSplitterOwner)), amountToSplitI);

        uint256 amountToSplitII = 100_000;
        assetToSplitII.mint(address(revenueSplitterOwner), amountToSplitII);
        assertEq(assetToSplitII.balanceOf(address(revenueSplitterOwner)), amountToSplitII);

        revenueSplitterOwner.splitRevenue(assetsToSplit);

        assertEq(assetToSplitI.balanceOf(address(revenueSplitterOwner)), 0);

        assertEq(assetToSplitI.balanceOf(address(recipientI)), 25_000);
        assertEq(assetToSplitI.balanceOf(address(recipientII)), 50_000);
        assertEq(assetToSplitI.balanceOf(address(recipientIII)), 175_000);

        assertEq(assetToSplitII.balanceOf(address(recipientI)), 10_000);
        assertEq(assetToSplitII.balanceOf(address(recipientII)), 20_000);
        assertEq(assetToSplitII.balanceOf(address(recipientIII)), 70_000);
    }

    function test_splitRevenue_canBeCalledByAnyone(address msgSender) public {
        MockDAI assetToSplit = new MockDAI();
        address[] memory assetsToSplit = new address[](1);
        assetsToSplit[0] = address(assetToSplit);

        uint256 amountToSplit = 1_000;

        assertEq(assetToSplit.balanceOf(address(revenueSplitterOwner)), 0);
        assertEq(assetToSplit.balanceOf(address(recipientI)), 0);
        assertEq(assetToSplit.balanceOf(address(recipientII)), 0);
        assertEq(assetToSplit.balanceOf(address(recipientIII)), 0);

        assetToSplit.mint(address(revenueSplitterOwner), amountToSplit);

        assertEq(assetToSplit.balanceOf(address(revenueSplitterOwner)), amountToSplit);

        vm.prank(msgSender);
        revenueSplitterOwner.splitRevenue(assetsToSplit);

        assertEq(assetToSplit.balanceOf(address(revenueSplitterOwner)), 0);
        assertEq(assetToSplit.balanceOf(address(recipientI)), 100);
        assertEq(assetToSplit.balanceOf(address(recipientII)), 200);
        assertEq(assetToSplit.balanceOf(address(recipientIII)), 700);
    }

    function test_splitRevenue_emitsExpectedEvents() public {
        MockDAI assetToSplit = new MockDAI();
        address[] memory assetsToSplit = new address[](1);
        assetsToSplit[0] = address(assetToSplit);

        uint256 amountToSplit = 1_000;

        assetToSplit.mint(address(revenueSplitterOwner), amountToSplit);

        vm.expectEmit(true, true, true, true);
        emit RevenueSplit(address(recipientI), address(assetToSplit), 100);
        vm.expectEmit(true, true, true, true);
        emit RevenueSplit(address(recipientII), address(assetToSplit), 200);
        vm.expectEmit(true, true, true, true);
        emit RevenueSplit(address(recipientIII), address(assetToSplit), 700);

        revenueSplitterOwner.splitRevenue(assetsToSplit);
    }

    function test_splitRevenue_distributesRevenueToAllRecipientsAccordingToTheirShares_FuzzAmount(
        uint256 amountToSplit
    ) public {
        amountToSplit = bound(amountToSplit, 0, type(uint240).max);

        MockDAI assetToSplit = new MockDAI();

        assertEq(assetToSplit.balanceOf(address(revenueSplitterOwner)), 0);
        assertEq(assetToSplit.balanceOf(address(recipientI)), 0);
        assertEq(assetToSplit.balanceOf(address(recipientII)), 0);
        assertEq(assetToSplit.balanceOf(address(recipientIII)), 0);

        assetToSplit.mint(address(revenueSplitterOwner), amountToSplit);

        assertEq(assetToSplit.balanceOf(address(revenueSplitterOwner)), amountToSplit);

        address[] memory assetsToSplit = new address[](1);
        assetsToSplit[0] = address(assetToSplit);

        revenueSplitterOwner.splitRevenue(assetsToSplit);

        assertEq(assetToSplit.balanceOf(address(recipientI)), amountToSplit * shareI / 10_000);
        assertEq(assetToSplit.balanceOf(address(recipientII)), amountToSplit * shareII / 10_000);
        assertEq(assetToSplit.balanceOf(address(recipientIII)), amountToSplit * shareIII / 10_000);

        // The remaining unsplit amount is capped to the be strictly less than the number of recipients
        assertLe(assetToSplit.balanceOf(address(revenueSplitterOwner)), recipients.length - 1);
    }

    function test_splitRevenue_distributesRevenueToAllRecipientsAccordingToTheirShares_NativeCurrency() public {
        uint256 amountToSplit = 250_000;

        assertEq(address(revenueSplitterOwner).balance, 0);
        assertEq(address(recipientI).balance, 0);
        assertEq(address(recipientII).balance, 0);
        assertEq(address(recipientIII).balance, 0);

        vm.deal(address(revenueSplitterOwner), amountToSplit);

        assertEq(address(revenueSplitterOwner).balance, amountToSplit);

        revenueSplitterOwner.splitRevenue();

        assertEq(address(revenueSplitterOwner).balance, 0);
        assertEq(address(recipientI).balance, 25_000);
        assertEq(address(recipientII).balance, 50_000);
        assertEq(address(recipientIII).balance, 175_000);
    }

    function test_splitRevenue_emitsExpectedEvents_NativeCurrency() public {    
        uint256 amountToSplit = 1_000;

        vm.deal(address(revenueSplitterOwner), amountToSplit);

        vm.expectEmit(true, true, true, true);
        emit RevenueSplit(address(recipientI), address(0), 100);
        vm.expectEmit(true, true, true, true);
        emit RevenueSplit(address(recipientII), address(0), 200);
        vm.expectEmit(true, true, true, true);
        emit RevenueSplit(address(recipientIII), address(0), 700);

        revenueSplitterOwner.splitRevenue();
    }

    function test_splitRevenue_canBeCalledByAnyone_NativeCurrency(address msgSender) public {
        uint256 amountToSplit = 1_000;

        assertEq(address(revenueSplitterOwner).balance, 0);
        assertEq(address(recipientI).balance, 0);
        assertEq(address(recipientII).balance, 0);
        assertEq(address(recipientIII).balance, 0);

        vm.deal(address(revenueSplitterOwner), amountToSplit);

        assertEq(address(revenueSplitterOwner).balance, amountToSplit);

        vm.prank(msgSender);
        revenueSplitterOwner.splitRevenue();

        assertEq(address(revenueSplitterOwner).balance, 0);
        assertEq(address(recipientI).balance, 100);
        assertEq(address(recipientII).balance, 200);
        assertEq(address(recipientIII).balance, 700);
    }

    function test_splitRevenue_distributesRevenueToAllRecipientsAccordingToTheirShares_FuzzAmount_NativeCurrency(
        uint256 amountToSplit
    ) public {
        amountToSplit = bound(amountToSplit, 0, type(uint240).max);

        assertEq(address(revenueSplitterOwner).balance, 0);
        assertEq(address(recipientI).balance, 0);
        assertEq(address(recipientII).balance, 0);
        assertEq(address(recipientIII).balance, 0);

        vm.deal(address(revenueSplitterOwner), amountToSplit);

        assertEq(address(revenueSplitterOwner).balance, amountToSplit);

        revenueSplitterOwner.splitRevenue();

        assertEq(address(recipientI).balance, amountToSplit * shareI / 10_000);
        assertEq(address(recipientII).balance, amountToSplit * shareII / 10_000);
        assertEq(address(recipientIII).balance, amountToSplit * shareIII / 10_000);

        // The remaining unsplit amount is capped to the be strictly less than the number of recipients
        assertLe(address(revenueSplitterOwner).balance, recipients.length - 1);
    }

    function test_splitRevenue_distributesRevenueToAllRecipientsAccordingToTheirShares_FuzzShares(
        uint16 fuzzShareI
    ) public {
        recipients.pop();
        assertEq(recipients.length, 2);

        fuzzShareI = uint16(bound(fuzzShareI, 1, 10_000 - 1));
        uint16 fuzzShareII = 10_000 - fuzzShareI;

        recipients[0].shareInBps = fuzzShareI;
        recipients[1].shareInBps = fuzzShareII;

        // Redeploys the splitter with the new recipients configuration
        revenueSplitterOwner = new ATokenVaultRevenueSplitterOwner(address(vault), owner, recipients);

        uint256 amountToSplit = 100_000;
        MockDAI assetToSplit = new MockDAI();

        assertEq(assetToSplit.balanceOf(address(revenueSplitterOwner)), 0);
        assertEq(assetToSplit.balanceOf(address(recipientI)), 0);
        assertEq(assetToSplit.balanceOf(address(recipientII)), 0);
        assertEq(assetToSplit.balanceOf(address(recipientIII)), 0); // Not set as recipient

        assetToSplit.mint(address(revenueSplitterOwner), amountToSplit);

        assertEq(assetToSplit.balanceOf(address(revenueSplitterOwner)), amountToSplit);

        address[] memory assetsToSplit = new address[](1);
        assetsToSplit[0] = address(assetToSplit);

        revenueSplitterOwner.splitRevenue(assetsToSplit);

        assertEq(assetToSplit.balanceOf(address(recipientI)), amountToSplit * fuzzShareI / 10_000);
        assertEq(assetToSplit.balanceOf(address(recipientII)), amountToSplit * fuzzShareII / 10_000);
        assertEq(assetToSplit.balanceOf(address(recipientIII)), 0); // Not set as recipient

        // The remaining unsplit amount is capped to the be strictly less than the number of recipients
        assertLe(assetToSplit.balanceOf(address(revenueSplitterOwner)), recipients.length - 1);
    }

    function test_splitRevenue_distributesRevenueToAllRecipientsAccordingToTheirShares_FuzzShares_NativeCurrency(
        uint16 fuzzShareI
    ) public {
        recipients.pop();
        assertEq(recipients.length, 2);

        fuzzShareI = uint16(bound(fuzzShareI, 1, 10_000 - 1));
        uint16 fuzzShareII = 10_000 - fuzzShareI;

        recipients[0].shareInBps = fuzzShareI;
        recipients[1].shareInBps = fuzzShareII;

        // Redeploys the splitter with the new recipients configuration
        revenueSplitterOwner = new ATokenVaultRevenueSplitterOwner(address(vault), owner, recipients);

        uint256 amountToSplit = 100_000;

        assertEq(address(revenueSplitterOwner).balance, 0);
        assertEq(address(recipientI).balance, 0);
        assertEq(address(recipientII).balance, 0);
        assertEq(address(recipientIII).balance, 0); // Not set as recipient

        vm.deal(address(revenueSplitterOwner), amountToSplit);

        assertEq(address(revenueSplitterOwner).balance, amountToSplit);

        revenueSplitterOwner.splitRevenue();

        assertEq(address(recipientI).balance, amountToSplit * fuzzShareI / 10_000);
        assertEq(address(recipientII).balance, amountToSplit * fuzzShareII / 10_000);
        assertEq(address(recipientIII).balance, 0); // Not set as recipient

        // The remaining unsplit amount is capped to the be strictly less than the number of recipients
        assertLe(address(revenueSplitterOwner).balance, recipients.length - 1);
    }

    function test_splitRevenue_revertsUponReentrancy() public {
        MockReentrant reentrantRecipient = new MockReentrant();
        
        recipients.pop();
        recipients[0].addr = address(reentrantRecipient);
        recipients[0].shareInBps = 5_000;
        recipients[1].shareInBps = 5_000;

        revenueSplitterOwner = new ATokenVaultRevenueSplitterOwner(address(vault), owner, recipients);
        reentrantRecipient.configureReentrancy({
            target: address(revenueSplitterOwner),
            data: abi.encodeWithSelector(bytes4(keccak256("splitRevenue()"))),
            msgValue: 0,
            times: 1
        });

        vm.deal(address(revenueSplitterOwner), 100_000);
        assertEq(address(revenueSplitterOwner).balance, 100_000);

        vm.expectRevert("NATIVE_TRANSFER_FAILED");
        revenueSplitterOwner.splitRevenue();
    }
}
