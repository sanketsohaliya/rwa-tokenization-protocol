"use client";

import { useState, useEffect } from "react";
import {
  useAccount,
  useReadContract,
  useWriteContract,
  useWaitForTransactionReceipt,
} from "wagmi";
import { parseUnits } from "viem";
import { navOracleAbi } from "@/lib/abi";
import { CHAIN_ID } from "@/lib/wagmi";
import { formatNAV, timeAgo, shortenAddress } from "@/lib/utils";

interface OraclePanelProps {
  oracleAddress: `0x${string}`;
}

export function OraclePanel({ oracleAddress }: OraclePanelProps) {
  const { address } = useAccount();

  const { data: nav } = useReadContract({
    address: oracleAddress,
    abi: navOracleAbi,
    functionName: "navPerToken",
  });

  const { data: lastUpdated } = useReadContract({
    address: oracleAddress,
    abi: navOracleAbi,
    functionName: "lastUpdated",
  });

  const { data: isStale } = useReadContract({
    address: oracleAddress,
    abi: navOracleAbi,
    functionName: "isStale",
  });

  const { data: updater } = useReadContract({
    address: oracleAddress,
    abi: navOracleAbi,
    functionName: "updater",
  });

  const { data: maxStaleness } = useReadContract({
    address: oracleAddress,
    abi: navOracleAbi,
    functionName: "maxStaleness",
  });

  const isUpdater =
    address && updater
      ? address.toLowerCase() === updater.toLowerCase()
      : false;

  // ─── Update NAV ───────────────────────────────────────────────────────────
  const [newNav, setNewNav] = useState("");

  const {
    writeContract: writeUpdateNAV,
    data: updateHash,
    isPending: isUpdatePending,
    reset: resetUpdate,
  } = useWriteContract();

  const { isLoading: isUpdateConfirming, isSuccess: isUpdateSuccess } =
    useWaitForTransactionReceipt({ hash: updateHash });

  useEffect(() => {
    if (isUpdateSuccess) {
      setNewNav("");
      resetUpdate();
    }
  }, [isUpdateSuccess, resetUpdate]);

  function handleUpdateNAV() {
    if (!newNav || isNaN(Number(newNav))) return;
    const navBigInt = parseUnits(newNav, 18);
    writeUpdateNAV({
      chainId: CHAIN_ID,
      address: oracleAddress,
      abi: navOracleAbi,
      functionName: "updateNAV",
      args: [navBigInt],
    });
  }

  return (
    <div className="rounded-xl border border-slate-800 bg-slate-900/50 p-6">
      <h3 className="mb-4 text-lg font-semibold text-white">NAV Oracle</h3>

      {/* Oracle Info */}
      <div className="mb-4 grid grid-cols-2 gap-3">
        <div className="rounded-lg bg-slate-800/50 p-3">
          <p className="text-xs text-slate-500">Current NAV</p>
          <p className="mt-1 text-lg font-semibold text-white">
            {nav !== undefined ? formatNAV(nav) : "..."}
          </p>
        </div>
        <div className="rounded-lg bg-slate-800/50 p-3">
          <p className="text-xs text-slate-500">Last Updated</p>
          <p className="mt-1 text-sm font-medium text-white">
            {lastUpdated !== undefined ? timeAgo(lastUpdated) : "..."}
          </p>
        </div>
        <div className="rounded-lg bg-slate-800/50 p-3">
          <p className="text-xs text-slate-500">Status</p>
          <p className="mt-1 flex items-center gap-1.5 text-sm font-medium">
            <span
              className={`h-2 w-2 rounded-full ${isStale ? "bg-red-400" : "bg-emerald-400"}`}
            />
            <span className={isStale ? "text-red-400" : "text-emerald-400"}>
              {isStale ? "Stale" : "Fresh"}
            </span>
          </p>
        </div>
        <div className="rounded-lg bg-slate-800/50 p-3">
          <p className="text-xs text-slate-500">Max Staleness</p>
          <p className="mt-1 text-sm font-medium text-white">
            {maxStaleness !== undefined
              ? `${(Number(maxStaleness) / 3600).toFixed(1)}h`
              : "..."}
          </p>
        </div>
      </div>

      <p className="mb-4 text-xs text-slate-500">
        Oracle: {shortenAddress(oracleAddress)} &middot; Updater:{" "}
        {updater ? shortenAddress(updater) : "..."}
      </p>

      {/* Update NAV (updater only) */}
      {isUpdater && (
        <div className="border-t border-slate-800 pt-4">
          <label className="mb-1 block text-xs text-slate-400">
            Update NAV (e.g. 1.05 for $1.05)
          </label>
          <div className="flex gap-2">
            <input
              type="number"
              step="0.0001"
              placeholder="1.05"
              value={newNav}
              onChange={(e) => setNewNav(e.target.value)}
              className="flex-1 rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none placeholder:text-slate-600 focus:border-blue-500"
            />
            <button
              onClick={handleUpdateNAV}
              disabled={
                !newNav ||
                isNaN(Number(newNav)) ||
                isUpdatePending ||
                isUpdateConfirming
              }
              className="rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-blue-700 disabled:opacity-50"
            >
              {isUpdatePending
                ? "..."
                : isUpdateConfirming
                  ? "Confirming"
                  : "Update"}
            </button>
          </div>
          {isUpdateSuccess && (
            <p className="mt-1 text-xs text-emerald-400">NAV updated!</p>
          )}
        </div>
      )}
    </div>
  );
}
