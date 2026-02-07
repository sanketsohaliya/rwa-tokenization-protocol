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

        // 4. Create sample bond: "US Treasury 6M"
        (address bondToken, address bondRegistry, address bondOracle) = factory.createBond(
            "US Treasury 6M",
            "UST6M",
            block.timestamp + 180 days, // 6-month maturity
            500,                         // 5% coupon (500 bps)
            1000e6,                      // $1000 face value
            address(usdc),
            deployer,                    // compliance officer
            deployer                     // oracle updater
        );
        console.log("Bond token:", bondToken);
        console.log("Bond registry:", bondRegistry);
        console.log("Bond oracle:", bondOracle);

        // 5. Create sample real estate: "Manhattan Office A"
        (address reToken, , ) = factory.createRealEstate(
            "Manhattan Office A",
            "MNHTA",
            "property-001",
            "US",
            10_000_000e6,  // $10M valuation
            800,            // 8% rental yield (800 bps)
            address(usdc),
            deployer,
            deployer
        );
        console.log("RealEstate token:", reToken);

        // 6. Create sample commodity: "Gold Token"
        (address goldToken, , ) = factory.createCommodity(
            "Gold Token",
            "GLDT",
            "GOLD",
            "troy_oz",
            1e18,           // 1:1 backing
            address(usdc),
            deployer,
            deployer
        );
        console.log("Commodity token:", goldToken);

        // 7. Whitelist deployer on bond registry and invest
        address[] memory accounts = new address[](1);
        accounts[0] = deployer;
        ComplianceRegistry(bondRegistry).addToWhitelist(accounts);

        // Mint 100k USDC to deployer and invest 10k in the bond
        usdc.mint(deployer, 100_000e6);
        usdc.approve(bondToken, type(uint256).max);
        uint256 tokensOut = BondToken(bondToken).invest(10_000e6, 9_900e18);
        console.log("Invested 10,000 USDC, received tokens:", tokensOut);

        // 8. Update NAV to simulate yield accrual (5%)
        NAVOracle(bondOracle).updateNAV(1.05e18);
        uint256 value = BondToken(bondToken).getTokenValue(tokensOut);
        console.log("Token value after 5% yield (in USDC):", value);

        vm.stopBroadcast();

        console.log("");
        console.log("=== Deployment Complete ===");
        console.log("Total assets deployed:", factory.getDeployedAssetsCount());
    }
}