// SPDX-License-Identifier: UNLICENSED
// All Rights Reserved © AaveCo

pragma solidity ^0.8.10;

/**
 * @title IATokenVaultMerklRewardClaimer
 * @author Aave Protocol
 *
 * @notice Defines the basic interface of the ATokenVaultMerklRewardClaimer
 */
interface IATokenVaultMerklRewardClaimer {
    /**
     * @dev Emitted when Merkl rewards are claimed by the vault contract
     * @dev The token addresses do not always match the actual tokens received by the vault contract after rewards are claimed
     * @dev The amounts do not always match the actual amounts received (the amounts may be the cumulative rewards earned by the user)
     * @param distributor Address of the Merkl distributor contract
     * @param tokens Addresses of the ERC-20 reward tokens claimed (the tokens passed as params to the Merkl distributor contract)
     * @param amounts Amounts of the reward tokens claimed for each token (the amounts passed as params to the Merkl distributor contract)
     */
    event MerklRewardsClaimed(address indexed distributor, address[] tokens, uint256[] amounts);

    /**
     * @dev Emitted when a reward token is forwarded to a destination
     * @param token Address of the ERC-20 reward token
     * @param destination Address of the destination receiving the reward token
     * @param amount Amount of the reward token transferred to the destination
     */
    event MerklRewardsTokenForwarded(address indexed token, address indexed destination, uint256 indexed amount);

    /**
     * @dev Emitted when the Merkl distributor address is updated
     * @param oldMerklDistributor The old address of the Merkl distributor contract
     * @param newMerklDistributor The new address of the Merkl distributor contract
     */
    event MerklDistributorUpdated(address indexed oldMerklDistributor, address indexed newMerklDistributor);

    /**
     * @notice Claims Merkl protocol rewards accrued from vault deposits.
     * @dev Only callable by the owner
     * @dev Merkl distributor address must be set
     * @dev The IMerklDistributor.claim(...) function does not return a list of tokens and amounts the users actually receive
     * @dev The order of the tokens, amounts, and proofs must align with eachother
     * @param tokens Addresses of the ERC-20 reward tokens to claim (the tokens passed as params to the Merkl distributor contract)
     * @param amounts Amounts of the reward tokens to claim for each token
     * @param proofs Merkl proof passed to the Merkl distributor contract
     * @param rewardTokensToForward Addresses of the ERC-20 tokens received by the vault contract from reward claiming (to be set if rewards should be forwarded to the `destination`)
     * @param destination Address to send the received tokens to
     */
    function claimMerklRewards(
        address[] calldata tokens,
        uint256[] calldata amounts,
        bytes32[][] calldata proofs,
        address[] calldata rewardTokensToForward,
        address destination
    ) external;

    /**
     * @notice Sets the Merkl distributor address for the vault uses to claim Merkl rewards.
     * @dev Only callable by the owner
     * @param merklDistributor Address of the new Merkl distributor contract
     */
    function setMerklDistributor(address merklDistributor) external;

    /**
     * @notice Returns the address of the Merkl distributor contract.
     * @return The address of the Merkl distributor contract
     */
    function getMerklDistributor() external view returns (address);
}
