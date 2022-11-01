// // SPDX-License-Identifier: MIT
// pragma solidity 0.8.10;

// import "forge-std/Test.sol";
// import {ERC4626Test} from "./props/ERC4626.t.sol";

// import {ATokenVault} from "../src/ATokenVault.sol";
// import {IAToken} from "aave/interfaces/IAToken.sol";
// import {ERC20} from "solmate/tokens/ERC20.sol";
// import {IPoolAddressesProvider} from "aave/interfaces/IPoolAddressesProvider.sol";

// import {MockAavePoolAddressesProvider} from "./mocks/MockAavePoolAddressesProvider.sol";
// import {MockAToken} from "./mocks/MockAToken.sol";
// import {MockAavePool} from "./mocks/MockAavePool.sol";
// import {MockDAI} from "./mocks/MockDAI.sol";

// contract ATokenVaultPropsTest is ERC4626Test {
//     string constant SHARE_NAME = "Wrapped aDAI";
//     string constant SHARE_SYMBOL = "waDAI";
//     uint256 constant DEFAULT_FEE = 0.2e18; // 20%

//     MockAavePoolAddressesProvider poolAddrProvider;
//     MockAavePool pool;
//     MockAToken aDai;
//     MockDAI dai;

//     ATokenVault vault;

//     function setUp() public override {
//         aDai = new MockAToken();
//         pool = new MockAavePool(aDai);
//         poolAddrProvider = new MockAavePoolAddressesProvider(address(pool));

//         dai = new MockDAI();

//         vault = new ATokenVault(dai, SHARE_NAME, SHARE_SYMBOL, DEFAULT_FEE, IPoolAddressesProvider(address(poolAddrProvider)));

//         __underlying__ = address(dai);
//         __vault__ = address(vault);
//         __delta__ = 0;
//     }
// }
