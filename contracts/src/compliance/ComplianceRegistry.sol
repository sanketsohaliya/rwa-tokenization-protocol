// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title ComplianceRegistry
 * @notice Manages KYC whitelist and address freezing for RWA tokens.
 * @dev Owned by a compliance officer. Tokens call `isEligible()` to gate transfers.
 *      An address must be whitelisted AND not frozen to be eligible.
 */
contract ComplianceRegistry is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    // --- Storage ---
    mapping(address => bool) private _whitelist;
    mapping(address => bool) private _frozen;

    // --- Events ---
    event AddedToWhitelist(address indexed account);
    event RemovedFromWhitelist(address indexed account);
    event AddressFrozen(address indexed account);
    event AddressUnfrozen(address indexed account);

    // --- Errors ---
    error ZeroAddress();
    error AlreadyWhitelisted(address account);
    error NotWhitelisted(address account);
    error AlreadyFrozen(address account);
    error NotFrozen(address account);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the registry with a compliance officer as owner.
     * @param complianceOfficer Address that will manage the whitelist and freeze list.
     */
    function initialize(address complianceOfficer) external initializer {
        if (complianceOfficer == address(0)) revert ZeroAddress();
        __Ownable_init(complianceOfficer);
        __UUPSUpgradeable_init();
    }

    // --- Whitelist Management ---

    /**
     * @notice Adds accounts to the KYC whitelist.
     * @param accounts Array of addresses to whitelist.
     */
    function addToWhitelist(address[] calldata accounts) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            if (accounts[i] == address(0)) revert ZeroAddress();
            if (_whitelist[accounts[i]]) revert AlreadyWhitelisted(accounts[i]);
            _whitelist[accounts[i]] = true;
            emit AddedToWhitelist(accounts[i]);
        }
    }

    /**
     * @notice Removes accounts from the KYC whitelist.
     * @param accounts Array of addresses to remove.
     */
    function removeFromWhitelist(address[] calldata accounts) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            if (!_whitelist[accounts[i]]) revert NotWhitelisted(accounts[i]);
            _whitelist[accounts[i]] = false;
            emit RemovedFromWhitelist(accounts[i]);
        }
    }

    /**
     * @notice Checks if an address is on the KYC whitelist.
     */
    function isWhitelisted(address account) external view returns (bool) {
        return _whitelist[account];
    }

    // --- Freeze Management ---

    /**
     * @notice Freezes accounts (sanctions, fraud, compromised keys).
     * @dev A frozen address is blocked from all token operations even if whitelisted.
     * @param accounts Array of addresses to freeze.
     */
    function freezeAddress(address[] calldata accounts) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            if (accounts[i] == address(0)) revert ZeroAddress();
            if (_frozen[accounts[i]]) revert AlreadyFrozen(accounts[i]);
            _frozen[accounts[i]] = true;
            emit AddressFrozen(accounts[i]);
        }
    }

    /**
     * @notice Unfreezes previously frozen accounts.
     * @param accounts Array of addresses to unfreeze.
     */
    function unfreezeAddress(address[] calldata accounts) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            if (!_frozen[accounts[i]]) revert NotFrozen(accounts[i]);
            _frozen[accounts[i]] = false;
            emit AddressUnfrozen(accounts[i]);
        }
    }

    /**
     * @notice Checks if an address is frozen.
     */
    function isFrozen(address account) external view returns (bool) {
        return _frozen[account];
    }

    // --- Combined Check ---

    /**
     * @notice Returns true if the account is whitelisted AND not frozen.
     * @dev This is the function that RWA tokens call to gate transfers and invest/redeem.
     */
    function isEligible(address account) external view returns (bool) {
        return _whitelist[account] && !_frozen[account];
    }

    // --- UUPS ---

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}