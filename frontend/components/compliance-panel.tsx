"use client";

import { useState, useEffect } from "react";
import {
  useAccount,
  useReadContract,
  useWriteContract,
  useWaitForTransactionReceipt,
} from "wagmi";
import { isAddress } from "viem";
import { complianceRegistryAbi } from "@/lib/abi";
import { CHAIN_ID } from "@/lib/wagmi";
import { shortenAddress } from "@/lib/utils";

interface CompliancePanelProps {
  registryAddress: `0x${string}`;
}

function StatusBadge({
  label,
  active,
  color,
}: {
  label: string;
  active: boolean;
  color: "emerald" | "blue" | "red";
}) {
  const colorMap = {
    emerald: active
      ? "bg-emerald-500/20 text-emerald-400 border-emerald-500/30"
      : "bg-slate-800 text-slate-500 border-slate-700",
    blue: active
      ? "bg-blue-500/20 text-blue-400 border-blue-500/30"
      : "bg-slate-800 text-slate-500 border-slate-700",
    red: active
      ? "bg-red-500/20 text-red-400 border-red-500/30"
      : "bg-slate-800 text-slate-500 border-slate-700",
  };

  const dotColor = active
    ? color === "red"
      ? "bg-red-400"
      : color === "blue"
        ? "bg-blue-400"
        : "bg-emerald-400"
    : "bg-slate-600";

  return (
    <span
      className={`inline-flex items-center gap-1.5 rounded-full border px-3 py-1 text-xs font-medium ${colorMap[color]}`}
    >
      <span className={`h-1.5 w-1.5 rounded-full ${dotColor}`} />
      {label}
    </span>
  );
}

function AdminAction({
  label,
  placeholder,
  value,
  onChange,
  onSubmit,
  isPending,
  isConfirming,
  isSuccess,
  buttonColor,
}: {
  label: string;
  placeholder: string;
  value: string;
  onChange: (v: string) => void;
  onSubmit: () => void;
  isPending: boolean;
  isConfirming: boolean;
  isSuccess: boolean;
  buttonColor: string;
}) {
  const isLoading = isPending || isConfirming;
  return (
    <div>
      <label className="mb-1 block text-xs text-slate-400">{label}</label>
      <div className="flex gap-2">
        <input
          type="text"
          placeholder={placeholder}
          value={value}
          onChange={(e) => onChange(e.target.value)}
          className="flex-1 rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none placeholder:text-slate-600 focus:border-blue-500"
        />
        <button
          onClick={onSubmit}
          disabled={!value.trim() || !isAddress(value.trim()) || isLoading}
          className={`rounded-lg px-4 py-2 text-sm font-medium text-white transition-colors disabled:opacity-50 ${buttonColor}`}
        >
          {isPending ? "..." : isConfirming ? "Confirming" : "Submit"}
        </button>
      </div>
      {isSuccess && (
        <p className="mt-1 text-xs text-emerald-400">Success!</p>
      )}
    </div>
  );
}

export function CompliancePanel({ registryAddress }: CompliancePanelProps) {
  const { address } = useAccount();

  const { data: registryOwner } = useReadContract({
    address: registryAddress,
    abi: complianceRegistryAbi,
    functionName: "owner",
  });

  const { data: isEligible } = useReadContract({
    address: registryAddress,
    abi: complianceRegistryAbi,
    functionName: "isEligible",
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  });

  const { data: isWhitelisted } = useReadContract({
    address: registryAddress,
    abi: complianceRegistryAbi,
    functionName: "isWhitelisted",
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  });

  const { data: isFrozen } = useReadContract({
    address: registryAddress,
    abi: complianceRegistryAbi,
    functionName: "isFrozen",
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  });

  const isOwner =
    address && registryOwner
      ? address.toLowerCase() === registryOwner.toLowerCase()
      : false;

  // Whitelist
  const [whitelistInput, setWhitelistInput] = useState("");
  const {
    writeContract: writeWhitelist,
    data: whitelistHash,
    isPending: isWhitelistPending,
    reset: resetWhitelist,
  } = useWriteContract();
  const { isLoading: isWhitelistConfirming, isSuccess: isWhitelistSuccess } =
    useWaitForTransactionReceipt({ hash: whitelistHash });

  // Remove
  const [removeInput, setRemoveInput] = useState("");
  const {
    writeContract: writeRemove,
    data: removeHash,
    isPending: isRemovePending,
    reset: resetRemove,
  } = useWriteContract();
  const { isLoading: isRemoveConfirming, isSuccess: isRemoveSuccess } =
    useWaitForTransactionReceipt({ hash: removeHash });

  // Freeze
  const [freezeInput, setFreezeInput] = useState("");
  const {
    writeContract: writeFreeze,
    data: freezeHash,
    isPending: isFreezePending,
    reset: resetFreeze,
  } = useWriteContract();
  const { isLoading: isFreezeConfirming, isSuccess: isFreezeSuccess } =
    useWaitForTransactionReceipt({ hash: freezeHash });

  // Unfreeze
  const [unfreezeInput, setUnfreezeInput] = useState("");
  const {
    writeContract: writeUnfreeze,
    data: unfreezeHash,
    isPending: isUnfreezePending,
    reset: resetUnfreeze,
  } = useWriteContract();
  const { isLoading: isUnfreezeConfirming, isSuccess: isUnfreezeSuccess } =
    useWaitForTransactionReceipt({ hash: unfreezeHash });

  useEffect(() => {
    if (isWhitelistSuccess) { setWhitelistInput(""); resetWhitelist(); }
  }, [isWhitelistSuccess, resetWhitelist]);
  useEffect(() => {
    if (isRemoveSuccess) { setRemoveInput(""); resetRemove(); }
  }, [isRemoveSuccess, resetRemove]);
  useEffect(() => {
    if (isFreezeSuccess) { setFreezeInput(""); resetFreeze(); }
  }, [isFreezeSuccess, resetFreeze]);
  useEffect(() => {
    if (isUnfreezeSuccess) { setUnfreezeInput(""); resetUnfreeze(); }
  }, [isUnfreezeSuccess, resetUnfreeze]);

  function handleWhitelist() {
    const addr = whitelistInput.trim() as `0x${string}`;
    if (!isAddress(addr)) return;
    writeWhitelist({
      chainId: CHAIN_ID,
      address: registryAddress,
      abi: complianceRegistryAbi,
      functionName: "addToWhitelist",
      args: [[addr]],
    });
  }

  function handleRemoveWhitelist() {
    const addr = removeInput.trim() as `0x${string}`;
    if (!isAddress(addr)) return;
    writeRemove({
      chainId: CHAIN_ID,
      address: registryAddress,
      abi: complianceRegistryAbi,
      functionName: "removeFromWhitelist",
      args: [[addr]],
    });
  }

  function handleFreeze() {
    const addr = freezeInput.trim() as `0x${string}`;
    if (!isAddress(addr)) return;
    writeFreeze({
      chainId: CHAIN_ID,
      address: registryAddress,
      abi: complianceRegistryAbi,
      functionName: "freezeAddress",
      args: [[addr]],
    });
  }

  function handleUnfreeze() {
    const addr = unfreezeInput.trim() as `0x${string}`;
    if (!isAddress(addr)) return;
    writeUnfreeze({
      chainId: CHAIN_ID,
      address: registryAddress,
      abi: complianceRegistryAbi,
      functionName: "unfreezeAddress",
      args: [[addr]],
    });
  }

  return (
    <div className="rounded-xl border border-slate-800 bg-slate-900/50 p-6">
      <h3 className="mb-4 text-lg font-semibold text-white">Compliance</h3>

      {address && (
        <div className="mb-6 rounded-lg bg-slate-800/50 p-4">
          <p className="mb-2 text-sm text-slate-400">Your Compliance Status</p>
          <div className="flex flex-wrap gap-3">
            <StatusBadge label="Eligible" active={isEligible === true} color="emerald" />
            <StatusBadge label="Whitelisted" active={isWhitelisted === true} color="blue" />
            <StatusBadge label="Frozen" active={isFrozen === true} color="red" />
          </div>
        </div>
      )}

      <p className="mb-4 text-xs text-slate-500">
        Registry: {shortenAddress(registryAddress)} &middot; Officer:{" "}
        {registryOwner ? shortenAddress(registryOwner) : "..."}
      </p>

      {isOwner && (
        <div className="space-y-4 border-t border-slate-800 pt-4">
          <p className="text-sm font-medium text-slate-300">
            Compliance Officer Actions
          </p>
          <AdminAction
            label="Add to Whitelist"
            placeholder="0x address..."
            value={whitelistInput}
            onChange={setWhitelistInput}
            onSubmit={handleWhitelist}
            isPending={isWhitelistPending}
            isConfirming={isWhitelistConfirming}
            isSuccess={isWhitelistSuccess}
            buttonColor="bg-emerald-600 hover:bg-emerald-700"
          />
          <AdminAction
            label="Remove from Whitelist"
            placeholder="0x address..."
            value={removeInput}
            onChange={setRemoveInput}
            onSubmit={handleRemoveWhitelist}
            isPending={isRemovePending}
            isConfirming={isRemoveConfirming}
            isSuccess={isRemoveSuccess}
            buttonColor="bg-slate-600 hover:bg-slate-700"
          />
          <AdminAction
            label="Freeze Address"
            placeholder="0x address..."
            value={freezeInput}
            onChange={setFreezeInput}
            onSubmit={handleFreeze}
            isPending={isFreezePending}
            isConfirming={isFreezeConfirming}
            isSuccess={isFreezeSuccess}
            buttonColor="bg-red-600 hover:bg-red-700"
          />
          <AdminAction
            label="Unfreeze Address"
            placeholder="0x address..."
            value={unfreezeInput}
            onChange={setUnfreezeInput}
            onSubmit={handleUnfreeze}
            isPending={isUnfreezePending}
            isConfirming={isUnfreezeConfirming}
            isSuccess={isUnfreezeSuccess}
            buttonColor="bg-amber-600 hover:bg-amber-700"
          />
        </div>
      )}
    </div>
  );
}
