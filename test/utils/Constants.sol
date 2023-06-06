// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

uint256 constant AAVE_ACTIVE_MASK = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFF;
uint256 constant AAVE_FROZEN_MASK = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDFFFFFFFFFFFFFF;
uint256 constant AAVE_PAUSED_MASK = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFFF;
uint256 constant AAVE_SUPPLY_CAP_MASK = 0xFFFFFFFFFFFFFFFFFFFFFFFFFF000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
uint256 constant AAVE_SUPPLY_CAP_BIT_POSITION = 116;

bytes4 constant EIP1271_MAGIC_VALUE = 0x1626ba7e;

bytes32 constant PERMIT_TYPEHASH = keccak256(
    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
);

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

uint256 constant IS_ACTIVE_START_BIT_POSITION = 56;
uint256 constant IS_FROZEN_START_BIT_POSITION = 57;
uint256 constant IS_PAUSED_START_BIT_POSITION = 60;
uint256 constant SUPPLY_CAP_UNSCALED = 420;
uint256 constant SHORT_SUPPLY_CAP_UNSCALED = 1;
uint256 constant RESERVE_CONFIG_MAP_UNCAPPED_ACTIVE = (0 & AAVE_ACTIVE_MASK) | (1 << IS_ACTIVE_START_BIT_POSITION);
uint256 constant RESERVE_CONFIG_MAP_CAPPED_ACTIVE = (RESERVE_CONFIG_MAP_UNCAPPED_ACTIVE & AAVE_SUPPLY_CAP_MASK) |
    (SUPPLY_CAP_UNSCALED << AAVE_SUPPLY_CAP_BIT_POSITION);
uint256 constant RESERVE_CONFIG_MAP_SHORT_CAPPED_ACTIVE = (RESERVE_CONFIG_MAP_UNCAPPED_ACTIVE & AAVE_SUPPLY_CAP_MASK) |
    (SHORT_SUPPLY_CAP_UNSCALED << AAVE_SUPPLY_CAP_BIT_POSITION);
uint256 constant RESERVE_CONFIG_MAP_INACTIVE = (0 & AAVE_ACTIVE_MASK) | (0 << IS_ACTIVE_START_BIT_POSITION);
uint256 constant RESERVE_CONFIG_MAP_FROZEN = (RESERVE_CONFIG_MAP_UNCAPPED_ACTIVE & AAVE_FROZEN_MASK) |
    (1 << IS_FROZEN_START_BIT_POSITION);
uint256 constant RESERVE_CONFIG_MAP_PAUSED = (RESERVE_CONFIG_MAP_UNCAPPED_ACTIVE & AAVE_PAUSED_MASK) |
    (1 << IS_PAUSED_START_BIT_POSITION);
