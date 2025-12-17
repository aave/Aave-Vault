// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";

import {IMerklDistributor} from "../../src/dependencies/merkl/DistributorInterface.sol";

contract MockMerklDistributor is IMerklDistributor {
    address[] internal _recipients;
    address[] internal _tokens;
    uint256[] internal _amounts;

    bool internal _shouldRevert = false;
    string internal _revertReason = "";

    function claim(
        address[] calldata users,
        address[] calldata tokens,
        uint256[] calldata amounts,
        bytes32[][] calldata proofs
    ) external {
        if (_shouldRevert) {
            revert(_revertReason);
        }
        require(users.length == tokens.length && users.length == amounts.length && users.length == proofs.length, "ARRAY_LENGTH_MISMATCH");
        for (uint256 i = 0; i < _recipients.length; i++) {
            if (_tokens[i] == address(0)) {
                payable(_recipients[i]).transfer(_amounts[i]);
            } else {
                ERC20(_tokens[i]).transfer(_recipients[i], _amounts[i]);
            }
        }
    }

    function mockTokensToSend(
        address[] memory recipients,
        address[] memory tokens,
        uint256[] memory amounts
    ) external {
        _recipients = recipients;
        _tokens = tokens;
        _amounts = amounts;
    }

    function setShouldRevert(bool shouldRevert, string memory revertReason) external {
        _shouldRevert = shouldRevert;
        _revertReason = revertReason;
    }
}
