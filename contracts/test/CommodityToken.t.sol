// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {ComplianceRegistry} from "../src/compliance/ComplianceRegistry.sol";
import {NAVOracle} from "../src/oracle/NAVOracle.sol";
import {CommodityToken} from "../src/token/CommodityToken.sol";
import {MockUSDC} from "../src/mock/MockUSDC.sol";

contract CommodityTokenTest is Test {
    CommodityToken token;
    address issuer = makeAddr("issuer");

    function setUp() public {
        MockUSDC usdc = new MockUSDC();

        ComplianceRegistry registry = ComplianceRegistry(address(new ERC1967Proxy(
            address(new ComplianceRegistry()),
            abi.encodeCall(ComplianceRegistry.initialize, (issuer))
        )));

        NAVOracle oracle = NAVOracle(address(new ERC1967Proxy(
            address(new NAVOracle()),
            abi.encodeCall(NAVOracle.initialize, (issuer, issuer, 90000))
        )));

        token = CommodityToken(address(new ERC1967Proxy(
            address(new CommodityToken()),
            abi.encodeCall(CommodityToken.initialize, (
                "Gold Token", "GLDT",
                address(registry), address(oracle), address(usdc), issuer,
                "GOLD", "troy_oz", 1e18
            ))
        )));
    }

    function test_metadata() public view {
        assertEq(token.commodityType(), "GOLD");
        assertEq(token.unit(), "troy_oz");
        assertEq(token.backingRatio(), 1e18);
        assertEq(token.assetType(), "COMMODITY");
    }

    function test_updateBackingRatio() public {
        vm.prank(issuer);
        token.updateBackingRatio(0.95e18);

        assertEq(token.backingRatio(), 0.95e18);
    }

    function test_updateBackingRatio_revertIfNotOwner() public {
        vm.prank(makeAddr("stranger"));
        vm.expectRevert();
        token.updateBackingRatio(0.95e18);
    }
}