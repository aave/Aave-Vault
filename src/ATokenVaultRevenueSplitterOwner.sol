// SPDX-License-Identifier: UNLICENSED
// All Rights Reserved © AaveCo

pragma solidity ^0.8.10;

import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {IATokenVault} from "./interfaces/IATokenVault.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";

contract ATokenVaultOwner is Ownable {
    using SafeERC20 for IERC20;

    event RecipientSet(address indexed recipient, uint16 shareInBps);

    event RevenueSplit(address indexed recipient, address indexed asset, uint256 amount);

    uint256 public constant TOTAL_SHARE_IN_BPS = 10_000; // 100.00%

    IATokenVault public immutable VAULT;

    struct Recipient {
        address addr;
        uint16 shareInBps;
    }

    Recipient[] internal _recipients;

    constructor(address vault, address owner, Recipient[] memory recipients) {
        VAULT = IATokenVault(vault);
        _setRecipients(recipients);
        _transferOwnership(owner);
    }

    function transferVaultOwnership(address newOwner) public onlyOwner {
        _claimRewards();
        _withdrawFees();
        Ownable(address(VAULT)).transferOwnership(newOwner);
    }

    // Fees - Percentage of the yield earned by the vault (aToken)
    // TODO: Does it make sense to allow partial withdrawal? I got rid of the `amount` param by doing a full one always
    // TODO: Any reason to make it onlyOwner?
    function withdrawFees() public {
        _withdrawFees();
    }

    // Rewards - Percentage of the token incentives granted to the vault
    // TODO: Any reason to make it onlyOwner?
    function claimRewards() external {
        _claimRewards();
    }

    // TODO: Any reason to make it onlyOwner?
    function splitRevenue(address[] calldata assets) public {
        Recipient[] memory recipients = _recipients;
        for (uint256 i = 0; i < assets.length; i++) {
            uint256 amountToSplit = IERC20(assets[i]).balanceOf(address(this));
            for (uint256 j = 0; j < recipients.length; j++) {
                uint256 amountForRecipient = amountToSplit * recipients[j].shareInBps / TOTAL_SHARE_IN_BPS;
                if (amountForRecipient > 0) {
                    IERC20(assets[i]).safeTransfer(recipients[j].addr, amountForRecipient);
                }
                emit RevenueSplit(recipients[j].addr, assets[i], amountForRecipient);
            }
        }
    }

    // TODO: address(0) used in the event instead of ad-hoc event for native revenue?
    // TODO: Should we assume recipients will succeed at receiving native? If one fails, the whole call fails.
    function splitRevenue() public {
        uint256 amountToSplit = address(this).balance;
        for (uint256 j = 0; j < _recipients.length; j++) {
            uint256 amountForRecipient = amountToSplit * _recipients[j].shareInBps / TOTAL_SHARE_IN_BPS;
            if (amountForRecipient > 0) {
                (bool transferSucceeded, ) = _recipients[j].addr.call{value: amountForRecipient}("");
                require(transferSucceeded, "NATIVE_TRANSFER_FAILED");
            }
            emit RevenueSplit(_recipients[j].addr, address(0), amountForRecipient);
        }
    }

    function emergencyRescue(address asset, address to, uint256 amount) public onlyOwner {
        VAULT.emergencyRescue(asset, to, amount);
    }

    function setFee(uint256 newFee) public onlyOwner {
        VAULT.setFee(newFee);
    }

    function getRecipients() public view returns (Recipient[] memory) {
        return _recipients;
    }

    function _claimRewards() internal {
        VAULT.claimRewards(address(this));
    }

    function _withdrawFees() internal {
        uint256 feesToWithdraw = VAULT.getClaimableFees();
        VAULT.withdrawFees(address(this), feesToWithdraw);
    }

    // Assumes no duplicates
    function _setRecipients(Recipient[] memory recipients) internal {
        uint256 accumulatedShareInBps = 0;
        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i].shareInBps > 0, "BPS_SHARE_CANNOT_BE_ZERO");
            accumulatedShareInBps += recipients[i].shareInBps;
            _recipients.push(recipients[i]);
            emit RecipientSet(recipients[i].addr, recipients[i].shareInBps);
        }
        require(accumulatedShareInBps == TOTAL_SHARE_IN_BPS, "WRONG_BPS_SUM");
    }
}
