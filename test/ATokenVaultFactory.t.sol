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

contract ATokenVaultFactoryTest is Test {
    ATokenVaultFactory factory;
    MockAavePoolAddressesProvider poolAddrProvider;
    MockAavePool pool;
    MockAToken aDai;
    MockDAI dai;

    address proxyAdmin = makeAddr("proxyAdmin");

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
        dai = new MockDAI();
        aDai = new MockAToken(address(dai));
        pool = new MockAavePool(aDai);
        poolAddrProvider = new MockAavePoolAddressesProvider(address(pool));
        factory = new ATokenVaultFactory(proxyAdmin);

        pool.setReserveConfigMap(RESERVE_CONFIG_MAP_UNCAPPED_ACTIVE);
    }

    /*//////////////////////////////////////////////////////////////
                            DEPLOYMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function testDeployVault() public {
        uint256 initialDeposit = 1000 * 1e18;
        deal(address(dai), ALICE, initialDeposit);

        vm.startPrank(ALICE);
        dai.approve(address(factory), initialDeposit);

        ATokenVaultFactory.VaultParams memory params = ATokenVaultFactory.VaultParams({
            underlying: address(dai),
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
        assertTrue(factory.isDeployedVault(vault));
        assertEq(factory.getAllVaultsLength(), 1);
        assertEq(factory.getAllVaults()[0], vault);

        ATokenVault vaultContract = ATokenVault(vault);
        assertEq(address(vaultContract.UNDERLYING()), address(dai));
        assertEq(vaultContract.REFERRAL_CODE(), 42);
        assertEq(vaultContract.owner(), ALICE);
        assertEq(vaultContract.name(), "Test Vault");
        assertEq(vaultContract.symbol(), "tVault");
        assertEq(vaultContract.getFee(), 0);

        address[] memory aliceVaults = factory.getVaultsByDeployer(ALICE);
        assertEq(aliceVaults.length, 1);
        assertEq(aliceVaults[0], vault);
    }

    function testDeployVaultWithFee() public {
        uint256 initialDeposit = 1000 * 1e18;
        uint256 fee = 1e17; // 10%
        deal(address(dai), ALICE, initialDeposit);

        vm.startPrank(ALICE);
        dai.approve(address(factory), initialDeposit);

        ATokenVaultFactory.VaultParams memory params = ATokenVaultFactory.VaultParams({
            underlying: address(dai),
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
        assertEq(address(vaultContract.UNDERLYING()), address(dai));
        assertEq(vaultContract.getFee(), fee);
        assertEq(vaultContract.name(), "Fee Vault");
        assertEq(vaultContract.symbol(), "fVault");
    }

    function testDeployMultipleVaults() public {
        uint256 initialDeposit = 1000 * 1e18;

        deal(address(dai), ALICE, initialDeposit);
        vm.startPrank(ALICE);
        dai.approve(address(factory), initialDeposit);

        ATokenVaultFactory.VaultParams memory params1 = ATokenVaultFactory.VaultParams({
            underlying: address(dai),
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

        deal(address(dai), BOB, initialDeposit);
        vm.startPrank(BOB);
        dai.approve(address(factory), initialDeposit);

        ATokenVaultFactory.VaultParams memory params2 = ATokenVaultFactory.VaultParams({
            underlying: address(dai),
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

        assertEq(factory.getAllVaultsLength(), 2);
        address[] memory allVaults = factory.getAllVaults();
        assertEq(allVaults[0], vault1);
        assertEq(allVaults[1], vault2);

        assertTrue(vault1 != vault2);

        address[] memory daiVaults = factory.getVaultsByUnderlying(address(dai));
        assertEq(daiVaults.length, 2);
        assertEq(daiVaults[0], vault1);
        assertEq(daiVaults[1], vault2);

        address[] memory aliceVaults = factory.getVaultsByDeployer(ALICE);
        assertEq(aliceVaults.length, 1);
        assertEq(aliceVaults[0], vault1);

        address[] memory bobVaults = factory.getVaultsByDeployer(BOB);
        assertEq(bobVaults.length, 1);
        assertEq(bobVaults[0], vault2);

        ATokenVault vault1Contract = ATokenVault(vault1);
        ATokenVault vault2Contract = ATokenVault(vault2);
        assertEq(vault1Contract.owner(), ALICE);
        assertEq(vault2Contract.owner(), BOB);
    }

    function testDeployVaultEmitsEvent() public {
        uint256 initialDeposit = 1000 * 1e18;
        deal(address(dai), ALICE, initialDeposit);

        vm.startPrank(ALICE);
        dai.approve(address(factory), initialDeposit);

        ATokenVaultFactory.VaultParams memory params = ATokenVaultFactory.VaultParams({
            underlying: address(dai),
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
            if (logs[i].topics[0] == keccak256("VaultDeployed(address,address,address,address,address,uint16,address)")) {
                eventFound = true;

                // Decode the event data
                address eventVault = address(uint160(uint256(logs[i].topics[1])));
                address eventImplementation = address(uint160(uint256(logs[i].topics[2])));
                address eventUnderlying = address(uint160(uint256(logs[i].topics[3])));

                (address eventDeployer, address eventOwner, uint16 eventReferralCode, address eventPoolProvider) =
                                    abi.decode(logs[i].data, (address, address, uint16, address));

                // Verify event data
                assertEq(eventVault, vault);
                assertTrue(eventImplementation != address(0));
                assertEq(eventUnderlying, address(dai));
                assertEq(eventDeployer, ALICE);
                assertEq(eventOwner, ALICE);
                assertEq(eventReferralCode, 42);
                assertEq(eventPoolProvider, address(poolAddrProvider));
                break;
            }
        }

        assertTrue(eventFound, "VaultDeployed event not found");
    }

    function testDeployVaultWithMaxReferralCode() public {
        uint256 initialDeposit = 1000 * 1e18;
        uint16 maxReferralCode = type(uint16).max;
        deal(address(dai), ALICE, initialDeposit);

        vm.startPrank(ALICE);
        dai.approve(address(factory), initialDeposit);

        ATokenVaultFactory.VaultParams memory params = ATokenVaultFactory.VaultParams({
            underlying: address(dai),
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
        deal(address(dai), ALICE, initialDeposit);

        vm.startPrank(ALICE);
        dai.approve(address(factory), initialDeposit);

        ATokenVaultFactory.VaultParams memory params = ATokenVaultFactory.VaultParams({
            underlying: address(dai),
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
        deal(address(dai), ALICE, initialDeposit);

        vm.startPrank(ALICE);
        dai.approve(address(factory), initialDeposit);

        ATokenVaultFactory.VaultParams memory params = ATokenVaultFactory.VaultParams({
            underlying: address(dai),
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

        address[] memory aliceVaults = factory.getVaultsByDeployer(ALICE);
        assertEq(aliceVaults.length, 1);
        assertEq(aliceVaults[0], vault);

        address[] memory bobVaults = factory.getVaultsByDeployer(BOB);
        assertEq(bobVaults.length, 0);
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
            underlying: address(dai),
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
            underlying: address(dai),
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
            underlying: address(dai),
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
            underlying: address(dai),
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
            underlying: address(dai),
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
        deal(address(dai), ALICE, initialDeposit);

        vm.startPrank(ALICE);
        dai.approve(address(factory), initialDeposit - 1); // Insufficient approval

        ATokenVaultFactory.VaultParams memory params = ATokenVaultFactory.VaultParams({
            underlying: address(dai),
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
        deal(address(dai), ALICE, initialDeposit - 1); // Insufficient balance

        vm.startPrank(ALICE);
        dai.approve(address(factory), initialDeposit);

        ATokenVaultFactory.VaultParams memory params = ATokenVaultFactory.VaultParams({
            underlying: address(dai),
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

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function testConstructorZeroProxyAdminReverts() public {
        vm.expectRevert("ZERO_ADDRESS_NOT_VALID");
        new ATokenVaultFactory(address(0));
    }

    function testConstructorSetsProxyAdmin() public {
        ATokenVaultFactory newFactory = new ATokenVaultFactory(CHARLIE);
        assertEq(newFactory.PROXY_ADMIN(), CHARLIE);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function testGetVaultInfo() public {
        uint256 initialDeposit = 1000 * 1e18;
        deal(address(dai), ALICE, initialDeposit);

        vm.startPrank(ALICE);
        dai.approve(address(factory), initialDeposit);

        ATokenVaultFactory.VaultParams memory params = ATokenVaultFactory.VaultParams({
            underlying: address(dai),
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

        (address vaultAddr, address underlying) = factory.getVaultInfo(0);
        assertEq(vaultAddr, vault);
        assertEq(underlying, address(dai));
    }

    function testGetVaultInfoInvalidIndexReverts() public {
        vm.expectRevert("INVALID_VAULT_INDEX");
        factory.getVaultInfo(0);
    }

    function testGetVaultInfoMultipleVaults() public {
        uint256 initialDeposit = 1000 * 1e18;

        deal(address(dai), ALICE, initialDeposit * 2);
        vm.startPrank(ALICE);
        dai.approve(address(factory), initialDeposit * 2);

        ATokenVaultFactory.VaultParams memory params1 = ATokenVaultFactory.VaultParams({
            underlying: address(dai),
            referralCode: 0,
            poolAddressesProvider: IPoolAddressesProvider(address(poolAddrProvider)),
            owner: ALICE,
            initialFee: 0,
            shareName: "First Vault",
            shareSymbol: "FV",
            initialLockDeposit: initialDeposit
        });

        address vault1 = factory.deployVault(params1);

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);

        ATokenVaultFactory.VaultParams memory params2 = ATokenVaultFactory.VaultParams({
            underlying: address(dai),
            referralCode: 0,
            poolAddressesProvider: IPoolAddressesProvider(address(poolAddrProvider)),
            owner: ALICE,
            initialFee: 0,
            shareName: "Second Vault",
            shareSymbol: "SV",
            initialLockDeposit: initialDeposit
        });

        address vault2 = factory.deployVault(params2);
        vm.stopPrank();

        (address vaultAddr1, address underlying1) = factory.getVaultInfo(0);
        (address vaultAddr2, address underlying2) = factory.getVaultInfo(1);

        assertEq(vaultAddr1, vault1);
        assertEq(underlying1, address(dai));
        assertEq(vaultAddr2, vault2);
        assertEq(underlying2, address(dai));
    }

    function testIsDeployedVault() public {
        uint256 initialDeposit = 1000 * 1e18;
        deal(address(dai), ALICE, initialDeposit);

        vm.startPrank(ALICE);
        dai.approve(address(factory), initialDeposit);

        ATokenVaultFactory.VaultParams memory params = ATokenVaultFactory.VaultParams({
            underlying: address(dai),
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

        assertTrue(factory.isDeployedVault(vault));
        assertFalse(factory.isDeployedVault(address(0x999)));
        assertFalse(factory.isDeployedVault(address(0)));
        assertFalse(factory.isDeployedVault(address(factory)));
    }

    function testGetVaultsByUnderlyingEmpty() public {
        address[] memory vaults = factory.getVaultsByUnderlying(address(dai));
        assertEq(vaults.length, 0);
    }

    function testGetVaultsByDeployerEmpty() public {
        address[] memory vaults = factory.getVaultsByDeployer(ALICE);
        assertEq(vaults.length, 0);
    }

    function testGetAllVaultsEmpty() public {
        address[] memory vaults = factory.getAllVaults();
        assertEq(vaults.length, 0);
        assertEq(factory.getAllVaultsLength(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                            INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testVaultBasicProperties() public {
        uint256 initialDeposit = 1000 * 1e18;
        deal(address(dai), ALICE, initialDeposit);

        vm.startPrank(ALICE);
        dai.approve(address(factory), initialDeposit);

        ATokenVaultFactory.VaultParams memory params = ATokenVaultFactory.VaultParams({
            underlying: address(dai),
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

        assertEq(address(vaultContract.UNDERLYING()), address(dai));
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
        MockAavePool usdcPool = new MockAavePool(aUsdc);
        MockAavePoolAddressesProvider usdcPoolProvider = new MockAavePoolAddressesProvider(address(usdcPool));

        usdcPool.setReserveConfigMap(RESERVE_CONFIG_MAP_UNCAPPED_ACTIVE);

        deal(address(dai), ALICE, initialDeposit);
        deal(address(usdc), ALICE, initialDeposit);

        vm.startPrank(ALICE);
        dai.approve(address(factory), initialDeposit);
        usdc.approve(address(factory), initialDeposit);

        ATokenVaultFactory.VaultParams memory daiParams = ATokenVaultFactory.VaultParams({
            underlying: address(dai),
            referralCode: 0,
            poolAddressesProvider: IPoolAddressesProvider(address(poolAddrProvider)),
            owner: ALICE,
            initialFee: 0,
            shareName: "DAI Vault",
            shareSymbol: "dVault",
            initialLockDeposit: initialDeposit
        });

        address daiVault = factory.deployVault(daiParams);

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

        assertTrue(daiVault != usdcVault);
        assertEq(factory.getAllVaultsLength(), 2);

        address[] memory daiVaults = factory.getVaultsByUnderlying(address(dai));
        address[] memory usdcVaults = factory.getVaultsByUnderlying(address(usdc));

        assertEq(daiVaults.length, 1);
        assertEq(usdcVaults.length, 1);
        assertEq(daiVaults[0], daiVault);
        assertEq(usdcVaults[0], usdcVault);
    }

    function testDeploymentCounterIncreases() public {
        uint256 initialDeposit = 1000 * 1e18;
        deal(address(dai), ALICE, initialDeposit * 3);

        vm.startPrank(ALICE);
        dai.approve(address(factory), initialDeposit * 3);

        ATokenVaultFactory.VaultParams memory params = ATokenVaultFactory.VaultParams({
            underlying: address(dai),
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
        assertEq(factory.getAllVaultsLength(), 3);
    }

    function testDeployVaultEdgeCaseMinimalDeposit() public {
        uint256 minDeposit = 1;
        deal(address(dai), ALICE, minDeposit);

        vm.startPrank(ALICE);
        dai.approve(address(factory), minDeposit);

        ATokenVaultFactory.VaultParams memory params = ATokenVaultFactory.VaultParams({
            underlying: address(dai),
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
        assertTrue(factory.isDeployedVault(vault));
    }

    function testDeployVaultEdgeCaseZeroFee() public {
        uint256 initialDeposit = 1000 * 1e18;
        deal(address(dai), ALICE, initialDeposit);

        vm.startPrank(ALICE);
        dai.approve(address(factory), initialDeposit);

        ATokenVaultFactory.VaultParams memory params = ATokenVaultFactory.VaultParams({
            underlying: address(dai),
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
        deal(address(dai), ALICE, initialDeposit);

        vm.startPrank(ALICE);
        dai.approve(address(factory), initialDeposit);

        ATokenVaultFactory.VaultParams memory params = ATokenVaultFactory.VaultParams({
            underlying: address(dai),
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
        vm.assume(initialDeposit > 0 && initialDeposit <= 1e30);
        vm.assume(initialFee <= 1e18); // Max 100% fee

        deal(address(dai), ALICE, initialDeposit);

        vm.startPrank(ALICE);
        dai.approve(address(factory), initialDeposit);

        ATokenVaultFactory.VaultParams memory params = ATokenVaultFactory.VaultParams({
            underlying: address(dai),
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
        assertTrue(factory.isDeployedVault(vault));

        ATokenVault vaultContract = ATokenVault(vault);
        assertEq(vaultContract.REFERRAL_CODE(), referralCode);
        assertEq(vaultContract.getFee(), initialFee);
    }

    function testFuzzDeployVaultEdgeCases(
        uint16 referralCode,
        uint256 initialFee
    ) public {
        uint256 minDeposit = 1;
        vm.assume(initialFee <= 1e18);

        deal(address(dai), ALICE, minDeposit);

        vm.startPrank(ALICE);
        dai.approve(address(factory), minDeposit);

        ATokenVaultFactory.VaultParams memory params = ATokenVaultFactory.VaultParams({
            underlying: address(dai),
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
        assertTrue(factory.isDeployedVault(vault));

        ATokenVault vaultContract = ATokenVault(vault);
        assertEq(vaultContract.REFERRAL_CODE(), referralCode);
        assertEq(vaultContract.getFee(), initialFee);
    }

    function testFuzzDeployVaultBoundaryFees(
        uint16 referralCode,
        uint256 initialDeposit
    ) public {
        vm.assume(initialDeposit > 0 && initialDeposit <= 1e30);

        deal(address(dai), ALICE, initialDeposit);

        vm.startPrank(ALICE);
        dai.approve(address(factory), initialDeposit);

        ATokenVaultFactory.VaultParams memory params = ATokenVaultFactory.VaultParams({
            underlying: address(dai),
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

        deal(address(dai), BOB, initialDeposit);
        vm.startPrank(BOB);
        dai.approve(address(factory), initialDeposit);

        params.owner = BOB;
        params.initialFee = 1e18;
        params.shareName = "Max Fee Fuzz Vault";
        params.shareSymbol = "MFFV";

        address vault2 = factory.deployVault(params);
        vm.stopPrank();

        ATokenVault vaultContract2 = ATokenVault(vault2);
        assertEq(vaultContract2.getFee(), 1e18);
    }
}