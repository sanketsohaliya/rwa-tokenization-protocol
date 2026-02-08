"use client";

import { useState, useEffect } from "react";
import {
  useAccount,
  useWriteContract,
  useWaitForTransactionReceipt,
} from "wagmi";
import { parseUnits } from "viem";
import { assetFactoryAbi } from "@/lib/abi";
import { FACTORY_ADDRESS, USDC_ADDRESS, CHAIN_ID } from "@/lib/wagmi";
import { shortenAddress } from "@/lib/utils";

type AssetType = "BOND" | "REAL_ESTATE" | "COMMODITY";

const ASSET_PLACEHOLDERS: Record<AssetType, { name: string; symbol: string }> = {
  BOND: { name: "US Treasury 6M", symbol: "UST6M" },
  REAL_ESTATE: { name: "Manhattan Office Tower", symbol: "MNHT-RE" },
  COMMODITY: { name: "Tokenized Gold", symbol: "tGOLD" },
};

export function CreateAssetForm() {
  const { address } = useAccount();
  const [assetType, setAssetType] = useState<AssetType>("BOND");

  // Common fields
  const [name, setName] = useState("");
  const [symbol, setSymbol] = useState("");
  const [complianceOfficer, setComplianceOfficer] = useState<string>("");
  const [oracleUpdater, setOracleUpdater] = useState<string>("");

  // Bond fields
  const [maturityDays, setMaturityDays] = useState("180");
  const [couponBps, setCouponBps] = useState("500");
  const [faceValue, setFaceValue] = useState("1000");

  // Real Estate fields
  const [propertyId, setPropertyId] = useState("");
  const [jurisdiction, setJurisdiction] = useState("");
  const [totalValuation, setTotalValuation] = useState("");
  const [rentalYieldBps, setRentalYieldBps] = useState("800");

  // Commodity fields
  const [commodityType, setCommodityType] = useState("");
  const [unit, setUnit] = useState("");
  const [backingRatio, setBackingRatio] = useState("1");


  // ─── Write ────────────────────────────────────────────────────────────────
  const {
    writeContract,
    data: txHash,
    isPending,
    error: writeError,
    reset,
  } = useWriteContract();

  const { isLoading: isConfirming, isSuccess } =
    useWaitForTransactionReceipt({ hash: txHash });

  useEffect(() => {
    if (isSuccess) {
      // Reset form
      setName("");
      setSymbol("");
      setPropertyId("");
      setJurisdiction("");
      setTotalValuation("");
      setCommodityType("");
      setUnit("");
    }
  }, [isSuccess]);

  function handleCreate() {
    if (!FACTORY_ADDRESS || !address) return;

    const payAddr = USDC_ADDRESS as `0x${string}`;
    const compAddr = complianceOfficer as `0x${string}`;
    const oracleAddr = oracleUpdater as `0x${string}`;

    switch (assetType) {
      case "BOND": {
        const maturityTimestamp =
          BigInt(Math.floor(Date.now() / 1000)) +
          BigInt(Number(maturityDays) * 86400);
        writeContract({
          chainId: CHAIN_ID,
          address: FACTORY_ADDRESS,
          abi: assetFactoryAbi,
          functionName: "createBond",
          args: [
            name,
            symbol,
            maturityTimestamp,
            BigInt(couponBps),
            parseUnits(faceValue, 6),
            payAddr,
            compAddr,
            oracleAddr,
          ],
        });
        break;
      }
      case "REAL_ESTATE": {
        writeContract({
          chainId: CHAIN_ID,
          address: FACTORY_ADDRESS,
          abi: assetFactoryAbi,
          functionName: "createRealEstate",
          args: [
            name,
            symbol,
            propertyId,
            jurisdiction,
            parseUnits(totalValuation, 6),
            BigInt(rentalYieldBps),
            payAddr,
            compAddr,
            oracleAddr,
          ],
        });
        break;
      }
      case "COMMODITY": {
        writeContract({
          chainId: CHAIN_ID,
          address: FACTORY_ADDRESS,
          abi: assetFactoryAbi,
          functionName: "createCommodity",
          args: [
            name,
            symbol,
            commodityType,
            unit,
            parseUnits(backingRatio, 18),
            payAddr,
            compAddr,
            oracleAddr,
          ],
        });
        break;
      }
    }
  }

  const tabs: { type: AssetType; label: string }[] = [
    { type: "BOND", label: "Bond" },
    { type: "REAL_ESTATE", label: "Real Estate" },
    { type: "COMMODITY", label: "Commodity" },
  ];

  return (
    <div className="mx-auto max-w-2xl">
      <h2 className="mb-6 text-2xl font-bold text-white">Create New Asset</h2>

      {/* Asset Type Tabs */}
      <div className="mb-6 flex rounded-lg bg-slate-800/50 p-1">
        {tabs.map((tab) => (
          <button
            key={tab.type}
            onClick={() => {
              setAssetType(tab.type);
              reset();
            }}
            className={`flex-1 rounded-md py-2.5 text-sm font-medium transition-colors ${
              assetType === tab.type
                ? "bg-blue-600 text-white"
                : "text-slate-400 hover:text-white"
            }`}
          >
            {tab.label}
          </button>
        ))}
      </div>

      <div className="space-y-6 rounded-xl border border-slate-800 bg-slate-900/50 p-6">
        {/* Common Fields */}
        <div className="grid grid-cols-2 gap-4">
          <FormField label="Token Name" value={name} onChange={setName} placeholder={ASSET_PLACEHOLDERS[assetType].name} />
          <FormField label="Token Symbol" value={symbol} onChange={setSymbol} placeholder={ASSET_PLACEHOLDERS[assetType].symbol} />
        </div>

        <div className="grid grid-cols-2 gap-4">
          <FormField
            label="Compliance Officer"
            value={complianceOfficer}
            onChange={setComplianceOfficer}
            placeholder="0x..."
            mono
          />
          <FormField
            label="Oracle Updater"
            value={oracleUpdater}
            onChange={setOracleUpdater}
            placeholder="0x..."
            mono
          />
        </div>

        {/* Bond-specific fields */}
        {assetType === "BOND" && (
          <div className="space-y-4 border-t border-slate-800 pt-4">
            <p className="text-sm font-medium text-slate-300">Bond Parameters</p>
            <div className="grid grid-cols-3 gap-4">
              <FormField
                label="Maturity (days)"
                value={maturityDays}
                onChange={setMaturityDays}
                placeholder="180"
                type="number"
              />
              <FormField
                label="Coupon Rate (bps)"
                value={couponBps}
                onChange={setCouponBps}
                placeholder="500 = 5%"
                type="number"
              />
              <FormField
                label="Face Value (USDC)"
                value={faceValue}
                onChange={setFaceValue}
                placeholder="1000"
                type="number"
              />
            </div>
          </div>
        )}

        {/* Real Estate-specific fields */}
        {assetType === "REAL_ESTATE" && (
          <div className="space-y-4 border-t border-slate-800 pt-4">
            <p className="text-sm font-medium text-slate-300">
              Real Estate Parameters
            </p>
            <div className="grid grid-cols-2 gap-4">
              <FormField
                label="Property ID"
                value={propertyId}
                onChange={setPropertyId}
                placeholder="property-001"
              />
              <FormField
                label="Jurisdiction"
                value={jurisdiction}
                onChange={setJurisdiction}
                placeholder="US"
              />
              <FormField
                label="Total Valuation (USDC)"
                value={totalValuation}
                onChange={setTotalValuation}
                placeholder="10000000"
                type="number"
              />
              <FormField
                label="Rental Yield (bps)"
                value={rentalYieldBps}
                onChange={setRentalYieldBps}
                placeholder="800 = 8%"
                type="number"
              />
            </div>
          </div>
        )}

        {/* Commodity-specific fields */}
        {assetType === "COMMODITY" && (
          <div className="space-y-4 border-t border-slate-800 pt-4">
            <p className="text-sm font-medium text-slate-300">
              Commodity Parameters
            </p>
            <div className="grid grid-cols-3 gap-4">
              <FormField
                label="Commodity Type"
                value={commodityType}
                onChange={setCommodityType}
                placeholder="GOLD"
              />
              <FormField
                label="Unit"
                value={unit}
                onChange={setUnit}
                placeholder="troy_oz"
              />
              <FormField
                label="Backing Ratio"
                value={backingRatio}
                onChange={setBackingRatio}
                placeholder="1 = 1:1"
                type="number"
              />
            </div>
          </div>
        )}

        {/* Submit */}
        {!address ? (
          <p className="text-center text-sm text-slate-500">
            Connect your wallet to create assets
          </p>
        ) : !FACTORY_ADDRESS ? (
          <p className="text-center text-sm text-red-400">
            Factory address not configured. Set NEXT_PUBLIC_FACTORY_ADDRESS in .env.local
          </p>
        ) : (
          <button
            onClick={handleCreate}
            disabled={!name || !symbol || isPending || isConfirming}
            className="w-full rounded-lg bg-blue-600 py-3 text-sm font-medium text-white transition-colors hover:bg-blue-700 disabled:opacity-50"
          >
            {isPending
              ? "Confirm in wallet..."
              : isConfirming
                ? "Creating asset..."
                : `Create ${tabs.find((t) => t.type === assetType)?.label}`}
          </button>
        )}

        {writeError && (
          <p className="text-center text-sm text-red-400">
            Error: {writeError.message.slice(0, 100)}
          </p>
        )}

        {isSuccess && txHash && (
          <div className="rounded-lg border border-emerald-500/30 bg-emerald-500/10 p-4 text-center">
            <p className="text-sm text-emerald-400">
              Asset created successfully!
            </p>
            <p className="mt-1 text-xs font-mono text-slate-400">
              Tx: {shortenAddress(txHash)}
            </p>
          </div>
        )}
      </div>
    </div>
  );
}

function FormField({
  label,
  value,
  onChange,
  placeholder,
  type = "text",
  mono = false,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  placeholder: string;
  type?: string;
  mono?: boolean;
}) {
  return (
    <div>
      <label className="mb-1 block text-xs text-slate-400">{label}</label>
      <input
        type={type}
        placeholder={placeholder}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className={`w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none placeholder:text-slate-600 focus:border-blue-500 ${mono ? "font-mono" : ""}`}
      />
    </div>
  );
}
