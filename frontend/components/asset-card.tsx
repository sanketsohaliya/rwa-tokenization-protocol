"use client";

import Link from "next/link";
import { useAccount, useReadContract } from "wagmi";
import { rwaTokenAbi, navOracleAbi } from "@/lib/abi";
import {
  formatNAV,
  formatTokens,
  shortenAddress,
  assetTypeLabel,
  assetTypeBadgeClasses,
} from "@/lib/utils";

interface AssetCardProps {
  index: number;
  token: `0x${string}`;
  navOracle: `0x${string}`;
  assetType: string;
}

export function AssetCard({
  index,
  token,
  navOracle,
  assetType,
}: AssetCardProps) {
  const { address } = useAccount();

  const { data: name } = useReadContract({
    address: token,
    abi: rwaTokenAbi,
    functionName: "name",
  });

  const { data: symbol } = useReadContract({
    address: token,
    abi: rwaTokenAbi,
    functionName: "symbol",
  });

  const { data: totalSupply } = useReadContract({
    address: token,
    abi: rwaTokenAbi,
    functionName: "totalSupply",
  });

  const { data: nav } = useReadContract({
    address: navOracle,
    abi: navOracleAbi,
    functionName: "navPerToken",
  });

  const { data: isStale } = useReadContract({
    address: navOracle,
    abi: navOracleAbi,
    functionName: "isStale",
  });

  const { data: balance } = useReadContract({
    address: token,
    abi: rwaTokenAbi,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  });

  return (
    <Link href={`/asset/${index}`}>
      <div className="group rounded-xl border border-slate-800 bg-slate-900/50 p-5 transition-all hover:border-slate-700 hover:bg-slate-900">
        {/* Header */}
        <div className="mb-4 flex items-start justify-between">
          <div>
            <h3 className="text-lg font-semibold text-white group-hover:text-blue-400 transition-colors">
              {name ?? "Loading..."}
            </h3>
            <p className="text-sm text-slate-500">{symbol ?? "..."}</p>
          </div>
          <span
            className={`inline-flex rounded-full border px-2.5 py-0.5 text-xs font-medium ${assetTypeBadgeClasses(assetType)}`}
          >
            {assetTypeLabel(assetType)}
          </span>
        </div>

        {/* Stats Grid */}
        <div className="grid grid-cols-2 gap-3">
          <div className="rounded-lg bg-slate-800/50 p-3">
            <p className="text-xs text-slate-500">NAV / Token</p>
            <p className="mt-1 flex items-center gap-1.5 text-sm font-medium text-white">
              {nav !== undefined ? formatNAV(nav) : "..."}
              {isStale && (
                <span className="inline-block h-2 w-2 rounded-full bg-amber-400" title="Stale NAV" />
              )}
            </p>
          </div>
          <div className="rounded-lg bg-slate-800/50 p-3">
            <p className="text-xs text-slate-500">Total Supply</p>
            <p className="mt-1 text-sm font-medium text-white">
              {totalSupply !== undefined ? formatTokens(totalSupply) : "..."}
            </p>
          </div>
          <div className="rounded-lg bg-slate-800/50 p-3">
            <p className="text-xs text-slate-500">Token Address</p>
            <p className="mt-1 text-sm font-mono text-slate-300">
              {shortenAddress(token)}
            </p>
          </div>
          <div className="rounded-lg bg-slate-800/50 p-3">
            <p className="text-xs text-slate-500">Your Balance</p>
            <p className="mt-1 text-sm font-medium text-white">
              {address
                ? balance !== undefined
                  ? formatTokens(balance)
                  : "..."
                : "--"}
            </p>
          </div>
        </div>

        {/* Footer */}
        <div className="mt-4 flex items-center justify-end text-xs text-slate-500 group-hover:text-blue-400 transition-colors">
          View details &rarr;
        </div>
      </div>
    </Link>
  );
}
