// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {RWAToken} from "./RWAToken.sol";

/**
 * @title CommodityToken
 * @notice Tokenized commodity with type, unit, and backing ratio.
 */
contract CommodityToken is RWAToken {
    string public commodityType;
    string public unit;
    uint256 public backingRatio; // 1e18 = 1:1 backing

    event BackingRatioUpdated(uint256 oldRatio, uint256 newRatio);

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
        string memory _commodityType,
        string memory _unit,
        uint256 _backingRatio
    ) external initializer {
        __RWAToken_init(name, symbol, _complianceRegistry, _navOracle, _paymentToken, issuer);
        commodityType = _commodityType;
        unit = _unit;
        backingRatio = _backingRatio;
    }

    function updateBackingRatio(uint256 newRatio) external onlyOwner {
        uint256 old = backingRatio;
        backingRatio = newRatio;
        emit BackingRatioUpdated(old, newRatio);
    }

    function assetType() external pure override returns (string memory) {
        return "COMMODITY";
    }
}