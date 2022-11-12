// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface IATokenVault {
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event FeeTaken(uint256 shares);
    event FeesWithdrawn(address indexed to, uint256 amount);
    event AavePoolUpdated(address newAavePool);
    event YieldAccrued(uint256 totalNewYield, uint256 newFeesFromYield);

    error FeeTooHigh();
    error InsufficientFees();
    error AssetNotSupported();

    /**
     * @notice A struct containing the necessary information to reconstruct an EIP-712 typed data signature.
     *
     * @param v The signature's recovery parameter.
     * @param r The signature's r parameter.
     * @param s The signature's s parameter
     * @param deadline The signature's deadline
     */
    struct EIP712Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 deadline;
    }
}
