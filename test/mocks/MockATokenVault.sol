// SPDX-License-Identifier: MIT

import {MockDAI} from "./MockDAI.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";

pragma solidity ^0.8.10;

contract MockATokenVault is Ownable {

    address internal _aTokenMock;

    uint256 internal _fees;

    address[] internal _rewardAssets;
    uint256[] internal _rewardAmounts;

    constructor(address aTokenMock, address owner) Ownable() {
        _aTokenMock = aTokenMock;
        _transferOwnership(owner);
    }

    fallback() external payable {}

    receive() external payable {}

    // Mock functions
  
    function mockFees(uint256 amount) external {
        _fees = amount;
        // Ensure the vault has enough aTokens to transfer fees later
        MockDAI(_aTokenMock).mint(address(this), amount); 
    }

    function mockRewards(address[] calldata mockAssets, uint256[] calldata amounts) external {
        require(mockAssets.length == amounts.length, "ARRAY_LENGTH_MISMATCH");
        _rewardAssets = mockAssets;
        _rewardAmounts = amounts;
        for (uint256 i = 0; i < mockAssets.length; i++) {
            // Ensure the vault has enough reward mockAssets to transfer them later
            MockDAI(mockAssets[i]).mint(address(this), amounts[i]);
        }
    }

    // Relevant aToken Vault functions to implement in the mock

    function claimRewards(address to) external onlyOwner {
        for (uint256 i = 0; i < _rewardAssets.length; i++) {
            MockDAI(_rewardAssets[i]).transfer(to, _rewardAmounts[i]);
        }
        _rewardAssets = new address[](0);
        _rewardAmounts = new uint256[](0);
    }

    function withdrawFees(address to, uint256 amount) external onlyOwner {
        _fees -= amount;
        MockDAI(_aTokenMock).transfer(to, amount);
    }

    function getClaimableFees() external view returns (uint256) {
        return _fees;
    }
}
