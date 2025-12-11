// SPDX-License-Identifier: UNLICENSED
// All Rights Reserved © AaveCo

pragma solidity ^0.8.10;

import {IPoolAddressesProvider} from "@aave-v3-core/interfaces/IPoolAddressesProvider.sol";
import {IERC20} from "@openzeppelin/interfaces/IERC20.sol";

import {ATokenVault} from "./ATokenVault.sol";
import {IATokenVaultMerklRewardClaimer} from "./interfaces/IATokenVaultMerklRewardClaimer.sol";
import {IMerklDistributor} from "./dependencies/merkl/DistributorInterface.sol";

/**
 * @title ATokenVaultMerklRewardClaimer
 * @author Aave Protocol
 * @notice ATokenVault, with Merkl reward claiming capability
 */
contract ATokenVaultMerklRewardClaimer is ATokenVault, IATokenVaultMerklRewardClaimer {
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
    function claimMerklRewards(address[] calldata rewardTokens, uint256[] calldata amounts, bytes32[][] calldata proofs)
        public
        override
        onlyOwner
    {
        require(_s.merklDistributor != address(0), "MERKL_DISTRIBUTOR_NOT_SET");
        require(rewardTokens.length == amounts.length && rewardTokens.length == proofs.length, "ARRAY_LENGTH_MISMATCH");

        address[] memory users = new address[](rewardTokens.length);
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            users[i] = address(this);
        }
        IMerklDistributor(_s.merklDistributor).claim(users, rewardTokens, amounts, proofs);
        emit MerklRewardsClaimed(_s.merklDistributor, rewardTokens, amounts);
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
