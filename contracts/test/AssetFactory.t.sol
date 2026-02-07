// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {ComplianceRegistry} from "../src/compliance/ComplianceRegistry.sol";
import {NAVOracle} from "../src/oracle/NAVOracle.sol";
import {BondToken} from "../src/token/BondToken.sol";
import {RealEstateToken} from "../src/token/RealEstateToken.sol";
import {CommodityToken} from "../src/token/CommodityToken.sol";
import {AssetFactory} from "../src/factory/AssetFactory.sol";
import {MockUSDC} from "../src/mock/MockUSDC.sol";

contract AssetFactoryTest is Test {
    AssetFactory factory;
    MockUSDC usdc;

    address deployer = makeAddr("deployer");
    address alice = makeAddr("alice");

    function setUp() public {
        usdc = new MockUSDC();

        // Deploy implementations
        ComplianceRegistry complianceImpl = new ComplianceRegistry();
        NAVOracle navOracleImpl = new NAVOracle();
        BondToken bondImpl = new BondToken();
        RealEstateToken realEstateImpl = new RealEstateToken();
        CommodityToken commodityImpl = new CommodityToken();

        // Deploy factory as proxy
        AssetFactory factoryImpl = new AssetFactory();
        vm.prank(deployer);
        factory = AssetFactory(address(new ERC1967Proxy(
            address(factoryImpl),
            abi.encodeCall(AssetFactory.initialize, (
                address(bondImpl),
                address(realEstateImpl),
                address(commodityImpl),
                address(complianceImpl),
                address(navOracleImpl)
            ))
        )));
    }

    // --- Create Assets ---

    function test_createBond() public {
        vm.prank(alice);
        (address token, address registry, address oracle) = factory.createBond(
            "Test Bond", "TBOND",
            block.timestamp + 180 days, 500, 1000e6,
            address(usdc), alice, alice
        );

        assertTrue(token != address(0));
        assertTrue(registry != address(0));
        assertTrue(oracle != address(0));

        assertEq(BondToken(token).assetType(), "BOND");
        assertEq(BondToken(token).owner(), alice); // msg.sender becomes issuer
        assertEq(BondToken(token).couponRateBps(), 500);
        assertEq(factory.getDeployedAssetsCount(), 1);
    }

    function test_createRealEstate() public {
        vm.prank(alice);
        (address token, , ) = factory.createRealEstate(
            "Test Property", "TPROP",
            "prop-001", "US", 5_000_000e6, 700,
            address(usdc), alice, alice
        );

        assertEq(RealEstateToken(token).assetType(), "REAL_ESTATE");
        assertEq(RealEstateToken(token).propertyId(), "prop-001");
        assertEq(RealEstateToken(token).owner(), alice);
    }

    function test_createCommodity() public {
        vm.prank(alice);
        (address token, , ) = factory.createCommodity(
            "Test Gold", "TGLD",
            "GOLD", "troy_oz", 1e18,
            address(usdc), alice, alice
        );

        assertEq(CommodityToken(token).assetType(), "COMMODITY");
        assertEq(CommodityToken(token).commodityType(), "GOLD");
        assertEq(CommodityToken(token).owner(), alice);
    }

    // --- Registry Tracking ---

    function test_deployedAssetsTracked() public {
        vm.startPrank(alice);
        factory.createBond("B1", "B1", block.timestamp + 30 days, 100, 100e6, address(usdc), alice, alice);
        factory.createRealEstate("R1", "R1", "p1", "US", 1e6, 500, address(usdc), alice, alice);
        factory.createCommodity("C1", "C1", "SILVER", "oz", 1e18, address(usdc), alice, alice);
        vm.stopPrank();

        assertEq(factory.getDeployedAssetsCount(), 3);

        (address token, , , string memory assetType) = factory.deployedAssets(0);
        assertTrue(token != address(0));
        assertEq(assetType, "BOND");

        (, , , string memory assetType2) = factory.deployedAssets(1);
        assertEq(assetType2, "REAL_ESTATE");

        (, , , string memory assetType3) = factory.deployedAssets(2);
        assertEq(assetType3, "COMMODITY");
    }

    // --- Triplet Linking ---

    function test_tripletLinkedCorrectly() public {
        vm.prank(alice);
        (address token, address registry, address oracle) = factory.createBond(
            "Bond", "BND", block.timestamp + 90 days, 300, 500e6,
            address(usdc), alice, alice
        );

        BondToken bondToken = BondToken(token);

        // Token references the correct registry and oracle
        assertEq(address(bondToken.complianceRegistry()), registry);
        assertEq(address(bondToken.navOracle()), oracle);
        assertEq(address(bondToken.paymentToken()), address(usdc));

        // Registry is owned by compliance officer (alice)
        assertEq(ComplianceRegistry(registry).owner(), alice);

        // Oracle is owned by msg.sender (alice) with alice as updater
        assertEq(NAVOracle(oracle).owner(), alice);
        assertEq(NAVOracle(oracle).updater(), alice);
    }

    // --- Implementation Updates ---

    function test_updateImplementations() public {
        BondToken newBondImpl = new BondToken();

        vm.prank(deployer);
        factory.setBondImpl(address(newBondImpl));

        assertEq(factory.bondImpl(), address(newBondImpl));
    }

    function test_updateImplementation_revertIfNotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        factory.setBondImpl(address(1));
    }

    function test_updateImplementation_revertIfZero() public {
        vm.prank(deployer);
        vm.expectRevert(AssetFactory.ZeroAddress.selector);
        factory.setBondImpl(address(0));
    }

    // --- Full Lifecycle Integration ---

    function test_fullLifecycle() public {
        // 1. Create bond
        vm.prank(alice);
        (address token, address registry, address oracle) = factory.createBond(
            "Lifecycle Bond", "LCB",
            block.timestamp + 365 days, 500, 1000e6,
            address(usdc), alice, alice
        );

        BondToken bondToken = BondToken(token);

        // 2. Whitelist alice
        address[] memory accounts = new address[](1);
        accounts[0] = alice;
        vm.prank(alice);
        ComplianceRegistry(registry).addToWhitelist(accounts);

        // 3. Fund and invest
        usdc.mint(alice, 10_000e6);
        vm.startPrank(alice);
        usdc.approve(token, type(uint256).max);
        uint256 tokensOut = bondToken.invest(10_000e6, 9_900e18);
        vm.stopPrank();

        assertEq(tokensOut, 10_000e18);
        assertEq(bondToken.balanceOf(alice), 10_000e18);

        // 4. Update NAV (5% yield)
        vm.prank(alice);
        NAVOracle(oracle).updateNAV(1.05e18);

        // 5. Verify token value increased
        uint256 value = bondToken.getTokenValue(10_000e18);
        assertEq(value, 10_500e6);

        // 6. Fund contract for redemption yield and redeem
        usdc.mint(token, 500e6); // extra to cover yield
        vm.prank(alice);
        uint256 paymentOut = bondToken.redeem(10_000e18, 10_400e6);

        // 7. Verify yield realized
        assertEq(paymentOut, 10_500e6);
        assertEq(bondToken.balanceOf(alice), 0);
    }
}