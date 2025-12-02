// SPDX-License-Identifier: UNLICENSED
// All Rights Reserved © AaveCo

pragma solidity ^0.8.10;

import {IPoolAddressesProvider} from "@aave-v3-core/interfaces/IPoolAddressesProvider.sol";
import {IERC20} from "@openzeppelin/interfaces/IERC20.sol";

import {ATokenVault} from "./ATokenVault.sol";
import {IATokenVaultMerklRewardClaimer} from "./interfaces/IATokenVaultMerklRewardClaimer.sol";

interface IMerklDistributor {
    function claim(
        address[] calldata users,
        address[] calldata tokens,
        uint256[] calldata amounts,
        bytes32[][] calldata proofs
    ) external;
}

/**
 * @title ATokenVaultMerklRewardClaimer
 * @author Aave Protocol
 * @notice A contract that allows the owner to claim Merkl rewards for the ATokenVault
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
    function getMerklDistributor() external view override returns (address) {
        return _s.merklDistributor;
    }

    /// @inheritdoc IATokenVaultMerklRewardClaimer
    function setMerklDistributor(address merklDistributor) external override onlyOwner {
        require(merklDistributor != address(0), "ZERO_ADDRESS_NOT_VALID");
        address currentMerklDistributor = _s.merklDistributor;
        _s.merklDistributor = merklDistributor;
        emit MerklDistributorUpdated(currentMerklDistributor, merklDistributor);
    }

    /// @inheritdoc IATokenVaultMerklRewardClaimer
    function claimMerklRewards(address[] calldata rewardTokens, uint256[] calldata amounts, bytes32[][] calldata proofs)
        public
        override
        onlyOwner
    {
        require(_s.merklDistributor != address(0), "MERKL_DISTRIBUTOR_NOT_SET");

        address[] memory users = new address[](rewardTokens.length);
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            // users represent depositors into Aave which is this contract
            users[i] = address(this);
        }

        // The claim function does not return a list of tokens and amounts actually received.
        // It is possible for rewards to be in aTokens, the underlying asset or some other token.
        // If necessary the owner can use IATokenVault.emergencyRescue(...) to rescue the non-aToken rewards.
        IMerklDistributor(_s.merklDistributor).claim(users, rewardTokens, amounts, proofs);
        // Do not attempt to accrue yield as it can be delegated to subsequent calls to this contract.
        // We do not need to accrue before claiming because new shares are not granted anywhere (rewards are socialized across all current share holders).
        // We do not need to accrue after claiming because any subsequent call will trigger an accrual before state updates
        // and preview functions read the balance of aTokens on the vault at runtime.

        emit MerklRewardsClaimed(rewardTokens, amounts);
    }
}
