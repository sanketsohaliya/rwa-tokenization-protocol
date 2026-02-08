// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {MockUSDC} from "../src/mock/MockUSDC.sol";
import {ComplianceRegistry} from "../src/compliance/ComplianceRegistry.sol";
import {NAVOracle} from "../src/oracle/NAVOracle.sol";
import {BondToken} from "../src/token/BondToken.sol";
import {RealEstateToken} from "../src/token/RealEstateToken.sol";
import {CommodityToken} from "../src/token/CommodityToken.sol";
import {AssetFactory} from "../src/factory/AssetFactory.sol";

/**
 * @title Deploy
 * @notice Deploys the full RWA platform: MockUSDC, implementations, factory, and sample assets.
 * @dev Run: forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast --private-key $PRIVATE_KEY
 */
contract Deploy is Script {
    function run() external {
        vm.startBroadcast();

        address deployer = msg.sender;
        console.log("Deployer:", deployer);

        // 1. Deploy MockUSDC
        MockUSDC usdc = new MockUSDC();
        console.log("MockUSDC:", address(usdc));

        // 2. Deploy implementation contracts
        ComplianceRegistry complianceImpl = new ComplianceRegistry();
        NAVOracle navOracleImpl = new NAVOracle();
        BondToken bondImpl = new BondToken();
        RealEstateToken realEstateImpl = new RealEstateToken();
        CommodityToken commodityImpl = new CommodityToken();

        console.log("ComplianceRegistry impl:", address(complianceImpl));
        console.log("NAVOracle impl:", address(navOracleImpl));
        console.log("BondToken impl:", address(bondImpl));
        console.log("RealEstateToken impl:", address(realEstateImpl));
        console.log("CommodityToken impl:", address(commodityImpl));

        // 3. Deploy AssetFactory as UUPS proxy
        AssetFactory factoryImpl = new AssetFactory();
        AssetFactory factory = AssetFactory(address(new ERC1967Proxy(
            address(factoryImpl),
            abi.encodeCall(AssetFactory.initialize, (
                address(bondImpl),
                address(realEstateImpl),
                address(commodityImpl),
                address(complianceImpl),
                address(navOracleImpl)
            ))
        )));
        console.log("AssetFactory proxy:", address(factory));

        // ============================================================
        //              ASSET CREATION (round-robin by type)
        // ============================================================

        // --- Round 1 ---

        // 4. Bond: "US Treasury 6M"
        (address bondToken1, address bondRegistry1, address bondOracle1) = factory.createBond(
            "US Treasury 6M",
            "UST6M",
            block.timestamp + 180 days, // 6-month maturity
            500,                         // 5.00% coupon
            1000e6,                      // $1,000 face value
            address(usdc),
            deployer,
            deployer
        );
        console.log("Bond [UST6M]:", bondToken1);

        // 5. Real Estate: "Manhattan Office A"
        (address reToken1, , ) = factory.createRealEstate(
            "Manhattan Office A",
            "MNHTA",
            "property-001",
            "US",
            10_000_000e6,  // $10M valuation
            800,            // 8.00% rental yield
            address(usdc),
            deployer,
            deployer
        );
        console.log("RealEstate [MNHTA]:", reToken1);

        // 6. Commodity: "Gold Token"
        (address comToken1, , ) = factory.createCommodity(
            "Gold Token",
            "GLDT",
            "GOLD",
            "troy_oz",
            1e18,           // 1:1 backing
            address(usdc),
            deployer,
            deployer
        );
        console.log("Commodity [GLDT]:", comToken1);

        // --- Round 2 ---

        // 7. Bond: "US Treasury 2Y"
        (address bondToken2, , ) = factory.createBond(
            "US Treasury 2Y",
            "UST2Y",
            block.timestamp + 730 days, // 2-year maturity
            425,                         // 4.25% coupon
            1000e6,                      // $1,000 face value
            address(usdc),
            deployer,
            deployer
        );
        console.log("Bond [UST2Y]:", bondToken2);

        // 8. Real Estate: "Dubai Marina Tower"
        (address reToken2, address reRegistry2, ) = factory.createRealEstate(
            "Dubai Marina Tower",
            "DBMRT",
            "property-002",
            "AE",
            25_000_000e6,  // $25M valuation
            650,            // 6.50% rental yield
            address(usdc),
            deployer,
            deployer
        );
        console.log("RealEstate [DBMRT]:", reToken2);

        // 9. Commodity: "Silver Token"
        (address comToken2, address comRegistry2, ) = factory.createCommodity(
            "Silver Token",
            "SLVT",
            "SILVER",
            "troy_oz",
            1e18,           // 1:1 backing
            address(usdc),
            deployer,
            deployer
        );
        console.log("Commodity [SLVT]:", comToken2);

        // --- Round 3 ---

        // 10. Bond: "Corporate Bond AAA"
        (address bondToken3, address bondRegistry3, ) = factory.createBond(
            "Corporate Bond AAA",
            "CBAAA",
            block.timestamp + 365 days, // 1-year maturity
            600,                         // 6.00% coupon
            5000e6,                      // $5,000 face value
            address(usdc),
            deployer,
            deployer
        );
        console.log("Bond [CBAAA]:", bondToken3);

        // 11. Real Estate: "London Canary Wharf"
        (address reToken3, , ) = factory.createRealEstate(
            "London Canary Wharf",
            "LNCWF",
            "property-003",
            "GB",
            50_000_000e6,  // $50M valuation
            500,            // 5.00% rental yield
            address(usdc),
            deployer,
            deployer
        );
        console.log("RealEstate [LNCWF]:", reToken3);

        // 12. Commodity: "Platinum Token"
        (address comToken3, , ) = factory.createCommodity(
            "Platinum Token",
            "PLTT",
            "PLATINUM",
            "troy_oz",
            1e18,           // 1:1 backing
            address(usdc),
            deployer,
            deployer
        );
        console.log("Commodity [PLTT]:", comToken3);

        // --- Round 4 ---

        // 13. Bond: "EU Sovereign 1Y"
        (address bondToken4, , ) = factory.createBond(
            "EU Sovereign 1Y",
            "EUS1Y",
            block.timestamp + 365 days, // 1-year maturity
            350,                         // 3.50% coupon
            1000e6,                      // $1,000 face value
            address(usdc),
            deployer,
            deployer
        );
        console.log("Bond [EUS1Y]:", bondToken4);

        // 14. Real Estate: "Tokyo Shibuya Retail"
        (address reToken4, , ) = factory.createRealEstate(
            "Tokyo Shibuya Retail",
            "TKSHR",
            "property-004",
            "JP",
            15_000_000e6,  // $15M valuation
            720,            // 7.20% rental yield
            address(usdc),
            deployer,
            deployer
        );
        console.log("RealEstate [TKSHR]:", reToken4);

        // 15. Commodity: "Crude Oil Token"
        (address comToken4, , ) = factory.createCommodity(
            "Crude Oil Token",
            "OILT",
            "CRUDE_OIL",
            "barrel",
            1e18,           // 1:1 backing
            address(usdc),
            deployer,
            deployer
        );
        console.log("Commodity [OILT]:", comToken4);

        // --- Round 5 ---

        // 16. Bond: "High Yield Corp 5Y"
        (address bondToken5, , ) = factory.createBond(
            "High Yield Corp 5Y",
            "HYC5Y",
            block.timestamp + 1825 days, // 5-year maturity
            850,                          // 8.50% coupon
            1000e6,                       // $1,000 face value
            address(usdc),
            deployer,
            deployer
        );
        console.log("Bond [HYC5Y]:", bondToken5);

        // 17. Real Estate: "Singapore CBD Office"
        (address reToken5, , ) = factory.createRealEstate(
            "Singapore CBD Office",
            "SGCBD",
            "property-005",
            "SG",
            35_000_000e6,  // $35M valuation
            600,            // 6.00% rental yield
            address(usdc),
            deployer,
            deployer
        );
        console.log("RealEstate [SGCBD]:", reToken5);

        // 18. Commodity: "Natural Gas Token"
        (address comToken5, , ) = factory.createCommodity(
            "Natural Gas Token",
            "NGAS",
            "NATURAL_GAS",
            "mmbtu",
            1e18,           // 1:1 backing
            address(usdc),
            deployer,
            deployer
        );
        console.log("Commodity [NGAS]:", comToken5);

        // ============================================================
        //                   INVESTMENTS (4 total)
        // ============================================================

        // Mint 500k USDC to deployer for investments
        usdc.mint(deployer, 500_000e6);

        // Whitelist deployer on the 4 registries we'll invest through
        address[] memory accounts = new address[](1);
        accounts[0] = deployer;
        ComplianceRegistry(bondRegistry1).addToWhitelist(accounts);
        ComplianceRegistry(bondRegistry3).addToWhitelist(accounts);
        ComplianceRegistry(reRegistry2).addToWhitelist(accounts);
        ComplianceRegistry(comRegistry2).addToWhitelist(accounts);

        // Approve all tokens we'll invest in
        usdc.approve(bondToken1, type(uint256).max);
        usdc.approve(bondToken3, type(uint256).max);
        usdc.approve(reToken2, type(uint256).max);
        usdc.approve(comToken2, type(uint256).max);

        // 7a. Invest $10,000 in US Treasury 6M (Bond)
        uint256 tokensOut1 = BondToken(bondToken1).invest(10_000e6, 9_900e18);
        console.log("Invested 10,000 USDC in UST6M, tokens:", tokensOut1);

        // 7b. Invest $25,000 in Corporate Bond AAA
        uint256 tokensOut2 = BondToken(bondToken3).invest(25_000e6, 24_500e18);
        console.log("Invested 25,000 USDC in CBAAA, tokens:", tokensOut2);

        // 7c. Invest $50,000 in Dubai Marina Tower (Real Estate)
        uint256 tokensOut3 = RealEstateToken(reToken2).invest(50_000e6, 49_000e18);
        console.log("Invested 50,000 USDC in DBMRT, tokens:", tokensOut3);

        // 7d. Invest $15,000 in Silver Token (Commodity)
        uint256 tokensOut4 = CommodityToken(comToken2).invest(15_000e6, 14_500e18);
        console.log("Invested 15,000 USDC in SLVT, tokens:", tokensOut4);

        // 8. Update NAV on UST6M oracle to simulate 5% yield accrual
        NAVOracle(bondOracle1).updateNAV(1.05e18);
        uint256 value = BondToken(bondToken1).getTokenValue(tokensOut1);
        console.log("UST6M value after 5% yield (USDC):", value);

        vm.stopBroadcast();

        console.log("");
        console.log("=== Deployment Complete ===");
        console.log("Total assets deployed:", factory.getDeployedAssetsCount());
    }
}