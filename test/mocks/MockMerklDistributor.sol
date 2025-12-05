// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

contract MockMerklDistributor {
    bool public claimCalled = false;
    address[] public lastUsers;
    address[] public lastTokens;
    uint256[] public lastAmounts;
    bytes32[][] public lastProofs;
    bool public shouldRevert = false;
    string public revertReason = "";

    function claim(
        address[] calldata users,
        address[] calldata tokens,
        uint256[] calldata amounts,
        bytes32[][] calldata proofs
    ) external {
        if (shouldRevert) {
            revert(revertReason);
        }

        claimCalled = true;

        // Store the call data to be checked in the test
        delete lastUsers;
        delete lastTokens;
        delete lastAmounts;
        delete lastProofs;
        for (uint256 i = 0; i < users.length; i++) {
            lastUsers.push(users[i]);
        }
        for (uint256 i = 0; i < tokens.length; i++) {
            lastTokens.push(tokens[i]);
        }
        for (uint256 i = 0; i < amounts.length; i++) {
            lastAmounts.push(amounts[i]);
        }
        for (uint256 i = 0; i < proofs.length; i++) {
            lastProofs.push(proofs[i]);
        }
    }

    function setShouldRevert(bool _shouldRevert, string memory _reason) external {
        shouldRevert = _shouldRevert;
        revertReason = _reason;
    }

    function getLastUsers() external view returns (address[] memory) {
        return lastUsers;
    }

    function getLastTokens() external view returns (address[] memory) {
        return lastTokens;
    }

    function getLastAmounts() external view returns (uint256[] memory) {
        return lastAmounts;
    }

    function getLastProofs() external view returns (bytes32[][] memory) {
        return lastProofs;
    }
}
