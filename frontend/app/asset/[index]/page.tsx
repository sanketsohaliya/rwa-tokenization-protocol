"use client";

import { useParams } from "next/navigation";
import Link from "next/link";
import { useAccount, useReadContract } from "wagmi";
import { assetFactoryAbi, navOracleAbi, rwaTokenAbi, bondTokenAbi, realEstateTokenAbi, commodityTokenAbi } from "@/lib/abi";
import { FACTORY_ADDRESS } from "@/lib/wagmi";
import {
  formatNAV,
  formatTokens,
  formatUSDC,
  formatBps,
  formatTimestamp,
  shortenAddress,
  assetTypeLabel,
  assetTypeBadgeClasses,
} from "@/lib/utils";
import { InvestRedeemPanel } from "@/components/invest-redeem-panel";
import { CompliancePanel } from "@/components/compliance-panel";
import { OraclePanel } from "@/components/oracle-panel";

export default function AssetDetailPage() {
  const params = useParams();
  const index = Number(params.index);
  const { address } = useAccount();

  // Fetch the deployed asset triplet from factory
  const { data: assetData, isLoading } = useReadContract({
    address: FACTORY_ADDRESS,
    abi: assetFactoryAbi,
    functionName: "deployedAssets",
    args: [BigInt(index)],
    query: { enabled: !isNaN(index) },
  });

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-20">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-blue-500 border-t-transparent" />
      </div>
    );
  }

  if (!assetData) {
    return (
      <div className="py-20 text-center">
        <p className="text-lg text-slate-400">Asset not found.</p>
        <Link href="/" className="mt-4 inline-block text-blue-400 hover:text-blue-300">
          Back to Dashboard
        </Link>
      </div>
    );
  }

  const [tokenAddress, registryAddress, oracleAddress, assetType] =
    assetData as [string, string, string, string];

  const token = tokenAddress as `0x${string}`;
  const registry = registryAddress as `0x${string}`;
  const oracle = oracleAddress as `0x${string}`;

  return (
    <div>
      {/* Back link */}
      <Link
        href="/"
        className="mb-6 inline-flex items-center gap-1 text-sm text-slate-400 hover:text-white transition-colors"
      >
        &larr; Back to Dashboard
      </Link>

      {/* Header */}
      <AssetHeader token={token} oracle={oracle} assetType={assetType} userAddress={address} />

      {/* Main content grid */}
      <div className="mt-8 grid grid-cols-1 gap-6 lg:grid-cols-2">
        {/* Left: Invest/Redeem */}
        <InvestRedeemSection token={token} oracle={oracle} />

        {/* Right: Asset-specific metadata */}
        <AssetMetadata token={token} assetType={assetType} />
      </div>

      {/* Bottom panels */}
      <div className="mt-6 grid grid-cols-1 gap-6 lg:grid-cols-2">
        <CompliancePanel registryAddress={registry} />
        <OraclePanel oracleAddress={oracle} />
      </div>
    </div>
  );
}

// ---- Sub-components ----

function AssetHeader({
  token,
  oracle,
  assetType,
  userAddress,
}: {
  token: `0x${string}`;
  oracle: `0x${string}`;
  assetType: string;
  userAddress?: `0x${string}`;
}) {
  const { data: name } = useReadContract({ address: token, abi: rwaTokenAbi, functionName: "name" });
  const { data: symbol } = useReadContract({ address: token, abi: rwaTokenAbi, functionName: "symbol" });
  const { data: totalSupply } = useReadContract({ address: token, abi: rwaTokenAbi, functionName: "totalSupply" });
  const { data: nav } = useReadContract({ address: oracle, abi: navOracleAbi, functionName: "navPerToken" });
  const { data: owner } = useReadContract({ address: token, abi: rwaTokenAbi, functionName: "owner" });
  const { data: paused } = useReadContract({ address: token, abi: rwaTokenAbi, functionName: "paused" });
  const { data: balance } = useReadContract({
    address: token,
    abi: rwaTokenAbi,
    functionName: "balanceOf",
    args: userAddress ? [userAddress] : undefined,
    query: { enabled: !!userAddress },
  });
  const { data: tokenValue } = useReadContract({
    address: token,
    abi: rwaTokenAbi,
    functionName: "getTokenValue",
    args: balance && balance > 0n ? [balance] : undefined,
    query: { enabled: !!balance && balance > 0n },
  });

  return (
    <div className="rounded-xl border border-slate-800 bg-slate-900/50 p-6">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <div className="flex items-center gap-3">
            <h1 className="text-2xl font-bold text-white">
              {name ?? "Loading..."}{" "}
              <span className="text-slate-500">({symbol ?? "..."})</span>
            </h1>
            <span
              className={`inline-flex rounded-full border px-2.5 py-0.5 text-xs font-medium ${assetTypeBadgeClasses(assetType)}`}
            >
              {assetTypeLabel(assetType)}
            </span>
            {paused && (
              <span className="inline-flex rounded-full border border-red-500/30 bg-red-500/20 px-2.5 py-0.5 text-xs font-medium text-red-400">
                Paused
              </span>
            )}
          </div>
          <p className="mt-2 text-sm text-slate-500">
            Token: <span className="font-mono text-slate-400">{token}</span>
          </p>
          <p className="mt-1 text-sm text-slate-500">
            Owner: <span className="font-mono text-slate-400">{owner ? shortenAddress(owner) : "..."}</span>
          </p>
        </div>
      </div>

      {/* Stats Row */}
      <div className="mt-6 grid grid-cols-2 gap-3 sm:grid-cols-4">
        <StatBox label="NAV / Token" value={nav !== undefined ? formatNAV(nav) : "..."} />
        <StatBox label="Total Supply" value={totalSupply !== undefined ? formatTokens(totalSupply) : "..."} />
        <StatBox
          label="Your Balance"
          value={userAddress ? (balance !== undefined ? formatTokens(balance) : "...") : "--"}
        />
        <StatBox
          label="Your Value"
          value={
            userAddress && balance && balance > 0n && tokenValue !== undefined
              ? `$${formatUSDC(tokenValue)}`
              : "--"
          }
        />
      </div>
    </div>
  );
}

function StatBox({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg bg-slate-800/50 p-3">
      <p className="text-xs text-slate-500">{label}</p>
      <p className="mt-1 text-sm font-semibold text-white">{value}</p>
    </div>
  );
}

function InvestRedeemSection({
  token,
  oracle,
}: {
  token: `0x${string}`;
  oracle: `0x${string}`;
}) {
  const { data: paymentToken } = useReadContract({
    address: token,
    abi: rwaTokenAbi,
    functionName: "paymentToken",
  });

  if (!paymentToken) {
    return (
      <div className="flex items-center justify-center rounded-xl border border-slate-800 bg-slate-900/50 p-12">
        <div className="h-6 w-6 animate-spin rounded-full border-2 border-blue-500 border-t-transparent" />
      </div>
    );
  }

  return (
    <InvestRedeemPanel
      tokenAddress={token}
      paymentTokenAddress={paymentToken as `0x${string}`}
      navOracleAddress={oracle}
    />
  );
}

function AssetMetadata({
  token,
  assetType,
}: {
  token: `0x${string}`;
  assetType: string;
}) {
  return (
    <div className="rounded-xl border border-slate-800 bg-slate-900/50 p-6">
      <h3 className="mb-4 text-lg font-semibold text-white">
        {assetTypeLabel(assetType)} Details
      </h3>
      {assetType === "BOND" && <BondMetadata token={token} />}
      {assetType === "REAL_ESTATE" && <RealEstateMetadata token={token} />}
      {assetType === "COMMODITY" && <CommodityMetadata token={token} />}
    </div>
  );
}

function BondMetadata({ token }: { token: `0x${string}` }) {
  const { data: maturityDate } = useReadContract({ address: token, abi: bondTokenAbi, functionName: "maturityDate" });
  const { data: couponBps } = useReadContract({ address: token, abi: bondTokenAbi, functionName: "couponRateBps" });
  const { data: faceValue } = useReadContract({ address: token, abi: bondTokenAbi, functionName: "faceValue" });
  const { data: isMatured } = useReadContract({ address: token, abi: bondTokenAbi, functionName: "isMatured" });

  return (
    <div className="space-y-3">
      <MetaRow label="Maturity Date" value={maturityDate !== undefined ? formatTimestamp(maturityDate) : "..."} />
      <MetaRow
        label="Status"
        value={
          isMatured !== undefined ? (
            <span className={isMatured ? "text-amber-400" : "text-emerald-400"}>
              {isMatured ? "Matured" : "Active"}
            </span>
          ) : (
            "..."
          )
        }
      />
      <MetaRow label="Coupon Rate" value={couponBps !== undefined ? formatBps(couponBps) : "..."} />
      <MetaRow label="Face Value" value={faceValue !== undefined ? `$${formatUSDC(faceValue)}` : "..."} />
    </div>
  );
}

function RealEstateMetadata({ token }: { token: `0x${string}` }) {
  const { data: propertyId } = useReadContract({ address: token, abi: realEstateTokenAbi, functionName: "propertyId" });
  const { data: jurisdiction } = useReadContract({ address: token, abi: realEstateTokenAbi, functionName: "jurisdiction" });
  const { data: totalValuation } = useReadContract({ address: token, abi: realEstateTokenAbi, functionName: "totalValuation" });
  const { data: rentalYieldBps } = useReadContract({ address: token, abi: realEstateTokenAbi, functionName: "rentalYieldBps" });

  return (
    <div className="space-y-3">
      <MetaRow label="Property ID" value={propertyId ?? "..."} />
      <MetaRow label="Jurisdiction" value={jurisdiction ?? "..."} />
      <MetaRow label="Total Valuation" value={totalValuation !== undefined ? `$${formatUSDC(totalValuation)}` : "..."} />
      <MetaRow label="Rental Yield" value={rentalYieldBps !== undefined ? formatBps(rentalYieldBps) : "..."} />
    </div>
  );
}

function CommodityMetadata({ token }: { token: `0x${string}` }) {
  const { data: commodityType } = useReadContract({ address: token, abi: commodityTokenAbi, functionName: "commodityType" });
  const { data: unit } = useReadContract({ address: token, abi: commodityTokenAbi, functionName: "unit" });
  const { data: backingRatio } = useReadContract({ address: token, abi: commodityTokenAbi, functionName: "backingRatio" });

  return (
    <div className="space-y-3">
      <MetaRow label="Commodity" value={commodityType ?? "..."} />
      <MetaRow label="Unit" value={unit ?? "..."} />
      <MetaRow
        label="Backing Ratio"
        value={
          backingRatio !== undefined
            ? `${(Number(backingRatio) / 1e18).toFixed(4)}:1`
            : "..."
        }
      />
    </div>
  );
}

function MetaRow({
  label,
  value,
}: {
  label: string;
  value: React.ReactNode;
}) {
  return (
    <div className="flex items-center justify-between rounded-lg bg-slate-800/50 px-4 py-3">
      <span className="text-sm text-slate-400">{label}</span>
      <span className="text-sm font-medium text-white">{value}</span>
    </div>
  );
}
