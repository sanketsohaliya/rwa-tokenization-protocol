// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title NAVOracle
 * @notice Stores the NAV (Net Asset Value) per token for an RWA asset.
 * @dev NAV can only increase (yield accrual). Includes staleness checks so
 *      invest/redeem revert if the price hasn't been updated recently.
 */
contract NAVOracle is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    // --- Storage ---
    uint256 public navPerToken;
    uint256 public lastUpdated;
    address public updater;
    uint256 public maxStaleness;

    // --- Events ---
    event NAVUpdated(uint256 oldNav, uint256 newNav, uint256 timestamp);
    event UpdaterChanged(address indexed newUpdater);
    event MaxStalenessChanged(uint256 newMaxStaleness);

    // --- Errors ---
    error StaleNAV();
    error NAVDecreased();
    error NotUpdater();
    error ZeroAddress();
    error ZeroValue();

    modifier onlyUpdater() {
        if (msg.sender != updater) revert NotUpdater();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the oracle.
     * @param _owner       Owner who can change updater and staleness settings.
     * @param _updater     Address authorized to update NAV (can differ from owner).
     * @param _maxStaleness Max seconds before NAV is considered stale (e.g. 90000 = 25h).
     */
    function initialize(
        address _owner,
        address _updater,
        uint256 _maxStaleness
    ) external initializer {
        if (_owner == address(0) || _updater == address(0)) revert ZeroAddress();
        if (_maxStaleness == 0) revert ZeroValue();

        __Ownable_init(_owner);
        __UUPSUpgradeable_init();

        updater = _updater;
        maxStaleness = _maxStaleness;
        navPerToken = 1e18; // Start at $1.00
        lastUpdated = block.timestamp;
    }

    // --- NAV Updates ---

    /**
     * @notice Updates the NAV per token. NAV can only increase.
     * @param newNavPerToken New NAV value (1e18 scale, e.g. 1.05e18 = $1.05).
     */
    function updateNAV(uint256 newNavPerToken) external onlyUpdater {
        if (newNavPerToken < navPerToken) revert NAVDecreased();

        uint256 oldNav = navPerToken;
        navPerToken = newNavPerToken;
        lastUpdated = block.timestamp;

        emit NAVUpdated(oldNav, newNavPerToken, block.timestamp);
    }

    // --- Reads ---

    /**
     * @notice Returns NAV per token without staleness check (informational use).
     */
    function getNavPerToken() external view returns (uint256) {
        return navPerToken;
    }

    /**
     * @notice Returns NAV per token, reverting if the price is stale.
     * @dev This is what RWAToken.invest() and redeem() call.
     */
    function getValidatedNavPerToken() external view returns (uint256) {
        if (block.timestamp - lastUpdated > maxStaleness) revert StaleNAV();
        return navPerToken;
    }

    /**
     * @notice Returns true if the NAV hasn't been updated within maxStaleness.
     */
    function isStale() external view returns (bool) {
        return block.timestamp - lastUpdated > maxStaleness;
    }

    // --- Admin ---

    /**
     * @notice Changes the authorized NAV updater address.
     */
    function setUpdater(address _updater) external onlyOwner {
        if (_updater == address(0)) revert ZeroAddress();
        updater = _updater;
        emit UpdaterChanged(_updater);
    }

    /**
     * @notice Changes the max staleness duration.
     */
    function setMaxStaleness(uint256 _maxStaleness) external onlyOwner {
        if (_maxStaleness == 0) revert ZeroValue();
        maxStaleness = _maxStaleness;
        emit MaxStalenessChanged(_maxStaleness);
    }

    // --- UUPS ---

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}