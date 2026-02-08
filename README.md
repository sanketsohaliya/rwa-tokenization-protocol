# RWA Tokenization Protocol

A full-stack protocol for tokenizing Real World Assets (RWA) on the Ethereum blockchain. The platform enables issuers to create compliance-gated, NAV-accruing ERC-20 tokens representing bonds, real estate, and commodities — with a Next.js frontend for managing the entire lifecycle.

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                        Frontend (Next.js)                    │
│  Dashboard · Create Asset · Invest/Redeem · Compliance · NAV │
└────────────────────────────┬─────────────────────────────────┘
                             │  wagmi / viem
┌────────────────────────────▼─────────────────────────────────┐
│                       AssetFactory (UUPS Proxy)              │
│  Deploys triplets: ComplianceRegistry + Token + NAVOracle    │
└──┬──────────────────────┬──────────────────────┬─────────────┘
   │                      │                      │
   ▼                      ▼                      ▼
┌──────────────┐  ┌───────────────┐  ┌───────────────────────┐
│ RWA Token    │  │ Compliance    │  │ NAV Oracle            │
│ (ERC-20)     │  │ Registry      │  │                       │
│              │  │               │  │ • Price feed           │
│ • BondToken  │  │ • KYC whitelist│  │ • Staleness checks   │
│ • RealEstate │  │ • Freeze/thaw │  │ • Monotonic NAV      │
│ • Commodity  │  │ • Eligibility │  │                       │
└──────────────┘  └───────────────┘  └───────────────────────┘
```

## Smart Contracts

All contracts are **upgradeable** (UUPS proxy pattern) and built with OpenZeppelin v5.

| Contract | Description |
|---|---|
| **`RWAToken`** | Abstract ERC-20 base with compliance-gated transfers, NAV-based invest/redeem, slippage protection, and daily rate limits. |
| **`BondToken`** | Tokenized bond — maturity date, coupon rate (bps), face value. |
| **`RealEstateToken`** | Tokenized real estate — property ID, jurisdiction, valuation, rental yield. |
| **`CommodityToken`** | Tokenized commodity — commodity type, unit, backing ratio. |
| **`ComplianceRegistry`** | KYC whitelist and address freeze management. Tokens call `isEligible()` to gate transfers. |
| **`NAVOracle`** | Stores NAV per token (monotonically increasing). Includes staleness checks so invest/redeem revert on stale prices. |
| **`AssetFactory`** | One-click deployment of asset triplets (Token + ComplianceRegistry + NAVOracle) as cheap ERC-1967 proxies. |
| **`MockUSDC`** | Test stablecoin (6 decimals) for local development. |

### Key Features

- **Compliance-gated transfers** — every transfer, mint, and invest/redeem is checked against the ComplianceRegistry
- **NAV-based pricing** — invest and redeem at oracle-provided NAV with automatic decimal scaling (e.g. 6-decimal USDC to 18-decimal tokens)
- **Slippage protection** — `minTokensOut` / `minPaymentOut` parameters on invest/redeem
- **Daily rate limits** — configurable daily caps on invest and redeem volumes
- **Pausability** — owner can halt all operations in emergencies
- **UUPS upgradeable** — all contracts are upgradeable via the UUPS proxy pattern

## Tech Stack

| Layer | Technology |
|---|---|
| Smart Contracts | Solidity 0.8.28, Foundry, OpenZeppelin Contracts Upgradeable v5 |
| Frontend | Next.js 16, React 19, TypeScript, Tailwind CSS v4 |
| Web3 Integration | wagmi v3, viem v2, TanStack Query |
| Testing | Foundry (forge test) |
| Deployment | Foundry scripts (forge script) |

## Project Structure

```
rwa-tokenization-protocol/
├── contracts/
│   ├── src/
│   │   ├── compliance/
│   │   │   └── ComplianceRegistry.sol
│   │   ├── factory/
│   │   │   └── AssetFactory.sol
│   │   ├── mock/
│   │   │   └── MockUSDC.sol
│   │   ├── oracle/
│   │   │   └── NAVOracle.sol
│   │   └── token/
│   │       ├── RWAToken.sol          # Abstract base
│   │       ├── BondToken.sol
│   │       ├── RealEstateToken.sol
│   │       └── CommodityToken.sol
│   ├── test/                          # Foundry tests
│   ├── script/
│   │   └── Deploy.s.sol              # Full deployment script
│   └── foundry.toml
├── frontend/
│   ├── app/                           # Next.js App Router
│   │   ├── page.tsx                   # Dashboard — lists all deployed assets
│   │   ├── factory/page.tsx           # Create new RWA assets
│   │   └── asset/[index]/page.tsx     # Asset detail — invest, redeem, compliance, NAV
│   ├── components/
│   │   ├── asset-card.tsx             # Asset summary card
│   │   ├── create-asset-form.tsx      # Multi-type asset creation form
│   │   ├── invest-redeem-panel.tsx    # Invest/redeem UI with slippage
│   │   ├── compliance-panel.tsx       # Whitelist/freeze management
│   │   ├── oracle-panel.tsx           # NAV oracle update UI
│   │   ├── navbar.tsx                 # Navigation bar
│   │   └── providers.tsx              # wagmi + TanStack Query providers
│   ├── lib/
│   │   ├── abi.ts                     # Contract ABIs
│   │   ├── wagmi.ts                   # wagmi config + chain setup
│   │   └── utils.ts                   # Shared utilities
│   └── package.json
└── README.md
```

## Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) (forge, anvil, cast)
- [Node.js](https://nodejs.org/) >= 18
- A wallet with a private key (for deployment)

### 1. Clone and install

```bash
git clone <repository-url>
cd rwa-tokenization-protocol
```

Install contract dependencies:

```bash
cd contracts
forge install
```

Install frontend dependencies:

```bash
cd ../frontend
npm install
```

### 2. Start a local chain

```bash
anvil
```

This starts a local Ethereum node at `http://localhost:8545` with pre-funded accounts.

### 3. Deploy contracts

In a new terminal:

```bash
cd contracts
forge script script/Deploy.s.sol \
  --rpc-url http://localhost:8545 \
  --broadcast \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

The script deploys:
- MockUSDC stablecoin
- All implementation contracts
- AssetFactory (UUPS proxy)
- 15 sample assets (5 bonds, 5 real estate, 5 commodities)
- 4 sample investments with whitelist setup

Note the **AssetFactory proxy** and **MockUSDC** addresses from the console output.

### 4. Configure the frontend

```bash
cd ../frontend
cp .env.local.example .env.local   # or create .env.local manually
```

Set the deployed addresses in `frontend/.env.local`:

```env
NEXT_PUBLIC_FACTORY_ADDRESS=0x<factory-proxy-address>
NEXT_PUBLIC_USDC_ADDRESS=0x<mock-usdc-address>
```

### 5. Run the frontend

```bash
cd frontend
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) to access the dashboard.

## Testing

Run the full test suite:

```bash
cd contracts
forge test
```

Run with verbosity for detailed traces:

```bash
forge test -vvv
```

Run a specific test file:

```bash
forge test --match-path test/BondToken.t.sol
```

## Deployment Flow

The `Deploy.s.sol` script handles the complete deployment in order:

1. **MockUSDC** — test stablecoin
2. **Implementation contracts** — one of each (BondToken, RealEstateToken, CommodityToken, ComplianceRegistry, NAVOracle)
3. **AssetFactory** — deployed as a UUPS proxy, initialized with all implementation addresses
4. **Sample assets** — 15 assets created through the factory (each is a set of 3 proxies)
5. **Sample investments** — deployer is whitelisted and invests in 4 assets
6. **NAV update** — simulates a 5% yield accrual on the first bond

## Usage

### Creating an Asset (Frontend)

1. Navigate to **Create Asset**
2. Select asset type (Bond, Real Estate, or Commodity)
3. Fill in the asset-specific fields (name, symbol, metadata)
4. Set the compliance officer and oracle updater addresses
5. Submit — the factory deploys 3 proxies in a single transaction

### Investing

1. Open an asset from the dashboard
2. Enter a USDC amount and review the estimated tokens out
3. Click **Invest** — tokens are minted at the current NAV price

### Managing Compliance

1. Open an asset's detail page
2. Use the **Compliance** panel to whitelist or freeze addresses
3. Only the designated compliance officer can manage the whitelist

### Updating NAV

1. Open an asset's detail page
2. Use the **Oracle** panel to update the NAV per token
3. NAV can only increase (monotonic) and has staleness protection

## License

MIT
