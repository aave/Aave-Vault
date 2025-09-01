// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import {MockAavePoolAddressesProvider} from "./mocks/MockAavePoolAddressesProvider.sol";
import {MockAToken} from "./mocks/MockAToken.sol";
import {MockAavePool} from "./mocks/MockAavePool.sol";
import {MockDAI} from "./mocks/MockDAI.sol";
import "./utils/Constants.sol";
import {IPoolAddressesProvider} from "@aave-v3-core/interfaces/IPoolAddressesProvider.sol";

import {ATokenVault} from "../src/ATokenVault.sol";
import {ATokenVaultFactory} from "../src/ATokenVaultFactory.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";

import {ProxyAdmin as ProxyAdmin_v4_7} from "@openzeppelin/proxy/transparent/ProxyAdmin.sol";

contract ATokenVaultFactoryTest is Test {
    using SafeERC20 for IERC20;

    ATokenVaultFactory factory;
    MockAavePoolAddressesProvider poolAddrProvider;
    MockAavePool pool;
    MockAToken aToken;
    address underlying;

    address proxyAdmin;

    address constant ALICE = address(0x1);
    address constant BOB = address(0x2);
    address constant CHARLIE = address(0x3);

    event VaultDeployed(
        address indexed vault,
        address indexed implementation,
        address indexed underlying,
        address deployer,
        address owner,
        uint16 referralCode,
        address poolAddressesProvider
    );

    function setUp() public {
        underlying = _deployUnderlying();
        aToken = new MockAToken(address(underlying));
        pool = new MockAavePool();
        pool.mockReserve(address(underlying), aToken);
        proxyAdmin = address(new ProxyAdmin_v4_7());
        ProxyAdmin_v4_7(proxyAdmin).renounceOwnership();
        poolAddrProvider = new MockAavePoolAddressesProvider(address(pool));
        factory = new ATokenVaultFactory(proxyAdmin);

        pool.setReserveConfigMap(RESERVE_CONFIG_MAP_UNCAPPED_ACTIVE);
    }

    function _deployUnderlying() internal virtual returns (address) {
        return address(new MockDAI());
    }

    /*//////////////////////////////////////////////////////////////
                            DEPLOYMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function testDeployVault() public {
        uint256 initialDeposit = 1000 * 1e18;
        deal(address(underlying), ALICE, initialDeposit);

        vm.startPrank(ALICE);
        IERC20(underlying).safeApprove(address(factory), initialDeposit);

        ATokenVaultFactory.VaultParams memory params = ATokenVaultFactory.VaultParams({
            underlying: address(underlying),
            referralCode: 42,
            poolAddressesProvider: IPoolAddressesProvider(address(poolAddrProvider)),
            owner: ALICE,
            initialFee: 0,
            shareName: "Test Vault",
            shareSymbol: "tVault",
            initialLockDeposit: initialDeposit
        });

        address vault = factory.deployVault(params);
        vm.stopPrank();

        assertTrue(vault != address(0));

        ATokenVault vaultContract = ATokenVault(vault);
        assertEq(address(vaultContract.UNDERLYING()), address(underlying));
        assertEq(vaultContract.REFERRAL_CODE(), 42);
        assertEq(vaultContract.owner(), ALICE);
        assertEq(vaultContract.name(), "Test Vault");
        assertEq(vaultContract.symbol(), "tVault");
        assertEq(vaultContract.getFee(), 0);
    }

    function testDeployVaultWithFee() public {
        uint256 initialDeposit = 1000 * 1e18;
        uint256 fee = 1e17; // 10%
        deal(address(underlying), ALICE, initialDeposit);

        vm.startPrank(ALICE);
        IERC20(underlying).safeApprove(address(factory), initialDeposit);

        ATokenVaultFactory.VaultParams memory params = ATokenVaultFactory.VaultParams({
            underlying: address(underlying),
            referralCode: 123,
            poolAddressesProvider: IPoolAddressesProvider(address(poolAddrProvider)),
            owner: ALICE,
            initialFee: fee,
            shareName: "Fee Vault",
            shareSymbol: "fVault",
            initialLockDeposit: initialDeposit
        });

        address vault = factory.deployVault(params);
        vm.stopPrank();

        assertTrue(vault != address(0));
        ATokenVault vaultContract = ATokenVault(vault);
        assertEq(vaultContract.REFERRAL_CODE(), 123);
        assertEq(address(vaultContract.UNDERLYING()), address(underlying));
        assertEq(vaultContract.getFee(), fee);
        assertEq(vaultContract.name(), "Fee Vault");
        assertEq(vaultContract.symbol(), "fVault");
    }

    function testDeployMultipleVaults() public {
        uint256 initialDeposit = 1000 * 1e18;

        deal(address(underlying), ALICE, initialDeposit);
        vm.startPrank(ALICE);
        IERC20(underlying).safeApprove(address(factory), initialDeposit);

        ATokenVaultFactory.VaultParams memory params1 = ATokenVaultFactory.VaultParams({
            underlying: address(underlying),
            referralCode: 0,
            poolAddressesProvider: IPoolAddressesProvider(address(poolAddrProvider)),
            owner: ALICE,
            initialFee: 0,
            shareName: "Vault 1",
            shareSymbol: "V1",
            initialLockDeposit: initialDeposit
        });

        address vault1 = factory.deployVault(params1);
        vm.stopPrank();

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);

        deal(address(underlying), BOB, initialDeposit);
        vm.startPrank(BOB);
        IERC20(underlying).safeApprove(address(factory), initialDeposit);

        ATokenVaultFactory.VaultParams memory params2 = ATokenVaultFactory.VaultParams({
            underlying: address(underlying),
            referralCode: 0,
            poolAddressesProvider: IPoolAddressesProvider(address(poolAddrProvider)),
            owner: BOB,
            initialFee: 0,
            shareName: "Vault 2",
            shareSymbol: "V2",
            initialLockDeposit: initialDeposit
        });

        address vault2 = factory.deployVault(params2);
        vm.stopPrank();

        assertTrue(vault1 != vault2);

        ATokenVault vault1Contract = ATokenVault(vault1);
        ATokenVault vault2Contract = ATokenVault(vault2);
        assertEq(vault1Contract.owner(), ALICE);
        assertEq(vault2Contract.owner(), BOB);
    }

    function testDeployVaultEmitsEvent() public {
        uint256 initialDeposit = 1000 * 1e18;
        deal(address(underlying), ALICE, initialDeposit);

        vm.startPrank(ALICE);
        IERC20(underlying).safeApprove(address(factory), initialDeposit);

        ATokenVaultFactory.VaultParams memory params = ATokenVaultFactory.VaultParams({
            underlying: address(underlying),
            referralCode: 42,
            poolAddressesProvider: IPoolAddressesProvider(address(poolAddrProvider)),
            owner: ALICE,
            initialFee: 0,
            shareName: "Test Vault",
            shareSymbol: "tVault",
            initialLockDeposit: initialDeposit
        });

        vm.recordLogs();
        address vault = factory.deployVault(params);
        vm.stopPrank();

        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Find the VaultDeployed event (should be the last one)
        bool eventFound = false;
        for (uint i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256("VaultDeployed(address,address,address,address,(address,uint16,address,address,uint256,string,string,uint256))")) {
                eventFound = true;

                // Decode the event data
                address eventVault = address(uint160(uint256(logs[i].topics[1])));
                address eventImplementation = address(uint160(uint256(logs[i].topics[2])));
                address eventUnderlying = address(uint160(uint256(logs[i].topics[3])));

                (address eventDeployer, ATokenVaultFactory.VaultParams memory eventVaultParams) = abi.decode(
                    logs[i].data,
                    (address, ATokenVaultFactory.VaultParams)
                );

                // Verify event data
                assertEq(eventVault, vault);
                assertTrue(eventImplementation != address(0));
                assertEq(eventUnderlying, address(underlying));
                assertEq(eventDeployer, ALICE);
                assertEq(eventVaultParams.underlying, address(underlying));
                assertEq(eventVaultParams.referralCode, 42);
                assertEq(address(eventVaultParams.poolAddressesProvider), address(poolAddrProvider));
                assertEq(eventVaultParams.owner, ALICE);
                assertEq(eventVaultParams.initialFee, 0);
                assertEq(eventVaultParams.shareName, "Test Vault");
                assertEq(eventVaultParams.shareSymbol, "tVault");
                assertEq(eventVaultParams.initialLockDeposit, initialDeposit);
                break;
            }
        }

        assertTrue(eventFound, "VaultDeployed event not found");
    }

    function testDeployVaultWithMaxReferralCode() public {
        uint256 initialDeposit = 1000 * 1e18;
        uint16 maxReferralCode = type(uint16).max;
        deal(address(underlying), ALICE, initialDeposit);

        vm.startPrank(ALICE);
        IERC20(underlying).safeApprove(address(factory), initialDeposit);

        ATokenVaultFactory.VaultParams memory params = ATokenVaultFactory.VaultParams({
            underlying: address(underlying),
            referralCode: maxReferralCode,
            poolAddressesProvider: IPoolAddressesProvider(address(poolAddrProvider)),
            owner: ALICE,
            initialFee: 0,
            shareName: "Max Referral Vault",
            shareSymbol: "MRV",
            initialLockDeposit: initialDeposit
        });

        address vault = factory.deployVault(params);
        vm.stopPrank();

        ATokenVault vaultContract = ATokenVault(vault);
        assertEq(vaultContract.REFERRAL_CODE(), maxReferralCode);
    }

    function testDeployVaultWithMaxFee() public {
        uint256 initialDeposit = 1000 * 1e18;
        uint256 maxFee = 1e18; // 100%
        deal(address(underlying), ALICE, initialDeposit);

        vm.startPrank(ALICE);
        IERC20(underlying).safeApprove(address(factory), initialDeposit);

        ATokenVaultFactory.VaultParams memory params = ATokenVaultFactory.VaultParams({
            underlying: address(underlying),
            referralCode: 0,
            poolAddressesProvider: IPoolAddressesProvider(address(poolAddrProvider)),
            owner: ALICE,
            initialFee: maxFee,
            shareName: "Max Fee Vault",
            shareSymbol: "MFV",
            initialLockDeposit: initialDeposit
        });

        address vault = factory.deployVault(params);
        vm.stopPrank();

        ATokenVault vaultContract = ATokenVault(vault);
        assertEq(vaultContract.getFee(), maxFee);
    }

    function testDeployVaultWithDifferentOwner() public {
        uint256 initialDeposit = 1000 * 1e18;
        deal(address(underlying), ALICE, initialDeposit);

        vm.startPrank(ALICE);
        IERC20(underlying).safeApprove(address(factory), initialDeposit);

        ATokenVaultFactory.VaultParams memory params = ATokenVaultFactory.VaultParams({
            underlying: address(underlying),
            referralCode: 0,
            poolAddressesProvider: IPoolAddressesProvider(address(poolAddrProvider)),
            owner: BOB, // Different owner than deployer
            initialFee: 0,
            shareName: "Different Owner Vault",
            shareSymbol: "DOV",
            initialLockDeposit: initialDeposit
        });

        address vault = factory.deployVault(params);
        vm.stopPrank();

        ATokenVault vaultContract = ATokenVault(vault);
        assertEq(vaultContract.owner(), BOB);
    }

    /*//////////////////////////////////////////////////////////////
                            VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testDeployVaultZeroUnderlyingReverts() public {
        uint256 initialDeposit = 1000 * 1e18;

        ATokenVaultFactory.VaultParams memory params = ATokenVaultFactory.VaultParams({
            underlying: address(0),
            referralCode: 0,
            poolAddressesProvider: IPoolAddressesProvider(address(poolAddrProvider)),
            owner: ALICE,
            initialFee: 0,
            shareName: "Test",
            shareSymbol: "TEST",
            initialLockDeposit: initialDeposit
        });

        vm.expectRevert("ZERO_ADDRESS_NOT_VALID");
        factory.deployVault(params);
    }

    function testDeployVaultZeroOwnerReverts() public {
        uint256 initialDeposit = 1000 * 1e18;

        ATokenVaultFactory.VaultParams memory params = ATokenVaultFactory.VaultParams({
            underlying: address(underlying),
            referralCode: 0,
            poolAddressesProvider: IPoolAddressesProvider(address(poolAddrProvider)),
            owner: address(0),
            initialFee: 0,
            shareName: "Test",
            shareSymbol: "TEST",
            initialLockDeposit: initialDeposit
        });

        vm.expectRevert("ZERO_ADDRESS_NOT_VALID");
        factory.deployVault(params);
    }

    function testDeployVaultZeroDepositReverts() public {
        ATokenVaultFactory.VaultParams memory params = ATokenVaultFactory.VaultParams({
            underlying: address(underlying),
            referralCode: 0,
            poolAddressesProvider: IPoolAddressesProvider(address(poolAddrProvider)),
            owner: ALICE,
            initialFee: 0,
            shareName: "Test",
            shareSymbol: "TEST",
            initialLockDeposit: 0
        });

        vm.expectRevert("ZERO_INITIAL_LOCK_DEPOSIT");
        factory.deployVault(params);
    }

    function testDeployVaultEmptyNameReverts() public {
        uint256 initialDeposit = 1000 * 1e18;

        ATokenVaultFactory.VaultParams memory params = ATokenVaultFactory.VaultParams({
            underlying: address(underlying),
            referralCode: 0,
            poolAddressesProvider: IPoolAddressesProvider(address(poolAddrProvider)),
            owner: ALICE,
            initialFee: 0,
            shareName: "",
            shareSymbol: "TEST",
            initialLockDeposit: initialDeposit
        });

        vm.expectRevert("EMPTY_SHARE_NAME");
        factory.deployVault(params);
    }

    function testDeployVaultEmptySymbolReverts() public {
        uint256 initialDeposit = 1000 * 1e18;

        ATokenVaultFactory.VaultParams memory params = ATokenVaultFactory.VaultParams({
            underlying: address(underlying),
            referralCode: 0,
            poolAddressesProvider: IPoolAddressesProvider(address(poolAddrProvider)),
            owner: ALICE,
            initialFee: 0,
            shareName: "Test",
            shareSymbol: "",
            initialLockDeposit: initialDeposit
        });

        vm.expectRevert("EMPTY_SHARE_SYMBOL");
        factory.deployVault(params);
    }

    function testDeployVaultZeroPoolProviderReverts() public {
        uint256 initialDeposit = 1000 * 1e18;

        ATokenVaultFactory.VaultParams memory params = ATokenVaultFactory.VaultParams({
            underlying: address(underlying),
            referralCode: 0,
            poolAddressesProvider: IPoolAddressesProvider(address(0)),
            owner: ALICE,
            initialFee: 0,
            shareName: "Test",
            shareSymbol: "TEST",
            initialLockDeposit: initialDeposit
        });

        vm.expectRevert("ZERO_ADDRESS_NOT_VALID");
        factory.deployVault(params);
    }

    function testDeployVaultInsufficientAllowanceReverts() public {
        uint256 initialDeposit = 1000 * 1e18;
        deal(address(underlying), ALICE, initialDeposit);

        vm.startPrank(ALICE);
        IERC20(underlying).safeApprove(address(factory), initialDeposit - 1); // Insufficient approval

        ATokenVaultFactory.VaultParams memory params = ATokenVaultFactory.VaultParams({
            underlying: address(underlying),
            referralCode: 0,
            poolAddressesProvider: IPoolAddressesProvider(address(poolAddrProvider)),
            owner: ALICE,
            initialFee: 0,
            shareName: "Test",
            shareSymbol: "TEST",
            initialLockDeposit: initialDeposit
        });

        vm.expectRevert("ERC20: insufficient allowance");
        factory.deployVault(params);
        vm.stopPrank();
    }

    function testDeployVaultInsufficientBalanceReverts() public {
        uint256 initialDeposit = 1000 * 1e18;
        deal(address(underlying), ALICE, initialDeposit - 1); // Insufficient balance

        vm.startPrank(ALICE);
        IERC20(underlying).safeApprove(address(factory), initialDeposit);

        ATokenVaultFactory.VaultParams memory params = ATokenVaultFactory.VaultParams({
            underlying: address(underlying),
            referralCode: 0,
            poolAddressesProvider: IPoolAddressesProvider(address(poolAddrProvider)),
            owner: ALICE,
            initialFee: 0,
            shareName: "Test",
            shareSymbol: "TEST",
            initialLockDeposit: initialDeposit
        });

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        factory.deployVault(params);
        vm.stopPrank();
    }

    function testDeployVaultExceedingMaxFeeReverts(uint256 initialDeposit, uint256 initFee) public {
        initialDeposit = _boundInitialDeposit(initialDeposit);
        initFee = bound(initFee, 1e18 + 1, type(uint256).max);

        deal(address(underlying), ALICE, initialDeposit);

        vm.startPrank(ALICE);
        IERC20(underlying).safeApprove(address(factory), initialDeposit);

        ATokenVaultFactory.VaultParams memory params = ATokenVaultFactory.VaultParams({
            underlying: address(underlying),
            referralCode: 0,
            poolAddressesProvider: IPoolAddressesProvider(address(poolAddrProvider)),
            owner: ALICE,
            initialFee: initFee,
            shareName: "Max Fee Vault",
            shareSymbol: "MFV",
            initialLockDeposit: initialDeposit
        });

        vm.expectRevert("FEE_TOO_HIGH");
        factory.deployVault(params);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function testConstructorZeroProxyAdminReverts() public {
        vm.expectRevert();
        new ATokenVaultFactory(address(0));
    }

    function testConstructorNonRenouncedProxyAdminReverts(address deployer) public {
        vm.assume(deployer != address(0));

        vm.prank(deployer);
        ProxyAdmin_v4_7 nonRenouncedProxyAdmin = new ProxyAdmin_v4_7();

        assertEq(nonRenouncedProxyAdmin.owner(), deployer);

        vm.expectRevert();
        new ATokenVaultFactory(address(nonRenouncedProxyAdmin));
    }

    function testConstructorSetsProxyAdmin() public {
        proxyAdmin = address(new ProxyAdmin_v4_7());

        ProxyAdmin_v4_7(proxyAdmin).renounceOwnership();
            
        ATokenVaultFactory newFactory = new ATokenVaultFactory(proxyAdmin);

        uint256 initialDeposit = 1000 * 1e18;
        MockDAI(underlying).mint(address(this), initialDeposit);

        IERC20(underlying).safeApprove(address(newFactory), initialDeposit);

        ATokenVaultFactory.VaultParams memory params = ATokenVaultFactory.VaultParams({
            underlying: address(underlying),
            referralCode: 0,
            poolAddressesProvider: IPoolAddressesProvider(address(poolAddrProvider)),
            owner: address(this),
            initialFee: 0,
            shareName: "Test Vault",
            shareSymbol: "tVault",
            initialLockDeposit: initialDeposit
        });

        address vault = newFactory.deployVault(params);

        bytes32 value = vm.load(
            vault,
            0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103 // Transparent proxy's admin slot
        );

        assertEq(value, bytes32(uint256(uint160(proxyAdmin))));
    }

    /*//////////////////////////////////////////////////////////////
                            INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testVaultBasicProperties() public {
        uint256 initialDeposit = 1000 * 1e18;
        deal(address(underlying), ALICE, initialDeposit);

        vm.startPrank(ALICE);
        IERC20(underlying).safeApprove(address(factory), initialDeposit);

        ATokenVaultFactory.VaultParams memory params = ATokenVaultFactory.VaultParams({
            underlying: address(underlying),
            referralCode: 0,
            poolAddressesProvider: IPoolAddressesProvider(address(poolAddrProvider)),
            owner: ALICE,
            initialFee: 0,
            shareName: "Test Vault",
            shareSymbol: "tVault",
            initialLockDeposit: initialDeposit
        });

        address vault = factory.deployVault(params);
        vm.stopPrank();

        ATokenVault vaultContract = ATokenVault(vault);

        assertEq(address(vaultContract.UNDERLYING()), address(underlying));
        assertEq(address(vaultContract.AAVE_POOL()), address(pool));
        assertEq(address(vaultContract.POOL_ADDRESSES_PROVIDER()), address(poolAddrProvider));
        assertEq(vaultContract.REFERRAL_CODE(), 0);
        assertEq(vaultContract.owner(), ALICE);
        assertEq(vaultContract.name(), "Test Vault");
        assertEq(vaultContract.symbol(), "tVault");
    }

    function testDeployDifferentUnderlyingAssets() public {
        uint256 initialDeposit = 1000 * 1e18;

        MockDAI usdc = new MockDAI();
        MockAToken aUsdc = new MockAToken(address(usdc));
        MockAavePool usdcPool = new MockAavePool();
        usdcPool.mockReserve(address(usdc), aUsdc);
        MockAavePoolAddressesProvider usdcPoolProvider = new MockAavePoolAddressesProvider(address(usdcPool));

        usdcPool.setReserveConfigMap(RESERVE_CONFIG_MAP_UNCAPPED_ACTIVE);

        deal(address(underlying), ALICE, initialDeposit);
        deal(address(usdc), ALICE, initialDeposit);

        vm.startPrank(ALICE);
        IERC20(underlying).safeApprove(address(factory), initialDeposit);
        IERC20(usdc).safeApprove(address(factory), initialDeposit);

        ATokenVaultFactory.VaultParams memory underlyingParams = ATokenVaultFactory.VaultParams({
            underlying: address(underlying),
            referralCode: 0,
            poolAddressesProvider: IPoolAddressesProvider(address(poolAddrProvider)),
            owner: ALICE,
            initialFee: 0,
            shareName: "underlying Vault",
            shareSymbol: "dVault",
            initialLockDeposit: initialDeposit
        });

        address underlyingVault = factory.deployVault(underlyingParams);

        ATokenVaultFactory.VaultParams memory usdcParams = ATokenVaultFactory.VaultParams({
            underlying: address(usdc),
            referralCode: 0,
            poolAddressesProvider: IPoolAddressesProvider(address(usdcPoolProvider)),
            owner: ALICE,
            initialFee: 0,
            shareName: "USDC Vault",
            shareSymbol: "uVault",
            initialLockDeposit: initialDeposit
        });

        address usdcVault = factory.deployVault(usdcParams);

        vm.stopPrank();

        assertTrue(underlyingVault != usdcVault);
    }

    function testDeploymentCounterIncreases() public {
        uint256 initialDeposit = 1000 * 1e18;
        deal(address(underlying), ALICE, initialDeposit * 3);

        vm.startPrank(ALICE);
        IERC20(underlying).safeApprove(address(factory), initialDeposit * 3);

        ATokenVaultFactory.VaultParams memory params = ATokenVaultFactory.VaultParams({
            underlying: address(underlying),
            referralCode: 0,
            poolAddressesProvider: IPoolAddressesProvider(address(poolAddrProvider)),
            owner: ALICE,
            initialFee: 0,
            shareName: "Test Vault",
            shareSymbol: "TV",
            initialLockDeposit: initialDeposit
        });

        address vault1 = factory.deployVault(params);

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);

        address vault2 = factory.deployVault(params);

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);

        address vault3 = factory.deployVault(params);

        vm.stopPrank();

        assertTrue(vault1 != vault2);
        assertTrue(vault2 != vault3);
        assertTrue(vault1 != vault3);
    }

    function testDeployVaultEdgeCaseMinimalDeposit() public {
        uint256 minDeposit = 1;
        deal(address(underlying), ALICE, minDeposit);

        vm.startPrank(ALICE);
        IERC20(underlying).safeApprove(address(factory), minDeposit);

        ATokenVaultFactory.VaultParams memory params = ATokenVaultFactory.VaultParams({
            underlying: address(underlying),
            referralCode: 0,
            poolAddressesProvider: IPoolAddressesProvider(address(poolAddrProvider)),
            owner: ALICE,
            initialFee: 0,
            shareName: "Minimal Deposit Vault",
            shareSymbol: "MDV",
            initialLockDeposit: minDeposit
        });

        address vault = factory.deployVault(params);
        vm.stopPrank();

        assertTrue(vault != address(0));
    }

    function testDeployVaultEdgeCaseZeroFee() public {
        uint256 initialDeposit = 1000 * 1e18;
        deal(address(underlying), ALICE, initialDeposit);

        vm.startPrank(ALICE);
        IERC20(underlying).safeApprove(address(factory), initialDeposit);

        ATokenVaultFactory.VaultParams memory params = ATokenVaultFactory.VaultParams({
            underlying: address(underlying),
            referralCode: 0,
            poolAddressesProvider: IPoolAddressesProvider(address(poolAddrProvider)),
            owner: ALICE,
            initialFee: 0,
            shareName: "Zero Fee Vault",
            shareSymbol: "ZFV",
            initialLockDeposit: initialDeposit
        });

        address vault = factory.deployVault(params);
        vm.stopPrank();

        ATokenVault vaultContract = ATokenVault(vault);
        assertEq(vaultContract.getFee(), 0);
    }

    function testDeployVaultEdgeCaseMaxFee() public {
        uint256 initialDeposit = 1000 * 1e18;
        deal(address(underlying), ALICE, initialDeposit);

        vm.startPrank(ALICE);
        IERC20(underlying).safeApprove(address(factory), initialDeposit);

        ATokenVaultFactory.VaultParams memory params = ATokenVaultFactory.VaultParams({
            underlying: address(underlying),
            referralCode: 0,
            poolAddressesProvider: IPoolAddressesProvider(address(poolAddrProvider)),
            owner: ALICE,
            initialFee: 1e18,
            shareName: "Max Fee Vault",
            shareSymbol: "MFV",
            initialLockDeposit: initialDeposit
        });

        address vault = factory.deployVault(params);
        vm.stopPrank();

        ATokenVault vaultContract = ATokenVault(vault);
        assertEq(vaultContract.getFee(), 1e18);
    }

    /*//////////////////////////////////////////////////////////////
                            FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzzDeployVaultWithValidParams(
        uint16 referralCode,
        uint256 initialFee,
        uint256 initialDeposit
    ) public {
        initialDeposit = _boundInitialDeposit(initialDeposit);
        initialFee = _boundInitialFee(initialFee);

        deal(address(underlying), ALICE, initialDeposit);

        vm.startPrank(ALICE);
        IERC20(underlying).safeApprove(address(factory), initialDeposit);

        ATokenVaultFactory.VaultParams memory params = ATokenVaultFactory.VaultParams({
            underlying: address(underlying),
            referralCode: referralCode,
            poolAddressesProvider: IPoolAddressesProvider(address(poolAddrProvider)),
            owner: ALICE,
            initialFee: initialFee,
            shareName: "Fuzz Vault",
            shareSymbol: "FV",
            initialLockDeposit: initialDeposit
        });

        address vault = factory.deployVault(params);
        vm.stopPrank();

        assertTrue(vault != address(0));

        ATokenVault vaultContract = ATokenVault(vault);
        assertEq(vaultContract.REFERRAL_CODE(), referralCode);
        assertEq(vaultContract.getFee(), initialFee);
    }

    function testFuzzDeployVaultEdgeCases(
        uint16 referralCode,
        uint256 initialFee
    ) public {
        uint256 minDeposit = 1;
        initialFee = _boundInitialFee(initialFee);

        deal(address(underlying), ALICE, minDeposit);

        vm.startPrank(ALICE);
        IERC20(underlying).safeApprove(address(factory), minDeposit);

        ATokenVaultFactory.VaultParams memory params = ATokenVaultFactory.VaultParams({
            underlying: address(underlying),
            referralCode: referralCode,
            poolAddressesProvider: IPoolAddressesProvider(address(poolAddrProvider)),
            owner: ALICE,
            initialFee: initialFee,
            shareName: "Fuzz Edge Case Vault",
            shareSymbol: "FECV",
            initialLockDeposit: minDeposit
        });

        address vault = factory.deployVault(params);
        vm.stopPrank();

        assertTrue(vault != address(0));

        ATokenVault vaultContract = ATokenVault(vault);
        assertEq(vaultContract.REFERRAL_CODE(), referralCode);
        assertEq(vaultContract.getFee(), initialFee);
    }

    function testFuzzDeployVaultBoundaryFees(
        uint16 referralCode,
        uint256 initialDeposit
    ) public {
        initialDeposit = _boundInitialDeposit(initialDeposit);

        deal(address(underlying), ALICE, initialDeposit);

        vm.startPrank(ALICE);
        IERC20(underlying).safeApprove(address(factory), initialDeposit);

        ATokenVaultFactory.VaultParams memory params = ATokenVaultFactory.VaultParams({
            underlying: address(underlying),
            referralCode: referralCode,
            poolAddressesProvider: IPoolAddressesProvider(address(poolAddrProvider)),
            owner: ALICE,
            initialFee: 0,
            shareName: "Zero Fee Fuzz Vault",
            shareSymbol: "ZFFV",
            initialLockDeposit: initialDeposit
        });

        address vault1 = factory.deployVault(params);
        vm.stopPrank();

        ATokenVault vaultContract1 = ATokenVault(vault1);
        assertEq(vaultContract1.getFee(), 0);

        deal(address(underlying), BOB, initialDeposit);
        vm.startPrank(BOB);
        IERC20(underlying).safeApprove(address(factory), initialDeposit);

        params.owner = BOB;
        params.initialFee = 1e18;
        params.shareName = "Max Fee Fuzz Vault";
        params.shareSymbol = "MFFV";

        address vault2 = factory.deployVault(params);
        vm.stopPrank();

        ATokenVault vaultContract2 = ATokenVault(vault2);
        assertEq(vaultContract2.getFee(), 1e18);
    }

    function _boundInitialDeposit(uint256 initialDeposit) internal returns (uint256) {
        return bound(initialDeposit, 1, 1e30);
    }

    function _boundInitialFee(uint256 initialFee) internal returns (uint256) {
        return bound(initialFee, 0, 1e18);
    }
}
