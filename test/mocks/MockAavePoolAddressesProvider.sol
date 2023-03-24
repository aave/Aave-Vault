// SPDX-License-Identifier: UNLICENSED
// All rights Reserved © AaveCo
pragma solidity ^0.8.10;

contract MockAavePoolAddressesProvider {
    address public pool;

    constructor(address _pool) {
        pool = _pool;
    }

    function getPool() external view returns (address) {
        return pool;
    }
}
