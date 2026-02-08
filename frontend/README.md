# RWA Tokenization Protocol – Frontend

A Next.js dashboard for the RWA Tokenization Protocol. Manage tokenized bonds, real estate, and commodities with compliance-gated transfers and NAV-based pricing on the Sepolia testnet.

## Prerequisites

- Node.js 18+
- A browser wallet (MetaMask) connected to **Sepolia**
- Deployed contracts (see the root repo deploy script)

## Setup

```bash
# Install dependencies
npm install

# Copy the example env and fill in your deployed addresses
cp .env.local.example .env.local

# Start the dev server
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) in your browser.

## Environment Variables

| Variable | Description |
|---|---|
| `NEXT_PUBLIC_FACTORY_ADDRESS` | AssetFactory **proxy** address on Sepolia |
| `NEXT_PUBLIC_USDC_ADDRESS` | Mock USDC token address on Sepolia |

## Tech Stack

- **Next.js** (App Router)
- **Wagmi v2** + **Viem** – wallet connection and contract interactions
- **TanStack React Query** – data fetching and caching
- **Tailwind CSS** – styling
