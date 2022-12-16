// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "forge-std/Test.sol";

import {ATokenVault, FixedPointMathLib} from "../src/ATokenVault.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

import {DataTypes} from "../src/libraries/DataTypes.sol";
import {Events} from "../src/libraries/Events.sol";

// Inheritting from IATokenVault to access events for tests
contract ATokenVaultBaseTest is Test {
    using FixedPointMathLib for uint256;

    bytes32 constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    // Fork tests using Polygon for Aave v3
    address constant POLYGON_DAI = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
    address constant POLYGON_ADAI = 0x82E64f49Ed5EC1bC6e43DAD4FC8Af9bb3A2312EE;
    address constant POLYGON_AAVE_POOL = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    address constant POLYGON_POOL_ADDRESSES_PROVIDER = 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb;
    address constant POLYGON_REWARDS_CONTROLLER = 0x929EC64c34a17401F460460D4B9390518E5B473e;

    uint256 constant SCALE = 1e18;
    uint256 constant ONE = 1e18;
    uint256 constant TEN = 10e18;
    uint256 constant HUNDRED = 100e18;
    uint256 constant ONE_PERCENT = 0.01e18;
    uint256 constant ONE_BPS = 0.0001e18;

    uint256 constant OWNER_PRIV_KEY = 11111;
    uint256 constant ALICE_PRIV_KEY = 12345;
    uint256 constant BOB_PRIV_KEY = 54321;
    uint256 constant CHAD_PRIV_KEY = 98765;

    address OWNER = vm.addr(OWNER_PRIV_KEY);
    address ALICE = vm.addr(ALICE_PRIV_KEY);
    address BOB = vm.addr(BOB_PRIV_KEY);
    address CHAD = vm.addr(CHAD_PRIV_KEY);

    string constant SHARE_NAME = "Wrapped aDAI";
    string constant SHARE_SYMBOL = "waDAI";

    uint256 fee = 0.2e18; // 20%

    ATokenVault vault;
    address vaultAssetAddress; // aDAI, must be set in every setUp

    // Ownable Errors
    bytes constant ERR_NOT_OWNER = bytes("Ownable: caller is not the owner");

    // Meta Tx Errors
    bytes constant ERR_INVALID_SIGNER = bytes("INVALID_SIGNER");
    bytes constant ERR_PERMIT_DEADLINE_EXPIRED = bytes("PERMIT_DEADLINE_EXPIRED");
    bytes constant ERR_SIG_INVALID = bytes("SIG_INVALID");
    bytes constant ERR_SIG_EXPIRED = bytes("SIG_EXPIRED");

    // Vault Errors
    bytes constant ERR_ZERO_ASSETS = bytes("ZERO_ASSETS");
    bytes constant ERR_ZERO_SHARES = bytes("ZERO_SHARES");
    bytes constant ERR_CANNOT_RESCUE_ATOKEN = bytes("CANNOT_RESCUE_ATOKEN");
    bytes constant ERR_FEE_TOO_HIGH = bytes("FEE_TOO_HIGH");
    bytes constant ERR_ASSET_NOT_SUPPORTED = bytes("ASSET_NOT_SUPPORTED");
    bytes constant ERR_INSUFFICIENT_FEES = bytes("INSUFFICIENT_FEES");
    bytes constant ERR_CANNOT_CLAIM_TO_ZERO_ADDRESS = bytes("CANNOT_CLAIM_TO_ZERO_ADDRESS");

    function setUp() public virtual {}

    // For debug purposes
    function _logVaultBalances(address user, string memory label) internal {
        console.log("\n", label);
        console.log("ERC20 Assets\t\t\t", ERC20(vaultAssetAddress).balanceOf(address(vault)));
        console.log("totalAssets()\t\t\t", vault.totalAssets());
        console.log("lastVaulBalance()\t\t", vault.getLastVaultBalance());
        console.log("User Withdrawable\t\t", vault.maxWithdraw(user));
        console.log("current fees\t\t", vault.getCurrentFees());
        console.log("lastUpdated\t\t\t", vault.getLastUpdated());
        console.log("current time\t\t\t", block.timestamp);
    }
}
