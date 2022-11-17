pragma solidity 0.8.10;

bytes4 constant EIP1271_MAGIC_VALUE = 0x1626ba7e;

bytes32 constant DEPOSIT_WITH_SIG_TYPEHASH = keccak256(
    "DepositWithSig(uint256 assets,address receiver,address depositor,uint256 nonce,uint256 deadline)"
);

bytes32 constant MINT_WITH_SIG_TYPEHASH = keccak256(
    "MintWithSig(uint256 shares,address receiver,address depositor,uint256 nonce,uint256 deadline)"
);

bytes32 constant WITHDRAW_WITH_SIG_TYPEHASH = keccak256(
    "WithdrawWithSig(uint256 assets,address receiver,address owner,uint256 nonce,uint256 deadline)"
);

bytes32 constant REDEEM_WITH_SIG_TYPEHASH = keccak256(
    "RedeemWithSig(uint256 shares,address receiver,address owner,uint256 nonce,uint256 deadline)"
);
