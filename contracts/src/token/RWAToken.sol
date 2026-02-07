// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ComplianceRegistry} from "../compliance/ComplianceRegistry.sol";
import {NAVOracle} from "../oracle/NAVOracle.sol";

/**
 * @title RWAToken
 * @notice Abstract base ERC-20 for compliance-gated RWA tokens with NAV-accruing yield.
 * @dev Subclasses (BondToken, RealEstateToken, CommodityToken) add asset-specific metadata.
 *
 * Key features:
 *   - Compliance: transfers gated by ComplianceRegistry.isEligible()
 *   - Pausability: owner can halt all operations in emergencies
 *   - NAV-based invest/redeem: payment token <-> RWA token at oracle price
 *   - Decimal scaling: handles mismatch between payment token (e.g. 6) and RWA token (18)
 *   - Slippage protection: minOut parameters on invest/redeem
 *   - Rate limits: daily caps on invest/redeem volumes
 */
abstract contract RWAToken is
    Initializable,
    ERC20Upgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;

    // --- Storage ---
    ComplianceRegistry public complianceRegistry;
    NAVOracle public navOracle;
    IERC20 public paymentToken;
    uint256 public paymentTokenScale; // 10^(18 - paymentDecimals)

    // Rate limits
    uint256 public dailyInvestLimit; // 0 = unlimited
    uint256 public dailyRedeemLimit; // 0 = unlimited
    uint256 public currentEpochStart;
    uint256 public currentEpochInvested;
    uint256 public currentEpochRedeemed;

    // --- Events ---
    event Invested(address indexed investor, uint256 paymentAmount, uint256 tokensOut);
    event Redeemed(address indexed investor, uint256 tokenAmount, uint256 paymentOut);
    event DailyInvestLimitChanged(uint256 newLimit);
    event DailyRedeemLimitChanged(uint256 newLimit);
    event PaymentTokensWithdrawn(address indexed to, uint256 amount);
    event PaymentTokensDeposited(address indexed from, uint256 amount);

    // --- Errors ---
    error NotEligible(address account);
    error SlippageExceeded(uint256 actual, uint256 minimum);
    error InsufficientPaymentBalance(uint256 available, uint256 required);
    error DailyInvestLimitExceeded(uint256 remaining);
    error DailyRedeemLimitExceeded(uint256 remaining);
    error ZeroAmount();

    // --- Initializer ---

    /**
     * @dev Called by concrete subclass initializers.
     */
    function __RWAToken_init(
        string memory name,
        string memory symbol,
        address _complianceRegistry,
        address _navOracle,
        address _paymentToken,
        address issuer
    ) internal onlyInitializing {
        __ERC20_init(name, symbol);
        __Ownable_init(issuer);
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        complianceRegistry = ComplianceRegistry(_complianceRegistry);
        navOracle = NAVOracle(_navOracle);
        paymentToken = IERC20(_paymentToken);

        uint8 paymentDecimals = IERC20Metadata(_paymentToken).decimals();
        paymentTokenScale = 10 ** (18 - paymentDecimals);

        currentEpochStart = block.timestamp;
    }

    // --- Transfer Compliance ---

    /**
     * @dev Overrides ERC-20 _update to enforce compliance and pause.
     *   - Mint: receiver must be eligible
     *   - Transfer: both sender and receiver must be eligible
     *   - Burn: no eligibility check (admin burns for off-chain settlement)
     */
    function _update(
        address from,
        address to,
        uint256 value
    ) internal virtual override whenNotPaused {
        // Mint
        if (from == address(0)) {
            if (!complianceRegistry.isEligible(to)) revert NotEligible(to);
        }
        // Burn -- no eligibility check
        else if (to == address(0)) {
            // Allow burns without eligibility check
        }
        // Transfer
        else {
            if (!complianceRegistry.isEligible(from)) revert NotEligible(from);
            if (!complianceRegistry.isEligible(to)) revert NotEligible(to);
        }

        super._update(from, to, value);
    }

    // --- Invest / Redeem ---

    /**
     * @notice Invest payment tokens to receive RWA tokens at current NAV.
     * @param paymentAmount Amount of payment tokens (in payment token decimals, e.g. 1000e6 USDC).
     * @param minTokensOut  Minimum RWA tokens to receive (slippage protection).
     * @return tokensOut     Actual RWA tokens minted.
     */
    function invest(
        uint256 paymentAmount,
        uint256 minTokensOut
    ) external whenNotPaused nonReentrant returns (uint256 tokensOut) {
        if (paymentAmount == 0) revert ZeroAmount();
        if (!complianceRegistry.isEligible(msg.sender)) revert NotEligible(msg.sender);

        uint256 nav = navOracle.getValidatedNavPerToken();

        // Scale payment to 18 decimals, then divide by NAV
        // e.g. 1000e6 * 1e12 * 1e18 / 1e18 = 1000e18 tokens
        tokensOut = (paymentAmount * paymentTokenScale * 1e18) / nav;

        if (tokensOut < minTokensOut) revert SlippageExceeded(tokensOut, minTokensOut);

        _checkAndUpdateInvestLimit(paymentAmount);

        paymentToken.safeTransferFrom(msg.sender, address(this), paymentAmount);
        _mint(msg.sender, tokensOut);

        emit Invested(msg.sender, paymentAmount, tokensOut);
    }

    /**
     * @notice Redeem RWA tokens for payment tokens at current NAV.
     * @param tokenAmount   Amount of RWA tokens to redeem (18 decimals).
     * @param minPaymentOut Minimum payment tokens to receive (slippage protection).
     * @return paymentOut    Actual payment tokens sent.
     */
    function redeem(
        uint256 tokenAmount,
        uint256 minPaymentOut
    ) external whenNotPaused nonReentrant returns (uint256 paymentOut) {
        if (tokenAmount == 0) revert ZeroAmount();
        if (!complianceRegistry.isEligible(msg.sender)) revert NotEligible(msg.sender);

        uint256 nav = navOracle.getValidatedNavPerToken();

        // e.g. 1000e18 * 1.05e18 / 1e18 / 1e12 = 1050e6 USDC
        paymentOut = (tokenAmount * nav) / 1e18 / paymentTokenScale;

        if (paymentOut < minPaymentOut) revert SlippageExceeded(paymentOut, minPaymentOut);

        uint256 available = paymentToken.balanceOf(address(this));
        if (available < paymentOut) revert InsufficientPaymentBalance(available, paymentOut);

        _checkAndUpdateRedeemLimit(tokenAmount);

        _burn(msg.sender, tokenAmount);
        paymentToken.safeTransfer(msg.sender, paymentOut);

        emit Redeemed(msg.sender, tokenAmount, paymentOut);
    }

    // --- Rate Limits ---

    function _checkAndUpdateInvestLimit(uint256 paymentAmount) internal {
        if (dailyInvestLimit == 0) return; // unlimited

        if (block.timestamp >= currentEpochStart + 1 days) {
            currentEpochStart = block.timestamp;
            currentEpochInvested = 0;
            currentEpochRedeemed = 0;
        }

        uint256 remaining = dailyInvestLimit - currentEpochInvested;
        if (paymentAmount > remaining) revert DailyInvestLimitExceeded(remaining);
        currentEpochInvested += paymentAmount;
    }

    function _checkAndUpdateRedeemLimit(uint256 tokenAmount) internal {
        if (dailyRedeemLimit == 0) return; // unlimited

        if (block.timestamp >= currentEpochStart + 1 days) {
            currentEpochStart = block.timestamp;
            currentEpochInvested = 0;
            currentEpochRedeemed = 0;
        }

        uint256 remaining = dailyRedeemLimit - currentEpochRedeemed;
        if (tokenAmount > remaining) revert DailyRedeemLimitExceeded(remaining);
        currentEpochRedeemed += tokenAmount;
    }

    // --- Admin ---

    function mint(address to, uint256 amount) external onlyOwner whenNotPaused {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyOwner whenNotPaused {
        _burn(from, amount);
    }

    function withdrawPaymentTokens(address to, uint256 amount) external onlyOwner {
        paymentToken.safeTransfer(to, amount);
        emit PaymentTokensWithdrawn(to, amount);
    }

    function depositPaymentTokens(uint256 amount) external onlyOwner {
        paymentToken.safeTransferFrom(msg.sender, address(this), amount);
        emit PaymentTokensDeposited(msg.sender, amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setDailyInvestLimit(uint256 limit) external onlyOwner {
        dailyInvestLimit = limit;
        emit DailyInvestLimitChanged(limit);
    }

    function setDailyRedeemLimit(uint256 limit) external onlyOwner {
        dailyRedeemLimit = limit;
        emit DailyRedeemLimitChanged(limit);
    }

    // --- Views ---

    /**
     * @notice Returns the value of `tokenAmount` tokens in payment token terms.
     */
    function getTokenValue(uint256 tokenAmount) external view returns (uint256) {
        uint256 nav = navOracle.getNavPerToken();
        return (tokenAmount * nav) / 1e18 / paymentTokenScale;
    }

    /**
     * @notice Remaining invest capacity in the current epoch (in payment token units).
     */
    function getRemainingInvestCapacity() external view returns (uint256) {
        if (dailyInvestLimit == 0) return type(uint256).max;
        if (block.timestamp >= currentEpochStart + 1 days) return dailyInvestLimit;
        if (currentEpochInvested >= dailyInvestLimit) return 0;
        return dailyInvestLimit - currentEpochInvested;
    }

    /**
     * @notice Remaining redeem capacity in the current epoch (in RWA token units).
     */
    function getRemainingRedeemCapacity() external view returns (uint256) {
        if (dailyRedeemLimit == 0) return type(uint256).max;
        if (block.timestamp >= currentEpochStart + 1 days) return dailyRedeemLimit;
        if (currentEpochRedeemed >= dailyRedeemLimit) return 0;
        return dailyRedeemLimit - currentEpochRedeemed;
    }

    /**
     * @notice Returns the asset type identifier (overridden by subclasses).
     */
    function assetType() external pure virtual returns (string memory);

    // --- UUPS ---

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}