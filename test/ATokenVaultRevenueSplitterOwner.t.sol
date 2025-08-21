// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import {MockATokenVault} from "./mocks/MockATokenVault.sol";
import {MockDAI} from "./mocks/MockDAI.sol";
import {ATokenVaultRevenueSplitterOwner} from "../src/ATokenVaultRevenueSplitterOwner.sol";
import {IATokenVault} from "../src/interfaces/IATokenVault.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";

contract ATokenVaultRevenueSplitterOwnerTest is Test {

    event RecipientSet(address indexed recipient, uint16 shareInBps);
    event RevenueSplitTransferred(address indexed recipient, address indexed asset, uint256 amount);

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

    uint256 public constant TOTAL_SHARE_IN_BPS = 10_000;

    uint256 public constant UNIT_OF_DUST = 1;

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

    function test_constructor_revertsIfSomeRecipientIsDuplicated(
        uint8 recipientsLength, uint8 setDuplicatedAt, uint8 copyFrom
    ) public {
        recipientsLength = uint8(bound(recipientsLength, 2, 15));
        setDuplicatedAt = uint8(bound(setDuplicatedAt, 0, recipientsLength - 1));
        copyFrom = uint8(bound(copyFrom, 0, recipientsLength - 1));
        vm.assume(setDuplicatedAt != copyFrom);


        uint16 eachRecipientShare = uint16(TOTAL_SHARE_IN_BPS / recipientsLength);
        uint16 accumulatedShares = 0;
        
        ATokenVaultRevenueSplitterOwner.Recipient[] memory recipientsWithDuplicate =
            new ATokenVaultRevenueSplitterOwner.Recipient[](recipientsLength);
        for (uint8 i = 0; i < recipientsLength - 1; i++) {
            recipientsWithDuplicate[i].addr = makeAddr(string(abi.encodePacked("recipient", i)));
            recipientsWithDuplicate[i].shareInBps = eachRecipientShare;
            accumulatedShares += eachRecipientShare;
        }
        recipientsWithDuplicate[recipientsLength - 1].addr = makeAddr(string(abi.encodePacked("recipient", recipientsLength - 1)));
        recipientsWithDuplicate[recipientsLength - 1].shareInBps = uint16(TOTAL_SHARE_IN_BPS - accumulatedShares);

        recipientsWithDuplicate[setDuplicatedAt].addr = recipientsWithDuplicate[copyFrom].addr;

        vm.expectRevert("DUPLICATED_RECIPIENT");
        new ATokenVaultRevenueSplitterOwner(address(vault), owner, recipientsWithDuplicate);
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

        if (amount > 0) {
            vm.expectCall(
                address(vault),
                abi.encodeWithSelector(IATokenVault.withdrawFees.selector, address(revenueSplitterOwner), amount)
            );
        }
        revenueSplitterOwner.withdrawFees();

        assertEq(aToken.balanceOf(address(revenueSplitterOwner)), amount);
    }

    function test_withdrawFees_canBeCalledByAnyone(address msgSender, uint256 amount) public {
        vault.mockFees(amount);

        assertEq(aToken.balanceOf(address(revenueSplitterOwner)), 0);

        if (amount > 0) {
            vm.expectCall(
                address(vault),
                abi.encodeWithSelector(IATokenVault.withdrawFees.selector, address(revenueSplitterOwner), amount)
            );
        }

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

        if (feesToWithdraw > 0) {
            vm.expectCall(
                address(vault),
                abi.encodeWithSelector(IATokenVault.withdrawFees.selector, address(revenueSplitterOwner), feesToWithdraw)
            );
        }

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
        uint256 assetBalance = 250_001;
        uint256 amountToSplit = assetBalance - UNIT_OF_DUST;

        assertEq(assetToSplit.balanceOf(address(revenueSplitterOwner)), 0);
        assertEq(assetToSplit.balanceOf(address(recipientI)), 0);
        assertEq(assetToSplit.balanceOf(address(recipientII)), 0);
        assertEq(assetToSplit.balanceOf(address(recipientIII)), 0);

        assetToSplit.mint(address(revenueSplitterOwner), assetBalance);

        assertEq(assetToSplit.balanceOf(address(revenueSplitterOwner)), assetBalance);

        address[] memory assetsToSplit = new address[](1);
        assetsToSplit[0] = address(assetToSplit);

        revenueSplitterOwner.splitRevenue(assetsToSplit);

        assertEq(assetToSplit.balanceOf(address(revenueSplitterOwner)), UNIT_OF_DUST);
        assertEq(assetToSplit.balanceOf(address(recipientI)), 25_000);
        assertEq(assetToSplit.balanceOf(address(recipientII)), 50_000);
        assertEq(assetToSplit.balanceOf(address(recipientIII)), 175_000);

        assertEq(amountToSplit,
            assetToSplit.balanceOf(address(recipientI)) +
            assetToSplit.balanceOf(address(recipientII)) +
            assetToSplit.balanceOf(address(recipientIII))
        );
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

        uint256 assetBalanceI = 250_001;
        uint256 amountToSplitI = assetBalanceI - UNIT_OF_DUST;
        assetToSplitI.mint(address(revenueSplitterOwner), assetBalanceI);
        assertEq(assetToSplitI.balanceOf(address(revenueSplitterOwner)), assetBalanceI);

        uint256 assetBalanceII = 100_001;
        uint256 amountToSplitII = assetBalanceII - UNIT_OF_DUST;
        assetToSplitII.mint(address(revenueSplitterOwner), assetBalanceII);
        assertEq(assetToSplitII.balanceOf(address(revenueSplitterOwner)), assetBalanceII);

        revenueSplitterOwner.splitRevenue(assetsToSplit);

        assertEq(assetToSplitI.balanceOf(address(revenueSplitterOwner)), UNIT_OF_DUST);

        assertEq(assetToSplitI.balanceOf(address(recipientI)), 25_000);
        assertEq(assetToSplitI.balanceOf(address(recipientII)), 50_000);
        assertEq(assetToSplitI.balanceOf(address(recipientIII)), 175_000);

        assertEq(amountToSplitI,
            assetToSplitI.balanceOf(address(recipientI)) +
            assetToSplitI.balanceOf(address(recipientII)) +
            assetToSplitI.balanceOf(address(recipientIII))
        );


        assertEq(assetToSplitII.balanceOf(address(recipientI)), 10_000);
        assertEq(assetToSplitII.balanceOf(address(recipientII)), 20_000);
        assertEq(assetToSplitII.balanceOf(address(recipientIII)), 70_000);

        assertEq(amountToSplitII,
            assetToSplitII.balanceOf(address(recipientI)) +
            assetToSplitII.balanceOf(address(recipientII)) +
            assetToSplitII.balanceOf(address(recipientIII))
        );
    }

    function test_splitRevenue_canBeCalledByAnyone(address msgSender) public {
        MockDAI assetToSplit = new MockDAI();
        address[] memory assetsToSplit = new address[](1);
        assetsToSplit[0] = address(assetToSplit);

        uint256 assetBalance = 1_001;
        uint256 amountToSplit = assetBalance - UNIT_OF_DUST;

        assertEq(assetToSplit.balanceOf(address(revenueSplitterOwner)), 0);
        assertEq(assetToSplit.balanceOf(address(recipientI)), 0);
        assertEq(assetToSplit.balanceOf(address(recipientII)), 0);
        assertEq(assetToSplit.balanceOf(address(recipientIII)), 0);

        assetToSplit.mint(address(revenueSplitterOwner), assetBalance);

        assertEq(assetToSplit.balanceOf(address(revenueSplitterOwner)), assetBalance);

        vm.prank(msgSender);
        revenueSplitterOwner.splitRevenue(assetsToSplit);

        assertEq(assetToSplit.balanceOf(address(revenueSplitterOwner)), UNIT_OF_DUST);
        assertEq(assetToSplit.balanceOf(address(recipientI)), 100);
        assertEq(assetToSplit.balanceOf(address(recipientII)), 200);
        assertEq(assetToSplit.balanceOf(address(recipientIII)), 700);

        assertEq(assetToSplit.balanceOf(address(recipientI)) +
            assetToSplit.balanceOf(address(recipientII)) +
            assetToSplit.balanceOf(address(recipientIII)),
            amountToSplit
        );
    }

    function test_splitRevenue_emitsExpectedEvents() public {
        MockDAI assetToSplit = new MockDAI();
        address[] memory assetsToSplit = new address[](1);
        assetsToSplit[0] = address(assetToSplit);

        uint256 assetBalance = 1_001;

        assetToSplit.mint(address(revenueSplitterOwner), assetBalance);

        vm.expectEmit(true, true, true, true);
        emit RevenueSplitTransferred(address(recipientI), address(assetToSplit), 100);
        vm.expectEmit(true, true, true, true);
        emit RevenueSplitTransferred(address(recipientII), address(assetToSplit), 200);
        vm.expectEmit(true, true, true, true);
        emit RevenueSplitTransferred(address(recipientIII), address(assetToSplit), 700);

        revenueSplitterOwner.splitRevenue(assetsToSplit);
    }

    function test_splitRevenue_distributesRevenueToAllRecipientsAccordingToTheirShares_FuzzAmount(
        uint256 contractBalance
    ) public {
        contractBalance = bound(contractBalance, 1, type(uint240).max);

        MockDAI assetToSplit = new MockDAI();

        assertEq(assetToSplit.balanceOf(address(revenueSplitterOwner)), 0);
        assertEq(assetToSplit.balanceOf(address(recipientI)), 0);
        assertEq(assetToSplit.balanceOf(address(recipientII)), 0);
        assertEq(assetToSplit.balanceOf(address(recipientIII)), 0);

        assetToSplit.mint(address(revenueSplitterOwner), contractBalance);

        assertEq(assetToSplit.balanceOf(address(revenueSplitterOwner)), contractBalance);

        address[] memory assetsToSplit = new address[](1);
        assetsToSplit[0] = address(assetToSplit);

        revenueSplitterOwner.splitRevenue(assetsToSplit);

        uint256 amountToSplit = contractBalance - UNIT_OF_DUST;

        assertEq(assetToSplit.balanceOf(address(recipientI)), amountToSplit * shareI / TOTAL_SHARE_IN_BPS);
        assertEq(assetToSplit.balanceOf(address(recipientII)), amountToSplit * shareII / TOTAL_SHARE_IN_BPS);
        assertEq(assetToSplit.balanceOf(address(recipientIII)), amountToSplit * shareIII / TOTAL_SHARE_IN_BPS);

        // The remaining unsplit amount is capped to the be less than the number of recipients for standard ERC-20s,
        // and recipients + 1 for aTokens.
        assertLe(assetToSplit.balanceOf(address(revenueSplitterOwner)), recipients.length);
    }

    function test_splitRevenue_revertsIfAssetHasNoBalance() public {
        MockDAI assetToSplit = new MockDAI();
        address[] memory assetsToSplit = new address[](1);
        assetsToSplit[0] = address(assetToSplit);

        assertEq(assetToSplit.balanceOf(address(revenueSplitterOwner)), 0);

        vm.expectRevert("ASSET_NOT_HELD_BY_SPLITTER");
        revenueSplitterOwner.splitRevenue(assetsToSplit);
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

        uint256 assetBalance = 100_001;
        uint256 amountToSplit = assetBalance - UNIT_OF_DUST;

        MockDAI assetToSplit = new MockDAI();

        assertEq(assetToSplit.balanceOf(address(revenueSplitterOwner)), 0);
        assertEq(assetToSplit.balanceOf(address(recipientI)), 0);
        assertEq(assetToSplit.balanceOf(address(recipientII)), 0);
        assertEq(assetToSplit.balanceOf(address(recipientIII)), 0); // Not set as recipient

        assetToSplit.mint(address(revenueSplitterOwner), assetBalance);

        assertEq(assetToSplit.balanceOf(address(revenueSplitterOwner)), assetBalance);

        address[] memory assetsToSplit = new address[](1);
        assetsToSplit[0] = address(assetToSplit);

        revenueSplitterOwner.splitRevenue(assetsToSplit);

        assertEq(assetToSplit.balanceOf(address(recipientI)), amountToSplit * fuzzShareI / TOTAL_SHARE_IN_BPS);
        assertEq(assetToSplit.balanceOf(address(recipientII)), amountToSplit * fuzzShareII / TOTAL_SHARE_IN_BPS);
        assertEq(assetToSplit.balanceOf(address(recipientIII)), 0); // Not set as recipient

        // The remaining unsplit amount is capped to the be less than the number of recipients for standard ERC-20s,
        // and recipients + 1 for aTokens.
        assertLe(assetToSplit.balanceOf(address(revenueSplitterOwner)), recipients.length);
    }

    function test_receive_revertsUponNativeTransfer(address msgSender, uint256 amount) public {
        vm.assume(amount > 0);
        vm.assume(msgSender != address(revenueSplitterOwner));

        assertEq(address(revenueSplitterOwner).balance, 0);

        vm.deal(msgSender, amount);

        bool transferSucceeded = false; // Avoid 'Return value of low-level calls not used' warning.

        vm.prank(msgSender);
        vm.expectRevert("NATIVE_CURRENCY_NOT_SUPPORTED");
        (transferSucceeded, ) = address(revenueSplitterOwner).call{value: amount}("");

        assertEq(address(revenueSplitterOwner).balance, 0);
    }

    function test_splitRevenue_roundingErrorIsNotAccumulatedAfterManySplits() public {
        shareI = 9_000; // 90.00%
        shareII = 500; // 5.00%
        shareIII = 500; // 5.00%

        recipients[0].shareInBps = shareI;
        recipients[1].shareInBps = shareII;
        recipients[2].shareInBps = shareIII;

        revenueSplitterOwner = new ATokenVaultRevenueSplitterOwner(address(vault), owner, recipients);

        uint256 accumulatedAmountToSplit;

        MockDAI assetToSplit = new MockDAI();
        uint256 assetBalance = 4;
        uint256 amountToSplit = assetBalance - UNIT_OF_DUST; // = 3
        accumulatedAmountToSplit += amountToSplit;
        address[] memory assetsToSplit = new address[](1);
        assetsToSplit[0] = address(assetToSplit);

        /// Split #1: Balance is 4, 3 units of asset to distribute, only recipientI gets revenue

        assertEq(assetToSplit.balanceOf(address(revenueSplitterOwner)), 0, "Unexpected initial splitter balance");
        assetToSplit.mint(address(revenueSplitterOwner), assetBalance);
        assertEq(assetToSplit.balanceOf(address(revenueSplitterOwner)), 4, "Unexpected splitter balance");

        revenueSplitterOwner.splitRevenue(assetsToSplit);

        assertEq(assetToSplit.balanceOf(address(recipientI)), 2, "Unexpected recipientI balance after 1st split");
        assertEq(assetToSplit.balanceOf(address(recipientII)), 0, "Unexpected recipientII balance after 1st split");
        assertEq(assetToSplit.balanceOf(address(recipientIII)), 0, "Unexpected recipientIII balance after 1st split");

        /// Split #2 - #10: Balance is 4 (2 new + 1 carried from previous rounding error split dust + 1 from the
        /// reserved unit to not fail in aToken transfers), 3 units of asset to distribute, only recipientI gets revenue
        for (uint256 i = 1; i <= 10; i++) {
            amountToSplit = 2;
            accumulatedAmountToSplit += amountToSplit;

            assetToSplit.mint(address(revenueSplitterOwner), amountToSplit);

            revenueSplitterOwner.splitRevenue(assetsToSplit);
        }
        assertEq(assetToSplit.balanceOf(address(recipientI)), 20, "Unexpected recipientI balance after 10th split");
        assertEq(assetToSplit.balanceOf(address(recipientII)), 1, "Unexpected recipientII balance after 10th split");
        assertEq(assetToSplit.balanceOf(address(recipientIII)), 1, "Unexpected recipientIII balance after 10th split");

        // Split #11: 3 units of asset (2 new + 1 carried from previous split dust), all get revenue

        amountToSplit = 2;
        accumulatedAmountToSplit += amountToSplit;

        assetToSplit.mint(address(revenueSplitterOwner), amountToSplit);

        revenueSplitterOwner.splitRevenue(assetsToSplit);

        assertEq(assetToSplit.balanceOf(address(recipientI)), 22, "Unexpected recipientI balance after 11th split");
        assertEq(assetToSplit.balanceOf(address(recipientII)), 1, "Unexpected recipientII balance after 11th split");
        assertEq(assetToSplit.balanceOf(address(recipientIII)), 1, "Unexpected recipientIII balance after 11th split");

        assertEq(accumulatedAmountToSplit, 25, "Unexpected accumulated amount to split");

        // The accumulated split is the expected and does not have accumulated rounding errors
        assertEq(
            assetToSplit.balanceOf(address(recipientI)), accumulatedAmountToSplit * shareI / TOTAL_SHARE_IN_BPS,
            "Split has accumulated rounding error for recipientI"
        );
        assertEq(
            assetToSplit.balanceOf(address(recipientII)), accumulatedAmountToSplit * shareII / TOTAL_SHARE_IN_BPS,
            "Split has accumulated rounding error for recipientII"
        );
        assertEq(
            assetToSplit.balanceOf(address(recipientIII)), accumulatedAmountToSplit * shareIII / TOTAL_SHARE_IN_BPS,
            "Split has accumulated rounding error for recipientIII"
        );

        // One unit of rounding error dust + one unit of reserved unit to not fail in aToken transfers
        assertEq(assetToSplit.balanceOf(address(revenueSplitterOwner)), 2, "Unexpected final splitter balance");
    }
}
