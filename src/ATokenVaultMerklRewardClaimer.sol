// SPDX-License-Identifier: UNLICENSED
// All Rights Reserved © AaveCo

pragma solidity ^0.8.10;

import {IPoolAddressesProvider} from "@aave-v3-core/interfaces/IPoolAddressesProvider.sol";

import {IERC20Upgradeable} from "@openzeppelin-upgradeable/interfaces/IERC20Upgradeable.sol";
import {SafeERC20Upgradeable} from "@openzeppelin-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import {ATokenVault} from "./ATokenVault.sol";
import {IATokenVaultMerklRewardClaimer} from "./interfaces/IATokenVaultMerklRewardClaimer.sol";
import {IMerklDistributor} from "./dependencies/merkl/DistributorInterface.sol";

/**
 * @title ATokenVaultMerklRewardClaimer
 * @author Aave Protocol
 * @notice ATokenVault, with Merkl reward claiming capability
 */
contract ATokenVaultMerklRewardClaimer is ATokenVault, IATokenVaultMerklRewardClaimer {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /**
     * @dev Constructor.
     * @param underlying The underlying ERC20 asset which can be supplied to Aave
     * @param referralCode The Aave referral code to use for deposits from this vault
     * @param poolAddressesProvider The address of the Aave v3 Pool Addresses Provider
     */
    constructor(address underlying, uint16 referralCode, IPoolAddressesProvider poolAddressesProvider)
        ATokenVault(underlying, referralCode, poolAddressesProvider)
    {}

    /// @inheritdoc IATokenVaultMerklRewardClaimer
    function claimMerklRewards(
        address[] calldata tokens,
        uint256[] calldata amounts,
        bytes32[][] calldata proofs,
        address[] calldata rewardTokensToForward,
        address destination
    )
        public
        override
        onlyOwner
    {
        require(_s.merklDistributor != address(0), "MERKL_DISTRIBUTOR_NOT_SET");
        require(tokens.length == amounts.length && tokens.length == proofs.length, "ARRAY_LENGTH_MISMATCH");

        uint256[] memory currentBalancesOfRewardTokens = new uint256[](rewardTokensToForward.length);
        for (uint256 i = 0; i < rewardTokensToForward.length; i++) {
            currentBalancesOfRewardTokens[i] = IERC20Upgradeable(rewardTokensToForward[i]).balanceOf(address(this));
        }

        address[] memory users = new address[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            users[i] = address(this);
        }
        IMerklDistributor(_s.merklDistributor).claim(users, tokens, amounts, proofs);
        emit MerklRewardsClaimed(_s.merklDistributor, tokens, amounts);

        for (uint256 i = 0; i < rewardTokensToForward.length; i++) {
            uint256 newBalance = IERC20Upgradeable(rewardTokensToForward[i]).balanceOf(address(this));
            uint256 amountToForward = newBalance - currentBalancesOfRewardTokens[i];
            if (amountToForward > 0) {
                IERC20Upgradeable(rewardTokensToForward[i]).safeTransfer(destination, amountToForward);
                emit MerklRewardsTokenForwarded(rewardTokensToForward[i], destination, amountToForward);
            }
        }
    }

    /// @inheritdoc IATokenVaultMerklRewardClaimer
    /// @dev Allow setting address(0) to reset the Merkl distributor
    function setMerklDistributor(address merklDistributor) external override onlyOwner {
        address currentMerklDistributor = _s.merklDistributor;
        _s.merklDistributor = merklDistributor;
        emit MerklDistributorUpdated(currentMerklDistributor, merklDistributor);
    }

    /// @inheritdoc IATokenVaultMerklRewardClaimer
    function getMerklDistributor() external view override returns (address) {
        return _s.merklDistributor;
    }
}
