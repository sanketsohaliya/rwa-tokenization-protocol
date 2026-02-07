// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {RWAToken} from "./RWAToken.sol";

/**
 * @title RealEstateToken
 * @notice Tokenized real estate with property metadata and valuation tracking.
 */
contract RealEstateToken is RWAToken {
    string public propertyId;
    string public jurisdiction;
    uint256 public totalValuation;
    uint256 public rentalYieldBps;

    event ValuationUpdated(uint256 oldValuation, uint256 newValuation);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory name,
        string memory symbol,
        address _complianceRegistry,
        address _navOracle,
        address _paymentToken,
        address issuer,
        string memory _propertyId,
        string memory _jurisdiction,
        uint256 _totalValuation,
        uint256 _rentalYieldBps
    ) external initializer {
        __RWAToken_init(name, symbol, _complianceRegistry, _navOracle, _paymentToken, issuer);
        propertyId = _propertyId;
        jurisdiction = _jurisdiction;
        totalValuation = _totalValuation;
        rentalYieldBps = _rentalYieldBps;
    }

    function updateValuation(uint256 newValuation) external onlyOwner {
        uint256 old = totalValuation;
        totalValuation = newValuation;
        emit ValuationUpdated(old, newValuation);
    }

    function assetType() external pure override returns (string memory) {
        return "REAL_ESTATE";
    }
}