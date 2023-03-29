// SPDX-License-Identifier: UNLICENSED
// All Rights Reserved © AaveCo

pragma solidity ^0.8.10;

uint256 constant AAVE_ACTIVE_MASK = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFF;
uint256 constant AAVE_FROZEN_MASK = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDFFFFFFFFFFFFFF;
uint256 constant AAVE_PAUSED_MASK = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFFF;
uint256 constant AAVE_SUPPLY_CAP_MASK = 0xFFFFFFFFFFFFFFFFFFFFFFFFFF000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
uint256 constant AAVE_SUPPLY_CAP_BIT_POSITION = 116;

bytes4 constant EIP1271_MAGIC_VALUE = 0x1626ba7e;

bytes32 constant DEPOSIT_WITH_SIG_TYPEHASH = keccak256(
    "DepositWithSig(uint256 assets,address receiver,address depositor,uint256 nonce,uint256 deadline)"
);

bytes32 constant DEPOSIT_ATOKENS_WITH_SIG_TYPEHASH = keccak256(
    "DepositATokensWithSig(uint256 assets,address receiver,address depositor,uint256 nonce,uint256 deadline)"
);

bytes32 constant MINT_WITH_SIG_TYPEHASH = keccak256(
    "MintWithSig(uint256 shares,address receiver,address depositor,uint256 nonce,uint256 deadline)"
);

bytes32 constant MINT_WITH_ATOKENS_WITH_SIG_TYPEHASH = keccak256(
    "MintWithATokensWithSig(uint256 shares,address receiver,address depositor,uint256 nonce,uint256 deadline)"
);

bytes32 constant WITHDRAW_WITH_SIG_TYPEHASH = keccak256(
    "WithdrawWithSig(uint256 assets,address receiver,address owner,uint256 nonce,uint256 deadline)"
);

bytes32 constant WITHDRAW_ATOKENS_WITH_SIG_TYPEHASH = keccak256(
    "WithdrawATokensWithSig(uint256 assets,address receiver,address owner,uint256 nonce,uint256 deadline)"
);

bytes32 constant REDEEM_WITH_SIG_TYPEHASH = keccak256(
    "RedeemWithSig(uint256 shares,address receiver,address owner,uint256 nonce,uint256 deadline)"
);

bytes32 constant REDEEM_WITH_ATOKENS_WITH_SIG_TYPEHASH = keccak256(
    "RedeemWithATokensWithSig(uint256 shares,address receiver,address owner,uint256 nonce,uint256 deadline)"
);

uint256 constant SCALE = 1e18;
