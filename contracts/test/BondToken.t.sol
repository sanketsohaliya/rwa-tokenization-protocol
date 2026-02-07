// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {ComplianceRegistry} from "../src/compliance/ComplianceRegistry.sol";
import {NAVOracle} from "../src/oracle/NAVOracle.sol";
import {BondToken} from "../src/token/BondToken.sol";
import {RWAToken} from "../src/token/RWAToken.sol";
import {MockUSDC} from "../src/mock/MockUSDC.sol";

contract BondTokenTest is Test {
    ComplianceRegistry registry;
    NAVOracle oracle;
    BondToken bond;
    MockUSDC usdc;

    address issuer = makeAddr("issuer");
    address complianceOfficer = makeAddr("complianceOfficer");
    address oracleUpdater = makeAddr("oracleUpdater");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    uint256 constant MATURITY = 180 days;
    uint256 constant COUPON_BPS = 500;
    uint256 constant FACE_VALUE = 1000e6;

    function setUp() public {
        // Deploy MockUSDC
        usdc = new MockUSDC();

        // Deploy ComplianceRegistry proxy
        ComplianceRegistry registryImpl = new ComplianceRegistry();
        registry = ComplianceRegistry(address(new ERC1967Proxy(
            address(registryImpl),
            abi.encodeCall(ComplianceRegistry.initialize, (complianceOfficer))
        )));

        // Deploy NAVOracle proxy
        NAVOracle oracleImpl = new NAVOracle();
        oracle = NAVOracle(address(new ERC1967Proxy(
            address(oracleImpl),
            abi.encodeCall(NAVOracle.initialize, (issuer, oracleUpdater, 90000))
        )));

        // Deploy BondToken proxy
        BondToken bondImpl = new BondToken();
        bond = BondToken(address(new ERC1967Proxy(
            address(bondImpl),
            abi.encodeCall(BondToken.initialize, (
                "US Treasury 6M", "UST6M",
                address(registry), address(oracle), address(usdc), issuer,
                block.timestamp + MATURITY, COUPON_BPS, FACE_VALUE
            ))
        )));

        // Whitelist alice and bob
        _whitelist(alice);
        _whitelist(bob);

        // Fund alice with USDC
        usdc.mint(alice, 1_000_000e6);
        vm.prank(alice);
        usdc.approve(address(bond), type(uint256).max);

        // Fund bob with USDC
        usdc.mint(bob, 1_000_000e6);
        vm.prank(bob);
        usdc.approve(address(bond), type(uint256).max);
    }

    // ============================
    // Invest
    // ============================

    function test_invest_correctTokenAmount() public {
        vm.prank(alice);
        uint256 tokensOut = bond.invest(1000e6, 0);

        // 1000 USDC at NAV 1e18 => 1000e18 tokens
        assertEq(tokensOut, 1000e18);
        assertEq(bond.balanceOf(alice), 1000e18);
        assertEq(usdc.balanceOf(address(bond)), 1000e6);
    }

    function test_invest_atHigherNAV() public {
        _updateNAV(1.05e18);

        vm.prank(alice);
        uint256 tokensOut = bond.invest(1050e6, 0);

        // 1050 USDC at NAV 1.05e18 => 1000e18 tokens
        assertEq(tokensOut, 1000e18);
    }

    function test_invest_slippageProtection() public {
        vm.prank(alice);
        uint256 tokensOut = bond.invest(1000e6, 999e18);
        assertEq(tokensOut, 1000e18); // passes, 1000 >= 999
    }

    function test_invest_revertSlippageExceeded() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(RWAToken.SlippageExceeded.selector, 1000e18, 1001e18));
        bond.invest(1000e6, 1001e18); // wants 1001 but only gets 1000
    }

    function test_invest_revertIfNotEligible() public {
        address stranger = makeAddr("stranger");
        usdc.mint(stranger, 1000e6);
        vm.startPrank(stranger);
        usdc.approve(address(bond), type(uint256).max);

        vm.expectRevert(abi.encodeWithSelector(RWAToken.NotEligible.selector, stranger));
        bond.invest(1000e6, 0);
        vm.stopPrank();
    }

    function test_invest_revertIfFrozen() public {
        _freeze(alice);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(RWAToken.NotEligible.selector, alice));
        bond.invest(1000e6, 0);
    }

    function test_invest_revertIfPaused() public {
        vm.prank(issuer);
        bond.pause();

        vm.prank(alice);
        vm.expectRevert();
        bond.invest(1000e6, 0);
    }

    function test_invest_revertIfStaleNAV() public {
        vm.warp(block.timestamp + 90001);

        vm.prank(alice);
        vm.expectRevert(NAVOracle.StaleNAV.selector);
        bond.invest(1000e6, 0);
    }

    function test_invest_revertIfZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert(RWAToken.ZeroAmount.selector);
        bond.invest(0, 0);
    }

    // ============================
    // Redeem
    // ============================

    function test_redeem_correctPaymentAmount() public {
        // Invest first
        vm.prank(alice);
        bond.invest(1000e6, 0);

        // Redeem all
        vm.prank(alice);
        uint256 paymentOut = bond.redeem(1000e18, 0);

        assertEq(paymentOut, 1000e6);
        assertEq(bond.balanceOf(alice), 0);
    }

    function test_redeem_afterNAVIncrease() public {
        // Invest 1000 USDC => 1000 tokens
        vm.prank(alice);
        bond.invest(1000e6, 0);

        // NAV goes up 5%
        _updateNAV(1.05e18);

        // Need to fund contract for extra yield payment
        usdc.mint(address(bond), 50e6);

        // Redeem 1000 tokens => should get 1050 USDC
        vm.prank(alice);
        uint256 paymentOut = bond.redeem(1000e18, 0);

        assertEq(paymentOut, 1050e6);
    }

    function test_redeem_slippageProtection() public {
        vm.prank(alice);
        bond.invest(1000e6, 0);

        vm.prank(alice);
        uint256 paymentOut = bond.redeem(1000e18, 999e6);
        assertEq(paymentOut, 1000e6); // 1000 >= 999
    }

    function test_redeem_revertSlippageExceeded() public {
        vm.prank(alice);
        bond.invest(1000e6, 0);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(RWAToken.SlippageExceeded.selector, 1000e6, 1001e6));
        bond.redeem(1000e18, 1001e6);
    }

    function test_redeem_revertIfFrozen() public {
        vm.prank(alice);
        bond.invest(1000e6, 0);

        _freeze(alice);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(RWAToken.NotEligible.selector, alice));
        bond.redeem(1000e18, 0);
    }

    function test_redeem_revertIfPaused() public {
        vm.prank(alice);
        bond.invest(1000e6, 0);

        vm.prank(issuer);
        bond.pause();

        vm.prank(alice);
        vm.expectRevert();
        bond.redeem(1000e18, 0);
    }

    function test_redeem_revertInsufficientBalance() public {
        vm.prank(alice);
        bond.invest(1000e6, 0);

        // Issuer withdraws all payment tokens
        vm.prank(issuer);
        bond.withdrawPaymentTokens(issuer, 1000e6);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(RWAToken.InsufficientPaymentBalance.selector, 0, 1000e6));
        bond.redeem(1000e18, 0);
    }

    // ============================
    // Transfers
    // ============================

    function test_transfer_whitelistedToWhitelisted() public {
        vm.prank(alice);
        bond.invest(1000e6, 0);

        vm.prank(alice);
        bond.transfer(bob, 500e18);

        assertEq(bond.balanceOf(alice), 500e18);
        assertEq(bond.balanceOf(bob), 500e18);
    }

    function test_transfer_revertIfReceiverNotEligible() public {
        vm.prank(alice);
        bond.invest(1000e6, 0);

        address stranger = makeAddr("stranger");
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(RWAToken.NotEligible.selector, stranger));
        bond.transfer(stranger, 500e18);
    }

    function test_transfer_revertIfSenderFrozen() public {
        vm.prank(alice);
        bond.invest(1000e6, 0);

        _freeze(alice);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(RWAToken.NotEligible.selector, alice));
        bond.transfer(bob, 500e18);
    }

    function test_transfer_revertIfPaused() public {
        vm.prank(alice);
        bond.invest(1000e6, 0);

        vm.prank(issuer);
        bond.pause();

        vm.prank(alice);
        vm.expectRevert();
        bond.transfer(bob, 500e18);
    }

    // ============================
    // Rate Limits
    // ============================

    function test_investRateLimit() public {
        vm.prank(issuer);
        bond.setDailyInvestLimit(5000e6);

        vm.prank(alice);
        bond.invest(3000e6, 0);

        vm.prank(alice);
        bond.invest(2000e6, 0); // total 5000, at limit

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(RWAToken.DailyInvestLimitExceeded.selector, 0));
        bond.invest(1e6, 0); // exceeds
    }

    function test_investRateLimit_epochReset() public {
        vm.prank(issuer);
        bond.setDailyInvestLimit(5000e6);

        vm.prank(alice);
        bond.invest(5000e6, 0); // fill the limit

        // Advance 1 day
        vm.warp(block.timestamp + 1 days);
        _updateNAV(1e18); // refresh NAV so it's not stale

        vm.prank(alice);
        bond.invest(5000e6, 0); // works again after epoch reset
    }

    function test_redeemRateLimit() public {
        vm.prank(alice);
        bond.invest(10_000e6, 0);

        vm.prank(issuer);
        bond.setDailyRedeemLimit(5000e18);

        vm.prank(alice);
        bond.redeem(5000e18, 0);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(RWAToken.DailyRedeemLimitExceeded.selector, 0));
        bond.redeem(1e18, 0);
    }

    function test_remainingCapacity() public {
        vm.prank(issuer);
        bond.setDailyInvestLimit(5000e6);

        assertEq(bond.getRemainingInvestCapacity(), 5000e6);

        vm.prank(alice);
        bond.invest(3000e6, 0);

        assertEq(bond.getRemainingInvestCapacity(), 2000e6);
    }

    // ============================
    // Admin
    // ============================

    function test_adminMint() public {
        vm.prank(issuer);
        bond.mint(alice, 500e18);

        assertEq(bond.balanceOf(alice), 500e18);
    }

    function test_adminBurn() public {
        vm.prank(alice);
        bond.invest(1000e6, 0);

        vm.prank(issuer);
        bond.burn(alice, 500e18);

        assertEq(bond.balanceOf(alice), 500e18);
    }

    function test_adminMint_revertIfNotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        bond.mint(alice, 500e18);
    }

    function test_withdrawAndDepositPaymentTokens() public {
        vm.prank(alice);
        bond.invest(1000e6, 0);

        // Withdraw
        vm.prank(issuer);
        bond.withdrawPaymentTokens(issuer, 1000e6);
        assertEq(usdc.balanceOf(issuer), 1000e6);
        assertEq(usdc.balanceOf(address(bond)), 0);

        // Deposit back
        vm.startPrank(issuer);
        usdc.approve(address(bond), 1000e6);
        bond.depositPaymentTokens(1000e6);
        vm.stopPrank();
        assertEq(usdc.balanceOf(address(bond)), 1000e6);
    }

    // ============================
    // Bond-specific
    // ============================

    function test_bondMetadata() public view {
        assertEq(bond.couponRateBps(), COUPON_BPS);
        assertEq(bond.faceValue(), FACE_VALUE);
        assertEq(bond.assetType(), "BOND");
    }

    function test_isMatured() public {
        assertFalse(bond.isMatured());

        vm.warp(block.timestamp + MATURITY);
        assertTrue(bond.isMatured());
    }

    // ============================
    // Views
    // ============================

    function test_getTokenValue() public {
        vm.prank(alice);
        bond.invest(1000e6, 0);

        assertEq(bond.getTokenValue(1000e18), 1000e6);

        _updateNAV(1.05e18);
        assertEq(bond.getTokenValue(1000e18), 1050e6);
    }

    // ============================
    // Helpers
    // ============================

    function _whitelist(address account) internal {
        address[] memory accounts = new address[](1);
        accounts[0] = account;
        vm.prank(complianceOfficer);
        registry.addToWhitelist(accounts);
    }

    function _freeze(address account) internal {
        address[] memory accounts = new address[](1);
        accounts[0] = account;
        vm.prank(complianceOfficer);
        registry.freezeAddress(accounts);
    }

    function _updateNAV(uint256 nav) internal {
        vm.prank(oracleUpdater);
        oracle.updateNAV(nav);
    }
}