// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {ComplianceRegistry} from "../compliance/ComplianceRegistry.sol";
import {NAVOracle} from "../oracle/NAVOracle.sol";
import {BondToken} from "../token/BondToken.sol";
import {RealEstateToken} from "../token/RealEstateToken.sol";
import {CommodityToken} from "../token/CommodityToken.sol";

/**
 * @title AssetFactory
 * @notice Deploys RWA asset triplets (ComplianceRegistry + Token + NAVOracle) as UUPS proxies.
 * @dev Implementations are deployed once; each new asset is 3 cheap proxy deploys.
 *      msg.sender of create* functions becomes the token owner (issuer).
 */
contract AssetFactory is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    // --- Implementation addresses ---
    address public bondImpl;
    address public realEstateImpl;
    address public commodityImpl;
    address public complianceRegistryImpl;
    address public navOracleImpl;

    // --- Deployed assets registry ---
    struct DeployedAsset {
        address token;
        address complianceRegistry;
        address navOracle;
        string assetType;
    }
    DeployedAsset[] public deployedAssets;

    // --- Events ---
    event AssetCreated(
        address indexed token,
        address complianceRegistry,
        address navOracle,
        string assetType
    );
    event BondImplUpdated(address indexed newImpl);
    event RealEstateImplUpdated(address indexed newImpl);
    event CommodityImplUpdated(address indexed newImpl);
    event ComplianceRegistryImplUpdated(address indexed newImpl);
    event NavOracleImplUpdated(address indexed newImpl);

    // --- Errors ---
    error ZeroAddress();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _bondImpl,
        address _realEstateImpl,
        address _commodityImpl,
        address _complianceRegistryImpl,
        address _navOracleImpl
    ) external initializer {
        if (
            _bondImpl == address(0) ||
            _realEstateImpl == address(0) ||
            _commodityImpl == address(0) ||
            _complianceRegistryImpl == address(0) ||
            _navOracleImpl == address(0)
        ) revert ZeroAddress();

        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();

        bondImpl = _bondImpl;
        realEstateImpl = _realEstateImpl;
        commodityImpl = _commodityImpl;
        complianceRegistryImpl = _complianceRegistryImpl;
        navOracleImpl = _navOracleImpl;
    }

    // --- Create Functions ---

    function createBond(
        string memory name,
        string memory symbol,
        uint256 maturityDate,
        uint256 couponRateBps,
        uint256 faceValue,
        address paymentToken,
        address complianceOfficer,
        address oracleUpdater
    ) external returns (address token, address registry, address oracle) {
        (registry, oracle) = _deployRegistryAndOracle(complianceOfficer, oracleUpdater);

        token = address(new ERC1967Proxy(
            bondImpl,
            abi.encodeCall(BondToken.initialize, (
                name, symbol, registry, oracle, paymentToken, msg.sender,
                maturityDate, couponRateBps, faceValue
            ))
        ));

        _registerAsset(token, registry, oracle, "BOND");
    }

    function createRealEstate(
        string memory name,
        string memory symbol,
        string memory propertyId,
        string memory jurisdiction,
        uint256 totalValuation,
        uint256 rentalYieldBps,
        address paymentToken,
        address complianceOfficer,
        address oracleUpdater
    ) external returns (address token, address registry, address oracle) {
        (registry, oracle) = _deployRegistryAndOracle(complianceOfficer, oracleUpdater);

        token = address(new ERC1967Proxy(
            realEstateImpl,
            abi.encodeCall(RealEstateToken.initialize, (
                name, symbol, registry, oracle, paymentToken, msg.sender,
                propertyId, jurisdiction, totalValuation, rentalYieldBps
            ))
        ));

        _registerAsset(token, registry, oracle, "REAL_ESTATE");
    }

    function createCommodity(
        string memory name,
        string memory symbol,
        string memory commodityType,
        string memory unit_,
        uint256 backingRatio,
        address paymentToken,
        address complianceOfficer,
        address oracleUpdater
    ) external returns (address token, address registry, address oracle) {
        (registry, oracle) = _deployRegistryAndOracle(complianceOfficer, oracleUpdater);

        token = address(new ERC1967Proxy(
            commodityImpl,
            abi.encodeCall(CommodityToken.initialize, (
                name, symbol, registry, oracle, paymentToken, msg.sender,
                commodityType, unit_, backingRatio
            ))
        ));

        _registerAsset(token, registry, oracle, "COMMODITY");
    }

    // --- Internal Helpers ---

    function _deployRegistryAndOracle(
        address complianceOfficer,
        address oracleUpdater
    ) internal returns (address registry, address oracle) {
        registry = address(new ERC1967Proxy(
            complianceRegistryImpl,
            abi.encodeCall(ComplianceRegistry.initialize, (complianceOfficer))
        ));

        oracle = address(new ERC1967Proxy(
            navOracleImpl,
            abi.encodeCall(NAVOracle.initialize, (msg.sender, oracleUpdater, 90000))
        ));
    }

    function _registerAsset(
        address token,
        address registry,
        address oracle,
        string memory _assetType
    ) internal {
        deployedAssets.push(DeployedAsset({
            token: token,
            complianceRegistry: registry,
            navOracle: oracle,
            assetType: _assetType
        }));
        emit AssetCreated(token, registry, oracle, _assetType);
    }

    // --- Implementation Setters ---

    function setBondImpl(address newImpl) external onlyOwner {
        if (newImpl == address(0)) revert ZeroAddress();
        bondImpl = newImpl;
        emit BondImplUpdated(newImpl);
    }

    function setRealEstateImpl(address newImpl) external onlyOwner {
        if (newImpl == address(0)) revert ZeroAddress();
        realEstateImpl = newImpl;
        emit RealEstateImplUpdated(newImpl);
    }

    function setCommodityImpl(address newImpl) external onlyOwner {
        if (newImpl == address(0)) revert ZeroAddress();
        commodityImpl = newImpl;
        emit CommodityImplUpdated(newImpl);
    }

    function setComplianceRegistryImpl(address newImpl) external onlyOwner {
        if (newImpl == address(0)) revert ZeroAddress();
        complianceRegistryImpl = newImpl;
        emit ComplianceRegistryImplUpdated(newImpl);
    }

    function setNavOracleImpl(address newImpl) external onlyOwner {
        if (newImpl == address(0)) revert ZeroAddress();
        navOracleImpl = newImpl;
        emit NavOracleImplUpdated(newImpl);
    }

    // --- Views ---

    function getDeployedAssetsCount() external view returns (uint256) {
        return deployedAssets.length;
    }

    // --- UUPS ---

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}