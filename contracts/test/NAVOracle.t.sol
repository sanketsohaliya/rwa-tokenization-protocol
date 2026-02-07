// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {NAVOracle} from "../src/oracle/NAVOracle.sol";

contract NAVOracleTest is Test {
    NAVOracle oracle;
    address owner = makeAddr("owner");
    address updater = makeAddr("updater");
    uint256 constant MAX_STALENESS = 90000; // 25 hours

    function setUp() public {
        NAVOracle impl = new NAVOracle();
        oracle = NAVOracle(address(new ERC1967Proxy(
            address(impl),
            abi.encodeCall(NAVOracle.initialize, (owner, updater, MAX_STALENESS))
        )));
    }

    // --- Initialization ---

    function test_initialState() public view {
        assertEq(oracle.navPerToken(), 1e18);
        assertEq(oracle.updater(), updater);
        assertEq(oracle.maxStaleness(), MAX_STALENESS);
        assertFalse(oracle.isStale());
    }

    // --- updateNAV ---

    function test_updateNAV() public {
        vm.prank(updater);
        oracle.updateNAV(1.05e18);

        assertEq(oracle.navPerToken(), 1.05e18);
    }

    function test_updateNAV_revertIfDecreased() public {
        vm.prank(updater);
        oracle.updateNAV(1.05e18);

        vm.prank(updater);
        vm.expectRevert(NAVOracle.NAVDecreased.selector);
        oracle.updateNAV(1.04e18);
    }

    function test_updateNAV_sameValueAllowed() public {
        vm.prank(updater);
        oracle.updateNAV(1e18); // same as initial -- allowed (>=)
    }

    function test_updateNAV_revertIfNotUpdater() public {
        vm.prank(owner); // owner is NOT the updater
        vm.expectRevert(NAVOracle.NotUpdater.selector);
        oracle.updateNAV(1.05e18);
    }

    // --- Staleness ---

    function test_getValidatedNavPerToken_fresh() public view {
        assertEq(oracle.getValidatedNavPerToken(), 1e18);
    }

    function test_getValidatedNavPerToken_revertIfStale() public {
        vm.warp(block.timestamp + MAX_STALENESS + 1);

        vm.expectRevert(NAVOracle.StaleNAV.selector);
        oracle.getValidatedNavPerToken();
    }

    function test_isStale_afterMaxStaleness() public {
        assertFalse(oracle.isStale());

        vm.warp(block.timestamp + MAX_STALENESS + 1);
        assertTrue(oracle.isStale());
    }

    function test_updateNAV_resetsStaleness() public {
        vm.warp(block.timestamp + MAX_STALENESS + 1);
        assertTrue(oracle.isStale());

        vm.prank(updater);
        oracle.updateNAV(1.01e18);

        assertFalse(oracle.isStale());
        assertEq(oracle.getValidatedNavPerToken(), 1.01e18);
    }

    // --- Admin ---

    function test_setUpdater() public {
        address newUpdater = makeAddr("newUpdater");

        vm.prank(owner);
        oracle.setUpdater(newUpdater);

        assertEq(oracle.updater(), newUpdater);

        // New updater can update NAV
        vm.prank(newUpdater);
        oracle.updateNAV(1.02e18);
        assertEq(oracle.navPerToken(), 1.02e18);
    }

    function test_setUpdater_revertIfNotOwner() public {
        vm.prank(updater);
        vm.expectRevert();
        oracle.setUpdater(makeAddr("x"));
    }

    function test_setMaxStaleness() public {
        vm.prank(owner);
        oracle.setMaxStaleness(3600);

        assertEq(oracle.maxStaleness(), 3600);
    }

    function test_setMaxStaleness_revertIfZero() public {
        vm.prank(owner);
        vm.expectRevert(NAVOracle.ZeroValue.selector);
        oracle.setMaxStaleness(0);
    }

    // --- Upgrade ---

    function test_upgrade() public {
        NAVOracle newImpl = new NAVOracle();

        vm.prank(owner);
        oracle.upgradeToAndCall(address(newImpl), "");

        // State preserved after upgrade
        assertEq(oracle.navPerToken(), 1e18);
        assertEq(oracle.updater(), updater);
    }

    function test_upgrade_revertIfNotOwner() public {
        NAVOracle newImpl = new NAVOracle();

        vm.prank(updater);
        vm.expectRevert();
        oracle.upgradeToAndCall(address(newImpl), "");
    }
}