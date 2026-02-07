// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {RWAToken} from "./RWAToken.sol";

/**
 * @title BondToken
 * @notice Tokenized bond with maturity date, coupon rate, and face value.
 */
contract BondToken is RWAToken {
    uint256 public maturityDate;
    uint256 public couponRateBps;
    uint256 public faceValue;

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
        uint256 _maturityDate,
        uint256 _couponRateBps,
        uint256 _faceValue
    ) external initializer {
        __RWAToken_init(name, symbol, _complianceRegistry, _navOracle, _paymentToken, issuer);
        maturityDate = _maturityDate;
        couponRateBps = _couponRateBps;
        faceValue = _faceValue;
    }

    function isMatured() external view returns (bool) {
        return block.timestamp >= maturityDate;
    }

    function assetType() external pure override returns (string memory) {
        return "BOND";
    }
}