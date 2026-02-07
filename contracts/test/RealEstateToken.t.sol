// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {ComplianceRegistry} from "../src/compliance/ComplianceRegistry.sol";
import {NAVOracle} from "../src/oracle/NAVOracle.sol";
import {RealEstateToken} from "../src/token/RealEstateToken.sol";
import {MockUSDC} from "../src/mock/MockUSDC.sol";

contract RealEstateTokenTest is Test {
    RealEstateToken token;
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

        token = RealEstateToken(address(new ERC1967Proxy(
            address(new RealEstateToken()),
            abi.encodeCall(RealEstateToken.initialize, (
                "Manhattan Office A", "MNHTA",
                address(registry), address(oracle), address(usdc), issuer,
                "property-001", "US", 10_000_000e6, 800
            ))
        )));
    }

    function test_metadata() public view {
        assertEq(token.propertyId(), "property-001");
        assertEq(token.jurisdiction(), "US");
        assertEq(token.totalValuation(), 10_000_000e6);
        assertEq(token.rentalYieldBps(), 800);
        assertEq(token.assetType(), "REAL_ESTATE");
    }

    function test_updateValuation() public {
        vm.prank(issuer);
        token.updateValuation(12_000_000e6);

        assertEq(token.totalValuation(), 12_000_000e6);
    }

    function test_updateValuation_revertIfNotOwner() public {
        vm.prank(makeAddr("stranger"));
        vm.expectRevert();
        token.updateValuation(12_000_000e6);
    }
}