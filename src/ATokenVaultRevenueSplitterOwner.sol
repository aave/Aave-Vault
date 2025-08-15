// SPDX-License-Identifier: UNLICENSED
// All Rights Reserved © AaveCo

pragma solidity ^0.8.10;

import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {IATokenVault} from "./interfaces/IATokenVault.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";

/**
 * @title ATokenVaultRevenueSplitterOwner
 * @author Aave Labs
 * @notice ATokenVault owner with revenue split capabilities.
 */
contract ATokenVaultRevenueSplitterOwner is Ownable {
    using SafeERC20 for IERC20;

    /**
     * @dev Emitted at construction time for each recipient set.
     * @param recipient The address of the recipient set.
     * @param shareInBps The recipient's share of the revenue in basis points.
     */
    event RecipientSet(address indexed recipient, uint16 shareInBps);

    /**
     * @dev Emitted when revenue is split for each recipient and asset.
     * @param recipient The address of the recipient receiving the revenue.
     * @param asset The asset being split.
     * @param amount The amount of revenue sent to the recipient in the split asset.
     */
    event RevenueSplitTransferred(address indexed recipient, address indexed asset, uint256 amount);

    /**
     * @dev The sum of all recipients' shares in basis points, represents 100.00%. Each basis point is 0.01%.
     */
    uint256 public constant TOTAL_SHARE_IN_BPS = 10_000;

    /**
     * @dev The aToken Vault to own, whose revenue is split.
     */
    IATokenVault public immutable VAULT;
    
    /**
     * @dev A struct to represent a recipient and its share of the revenue in basis points.
     * @param addr The address of the recipient.
     * @param shareInBps The recipient's share of the revenue in basis points.
     */
    struct Recipient {
        address addr;
        uint16 shareInBps;
    }

    /**
     * @dev The recipients set for this revenue splitter. Set at construction time only, cannot be modified afterwards.
     */
    Recipient[] internal _recipients;

    /**
     * @dev Total historical amount held for a given asset in this contract.
     */
    mapping(address => uint256) internal _previousAccumulatedBalance;

    /**
     * @dev Amount already transferred for a given asset to a given recipient.
     */
    mapping(address => mapping(address => uint256)) internal _amountAlreadyTransferred;

    /**
     * @dev Constructor.
     * @param vault The address of the aToken Vault to own, whose revenue is split.
     * @param owner The address owning this contract, the effective owner of the vault.
     * @param recipients The recipients to set for the revenue split. Duplicates are not allowed. The recipients
     * configuration cannot be modified afterwards.
     */
    constructor(address vault, address owner, Recipient[] memory recipients) {
        VAULT = IATokenVault(vault);
        require(recipients.length > 0, "MISSING_RECIPIENTS");
        _setRecipients(recipients);
        _transferOwnership(owner);
    }

    /**
     * @dev Rejects native currency transfers.
     */
    receive() external payable {
        revert("NATIVE_CURRENCY_NOT_SUPPORTED");
    }

    /**
     * @dev Transfers the ownership of the aToken vault to a new owner. Claims all fees and rewards prior to transfer,
     * to secure already accrued fees and rewards for the configured split recipients.
     * @dev Only callable by the owner of this contract.
     * @dev DO NOT confuse with `transferOwnership` which transfers the ownership of this contract instead.
     * @param newVaultOwner The address of the new aToken vault owner.
     */
    function transferVaultOwnership(address newVaultOwner) public onlyOwner {
        _claimRewards();
        _withdrawFees();
        Ownable(address(VAULT)).transferOwnership(newVaultOwner);
    }

    /**
     * @dev Withdraws all vault fees to this contract, so they can be split among the configured recipients.
     */
    function withdrawFees() public {
        _withdrawFees();
    }

    /**
     * @dev Claims all vault rewards to this contract, so they can be split among the configured recipients.
     */
    function claimRewards() external {
        _claimRewards();
    }

    /**
     * @dev Splits the revenue from the given assets among the configured recipients. Assets must follow the ERC-20
     * standard and be held by this contract.
     * @param assets The assets to split the revenue from.
     */
    function splitRevenue(address[] calldata assets) public {
        Recipient[] memory recipients = _recipients;
        for (uint256 i = 0; i < assets.length; i++) {
            uint256 assetBalance = IERC20(assets[i]).balanceOf(address(this));
            require(assetBalance > 0, "ASSET_NOT_HELD_BY_SPLITTER");
            // Decrease balance by one unit to ensure aToken transfers will not fail due to scaled balance rounding.
            assetBalance--;
            uint256 accumulatedAssetBalance = _previousAccumulatedBalance[assets[i]] + assetBalance;
            _previousAccumulatedBalance[assets[i]] = accumulatedAssetBalance;
            uint256 undistributedAmount = assetBalance;
            for (uint256 j = 0; j < recipients.length; j++) {
                /**
                 * The `assetBalance` adjustment previously done by decrementing one unit will leave that unit of the
                 * asset undistributed in this contract's balance.
                 * However, due to floor-rounding in integer division, the sum of the amounts transferred may be less
                 * than the intended total amount to split, leaving a few more units of the asset undistributed.
                 * These units (also known as 'dust') may be distributed in the next `splitRevenue` call.
                 */
                uint256 amountForRecipient = accumulatedAssetBalance * recipients[j].shareInBps / TOTAL_SHARE_IN_BPS
                    - _amountAlreadyTransferred[assets[i]][recipients[j].addr];
                if (amountForRecipient > 0) {
                    _amountAlreadyTransferred[assets[i]][recipients[j].addr] += amountForRecipient;
                    IERC20(assets[i]).safeTransfer(recipients[j].addr, amountForRecipient);
                    undistributedAmount -= amountForRecipient;
                }
                emit RevenueSplitTransferred(recipients[j].addr, assets[i], amountForRecipient);
            }
            if (undistributedAmount > 0) {
                _previousAccumulatedBalance[assets[i]] -= undistributedAmount;
            }
        }
    }

    /**
     * @dev Rescues assets that may have accidentally been transferred to the vault.
     * @dev Only callable by the owner of this contract.
     * @dev The asset to rescue cannot be the vault's aToken.
     * @dev Fees cannot be "rescued" as they are accrued in the vault's aToken. Rewards cannot be "rescued" as they are 
     * not held by the vault contract. Thus, already accrued fees and rewards cannot be taken from split recipients.
     * @param asset The asset to rescue from the vault.
     * @param to The address to send the rescued assets to.
     * @param amount The amount of assets to rescue from the vault.
     */
    function emergencyRescue(address asset, address to, uint256 amount) public onlyOwner {
        VAULT.emergencyRescue(asset, to, amount);
    }

    /**
     * @dev Sets the fee for the vault.
     * @dev Only callable by the owner of this contract.
     * @param newFee The new fee for the vault.
     */
    function setFee(uint256 newFee) public onlyOwner {
        VAULT.setFee(newFee);
    }

    /**
     * @dev Getter for the revenue split configured recipients.
     * @return The configured recipients with their corresponding share in basis points.
     */
    function getRecipients() public view returns (Recipient[] memory) {
        return _recipients;
    }

    function _claimRewards() internal {
        VAULT.claimRewards(address(this));
    }

    function _withdrawFees() internal {
        uint256 feesToWithdraw = VAULT.getClaimableFees();
        if (feesToWithdraw > 0) {
            VAULT.withdrawFees(address(this), feesToWithdraw);
        }
    }

    /**
     * @dev Sum of shares must represent 100.00% in basis points.
     */
    function _setRecipients(Recipient[] memory recipients) internal {
        uint256 accumulatedShareInBps = 0;
        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i].addr != address(0), "RECIPIENT_CANNOT_BE_ZERO_ADDRESS");
            require(recipients[i].shareInBps > 0, "BPS_SHARE_CANNOT_BE_ZERO");
            accumulatedShareInBps += recipients[i].shareInBps;
            _recipients.push(recipients[i]);
            emit RecipientSet(recipients[i].addr, recipients[i].shareInBps);
            for (uint256 j = 0; j < i; j++) {
                require(recipients[i].addr != recipients[j].addr, "DUPLICATED_RECIPIENT");
            }
        }
        require(accumulatedShareInBps == TOTAL_SHARE_IN_BPS, "WRONG_BPS_SUM");
    }
}
