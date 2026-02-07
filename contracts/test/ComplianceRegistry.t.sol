// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ComplianceRegistry} from "../src/compliance/ComplianceRegistry.sol";

contract ComplianceRegistryTest is Test {
    ComplianceRegistry registry;
    address owner = makeAddr("complianceOfficer");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        ComplianceRegistry impl = new ComplianceRegistry();
        registry = ComplianceRegistry(address(new ERC1967Proxy(
            address(impl),
            abi.encodeCall(ComplianceRegistry.initialize, (owner))
        )));
    }

    // --- Whitelist ---

    function test_addToWhitelist() public {
        address[] memory accounts = new address[](2);
        accounts[0] = alice;
        accounts[1] = bob;

        vm.prank(owner);
        registry.addToWhitelist(accounts);

        assertTrue(registry.isWhitelisted(alice));
        assertTrue(registry.isWhitelisted(bob));
    }

    function test_removeFromWhitelist() public {
        _whitelist(alice);

        address[] memory accounts = new address[](1);
        accounts[0] = alice;

        vm.prank(owner);
        registry.removeFromWhitelist(accounts);

        assertFalse(registry.isWhitelisted(alice));
    }

    function test_addToWhitelist_revertIfNotOwner() public {
        address[] memory accounts = new address[](1);
        accounts[0] = alice;

        vm.prank(alice);
        vm.expectRevert();
        registry.addToWhitelist(accounts);
    }

    function test_addToWhitelist_revertIfZeroAddress() public {
        address[] memory accounts = new address[](1);
        accounts[0] = address(0);

        vm.prank(owner);
        vm.expectRevert(ComplianceRegistry.ZeroAddress.selector);
        registry.addToWhitelist(accounts);
    }

    function test_addToWhitelist_revertIfAlreadyWhitelisted() public {
        _whitelist(alice);

        address[] memory accounts = new address[](1);
        accounts[0] = alice;

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(ComplianceRegistry.AlreadyWhitelisted.selector, alice));
        registry.addToWhitelist(accounts);
    }

    function test_removeFromWhitelist_revertIfNotWhitelisted() public {
        address[] memory accounts = new address[](1);
        accounts[0] = alice;

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(ComplianceRegistry.NotWhitelisted.selector, alice));
        registry.removeFromWhitelist(accounts);
    }

    // --- Freeze ---

    function test_freezeAddress() public {
        address[] memory accounts = new address[](1);
        accounts[0] = alice;

        vm.prank(owner);
        registry.freezeAddress(accounts);

        assertTrue(registry.isFrozen(alice));
    }

    function test_unfreezeAddress() public {
        _freeze(alice);

        address[] memory accounts = new address[](1);
        accounts[0] = alice;

        vm.prank(owner);
        registry.unfreezeAddress(accounts);

        assertFalse(registry.isFrozen(alice));
    }

    function test_freezeAddress_revertIfZeroAddress() public {
        address[] memory accounts = new address[](1);
        accounts[0] = address(0);

        vm.prank(owner);
        vm.expectRevert(ComplianceRegistry.ZeroAddress.selector);
        registry.freezeAddress(accounts);
    }

    function test_freezeAddress_revertIfAlreadyFrozen() public {
        _freeze(alice);

        address[] memory accounts = new address[](1);
        accounts[0] = alice;

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(ComplianceRegistry.AlreadyFrozen.selector, alice));
        registry.freezeAddress(accounts);
    }

    // --- isEligible ---

    function test_isEligible_whitelistedAndNotFrozen() public {
        _whitelist(alice);
        assertTrue(registry.isEligible(alice));
    }

    function test_isEligible_notWhitelisted() public view {
        assertFalse(registry.isEligible(alice));
    }

    function test_isEligible_whitelistedButFrozen() public {
        _whitelist(alice);
        _freeze(alice);
        assertFalse(registry.isEligible(alice));
    }

    function test_isEligible_frozenButNotWhitelisted() public {
        _freeze(alice);
        assertFalse(registry.isEligible(alice));
    }

    // --- Upgrade ---

    function test_upgrade() public {
        ComplianceRegistry newImpl = new ComplianceRegistry();

        vm.prank(owner);
        registry.upgradeToAndCall(address(newImpl), "");

        // Still works after upgrade
        _whitelist(alice);
        assertTrue(registry.isEligible(alice));
    }

    function test_upgrade_revertIfNotOwner() public {
        ComplianceRegistry newImpl = new ComplianceRegistry();

        vm.prank(alice);
        vm.expectRevert();
        registry.upgradeToAndCall(address(newImpl), "");
    }

    // --- Helpers ---

    function _whitelist(address account) internal {
        address[] memory accounts = new address[](1);
        accounts[0] = account;
        vm.prank(owner);
        registry.addToWhitelist(accounts);
    }

    function _freeze(address account) internal {
        address[] memory accounts = new address[](1);
        accounts[0] = account;
        vm.prank(owner);
        registry.freezeAddress(accounts);
    }
}