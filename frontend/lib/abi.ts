import { parseAbi } from "viem";

// ─── Shared RWA Token functions (inherited by Bond, RealEstate, Commodity) ────
const rwaTokenFunctions = [
  "function name() view returns (string)",
  "function symbol() view returns (string)",
  "function decimals() view returns (uint8)",
  "function totalSupply() view returns (uint256)",
  "function balanceOf(address account) view returns (uint256)",
  "function transfer(address to, uint256 amount) returns (bool)",
  "function approve(address spender, uint256 amount) returns (bool)",
  "function allowance(address owner, address spender) view returns (uint256)",
  "function owner() view returns (address)",
  "function paused() view returns (bool)",
  "function complianceRegistry() view returns (address)",
  "function navOracle() view returns (address)",
  "function paymentToken() view returns (address)",
  "function paymentTokenScale() view returns (uint256)",
  "function dailyInvestLimit() view returns (uint256)",
  "function dailyRedeemLimit() view returns (uint256)",
  "function assetType() view returns (string)",
  "function invest(uint256 paymentAmount, uint256 minTokensOut) returns (uint256)",
  "function redeem(uint256 tokenAmount, uint256 minPaymentOut) returns (uint256)",
  "function getTokenValue(uint256 tokenAmount) view returns (uint256)",
  "function getRemainingInvestCapacity() view returns (uint256)",
  "function getRemainingRedeemCapacity() view returns (uint256)",
  "function mint(address to, uint256 amount)",
  "function burn(address from, uint256 amount)",
  "function pause()",
  "function unpause()",
  "function setDailyInvestLimit(uint256 limit)",
  "function setDailyRedeemLimit(uint256 limit)",
  "function withdrawPaymentTokens(address to, uint256 amount)",
  "function depositPaymentTokens(uint256 amount)",
] as const;

// ─── Bond Token ───────────────────────────────────────────────────────────────
export const bondTokenAbi = parseAbi([
  ...rwaTokenFunctions,
  "function maturityDate() view returns (uint256)",
  "function couponRateBps() view returns (uint256)",
  "function faceValue() view returns (uint256)",
  "function isMatured() view returns (bool)",
]);

// ─── Real Estate Token ────────────────────────────────────────────────────────
export const realEstateTokenAbi = parseAbi([
  ...rwaTokenFunctions,
  "function propertyId() view returns (string)",
  "function jurisdiction() view returns (string)",
  "function totalValuation() view returns (uint256)",
  "function rentalYieldBps() view returns (uint256)",
  "function updateValuation(uint256 newValuation)",
]);

// ─── Commodity Token ──────────────────────────────────────────────────────────
export const commodityTokenAbi = parseAbi([
  ...rwaTokenFunctions,
  "function commodityType() view returns (string)",
  "function unit() view returns (string)",
  "function backingRatio() view returns (uint256)",
  "function updateBackingRatio(uint256 newRatio)",
]);

// ─── General RWA Token (for when type is unknown) ─────────────────────────────
export const rwaTokenAbi = parseAbi([...rwaTokenFunctions]);

// ─── Asset Factory ────────────────────────────────────────────────────────────
export const assetFactoryAbi = parseAbi([
  "function getDeployedAssetsCount() view returns (uint256)",
  "function deployedAssets(uint256 index) view returns (address token, address complianceRegistry, address navOracle, string assetType)",
  "function createBond(string name, string symbol, uint256 maturityDate, uint256 couponRateBps, uint256 faceValue, address paymentToken, address complianceOfficer, address oracleUpdater) returns (address token, address registry, address oracle)",
  "function createRealEstate(string name, string symbol, string propertyId, string jurisdiction, uint256 totalValuation, uint256 rentalYieldBps, address paymentToken, address complianceOfficer, address oracleUpdater) returns (address token, address registry, address oracle)",
  "function createCommodity(string name, string symbol, string commodityType, string unit_, uint256 backingRatio, address paymentToken, address complianceOfficer, address oracleUpdater) returns (address token, address registry, address oracle)",
  "function owner() view returns (address)",
  "function bondImpl() view returns (address)",
  "function realEstateImpl() view returns (address)",
  "function commodityImpl() view returns (address)",
  "function complianceRegistryImpl() view returns (address)",
  "function navOracleImpl() view returns (address)",
]);

// ─── Compliance Registry ──────────────────────────────────────────────────────
export const complianceRegistryAbi = parseAbi([
  "function addToWhitelist(address[] accounts)",
  "function removeFromWhitelist(address[] accounts)",
  "function isWhitelisted(address account) view returns (bool)",
  "function freezeAddress(address[] accounts)",
  "function unfreezeAddress(address[] accounts)",
  "function isFrozen(address account) view returns (bool)",
  "function isEligible(address account) view returns (bool)",
  "function owner() view returns (address)",
]);

// ─── NAV Oracle ───────────────────────────────────────────────────────────────
export const navOracleAbi = parseAbi([
  "function navPerToken() view returns (uint256)",
  "function lastUpdated() view returns (uint256)",
  "function updater() view returns (address)",
  "function maxStaleness() view returns (uint256)",
  "function owner() view returns (address)",
  "function getNavPerToken() view returns (uint256)",
  "function getValidatedNavPerToken() view returns (uint256)",
  "function isStale() view returns (bool)",
  "function updateNAV(uint256 newNavPerToken)",
  "function setUpdater(address _updater)",
  "function setMaxStaleness(uint256 _maxStaleness)",
]);

// ─── ERC-20 (for payment token interactions) ─────────────────────────────────
export const erc20Abi = parseAbi([
  "function name() view returns (string)",
  "function symbol() view returns (string)",
  "function decimals() view returns (uint8)",
  "function totalSupply() view returns (uint256)",
  "function balanceOf(address account) view returns (uint256)",
  "function allowance(address owner, address spender) view returns (uint256)",
  "function approve(address spender, uint256 amount) returns (bool)",
  "function transfer(address to, uint256 amount) returns (bool)",
]);

// ─── Helper: get token ABI by asset type ──────────────────────────────────────
export function getTokenAbi(assetType: string) {
  switch (assetType) {
    case "BOND":
      return bondTokenAbi;
    case "REAL_ESTATE":
      return realEstateTokenAbi;
    case "COMMODITY":
      return commodityTokenAbi;
    default:
      return rwaTokenAbi;
  }
}
