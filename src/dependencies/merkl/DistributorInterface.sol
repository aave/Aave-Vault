// SPDX-License-Identifier: BUSL-1.1
// Based on implementation from https://github.com/AngleProtocol/merkl-contracts/blob/b7bd0e65a3f366e4041bc83494cbd981f8852b16/contracts/Distributor.sol#L202
pragma solidity ^0.8.10;

interface IMerklDistributor {
    function claim(
        address[] calldata users,
        address[] calldata tokens,
        uint256[] calldata amounts,
        bytes32[][] calldata proofs
    ) external;
}
