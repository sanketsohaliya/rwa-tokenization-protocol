"use client";

import { useState, useEffect } from "react";
import {
  useAccount,
  useReadContract,
  useWriteContract,
  useWaitForTransactionReceipt,
} from "wagmi";
import { parseUnits, formatUnits } from "viem";
import { rwaTokenAbi, erc20Abi, navOracleAbi } from "@/lib/abi";
import { CHAIN_ID } from "@/lib/wagmi";
import { formatUSDC, formatTokens } from "@/lib/utils";

interface InvestRedeemPanelProps {
  tokenAddress: `0x${string}`;
  paymentTokenAddress: `0x${string}`;
  navOracleAddress: `0x${string}`;
}

export function InvestRedeemPanel({
  tokenAddress,
  paymentTokenAddress,
  navOracleAddress,
}: InvestRedeemPanelProps) {
  const { address } = useAccount();
  const [investAmount, setInvestAmount] = useState("");
  const [redeemAmount, setRedeemAmount] = useState("");
  const [activeTab, setActiveTab] = useState<"invest" | "redeem">("invest");

  // ---- Contract Reads ----
  const { data: nav } = useReadContract({
    address: navOracleAddress,
    abi: navOracleAbi,
    functionName: "navPerToken",
  });

  const { data: usdcBalance } = useReadContract({
    address: paymentTokenAddress,
    abi: erc20Abi,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  });

  const { data: tokenBalance } = useReadContract({
    address: tokenAddress,
    abi: rwaTokenAbi,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  });

  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: paymentTokenAddress,
    abi: erc20Abi,
    functionName: "allowance",
    args: address ? [address, tokenAddress] : undefined,
    query: { enabled: !!address },
  });

  const { data: paymentDecimals } = useReadContract({
    address: paymentTokenAddress,
    abi: erc20Abi,
    functionName: "decimals",
  });

  const { data: paymentSymbol } = useReadContract({
    address: paymentTokenAddress,
    abi: erc20Abi,
    functionName: "symbol",
  });

  const { data: investCapacity } = useReadContract({
    address: tokenAddress,
    abi: rwaTokenAbi,
    functionName: "getRemainingInvestCapacity",
  });

  const { data: redeemCapacity } = useReadContract({
    address: tokenAddress,
    abi: rwaTokenAbi,
    functionName: "getRemainingRedeemCapacity",
  });

  // ---- Writes ----
  const {
    writeContract: writeApprove,
    data: approveHash,
    isPending: isApprovePending,
    reset: resetApprove,
  } = useWriteContract();

  const {
    writeContract: writeInvest,
    data: investHash,
    isPending: isInvestPending,
    reset: resetInvest,
  } = useWriteContract();

  const {
    writeContract: writeRedeem,
    data: redeemHash,
    isPending: isRedeemPending,
    reset: resetRedeem,
  } = useWriteContract();

  const { isLoading: isApproveConfirming, isSuccess: isApproveSuccess } =
    useWaitForTransactionReceipt({ hash: approveHash });

  const { isLoading: isInvestConfirming, isSuccess: isInvestSuccess } =
    useWaitForTransactionReceipt({ hash: investHash });

  const { isLoading: isRedeemConfirming, isSuccess: isRedeemSuccess } =
    useWaitForTransactionReceipt({ hash: redeemHash });

  useEffect(() => {
    if (isApproveSuccess) {
      refetchAllowance();
      resetApprove();
    }
  }, [isApproveSuccess, refetchAllowance, resetApprove]);

  useEffect(() => {
    if (isInvestSuccess) {
      setInvestAmount("");
      resetInvest();
    }
  }, [isInvestSuccess, resetInvest]);

  useEffect(() => {
    if (isRedeemSuccess) {
      setRedeemAmount("");
      resetRedeem();
    }
  }, [isRedeemSuccess, resetRedeem]);

  // ---- Calculations ----
  const decimals = paymentDecimals ?? 6;
  const pSymbol = paymentSymbol ?? "USDC";

  const investAmountBigInt =
    investAmount && !isNaN(Number(investAmount))
      ? parseUnits(investAmount, decimals)
      : 0n;

  const redeemAmountBigInt =
    redeemAmount && !isNaN(Number(redeemAmount))
      ? parseUnits(redeemAmount, 18)
      : 0n;

  const paymentTokenScale = 10n ** (18n - BigInt(decimals));
  const estimatedTokensOut =
    nav && investAmountBigInt > 0n
      ? (investAmountBigInt * paymentTokenScale * 10n ** 18n) / nav
      : 0n;

  const estimatedPaymentOut =
    nav && redeemAmountBigInt > 0n
      ? (redeemAmountBigInt * nav) / 10n ** 18n / paymentTokenScale
      : 0n;

  const needsApproval =
    allowance !== undefined &&
    investAmountBigInt > 0n &&
    allowance < investAmountBigInt;

  // ---- Handlers ----
  function handleApprove() {
    writeApprove({
      chainId: CHAIN_ID,
      address: paymentTokenAddress,
      abi: erc20Abi,
      functionName: "approve",
      args: [tokenAddress, investAmountBigInt],
    });
  }

  function handleInvest() {
    writeInvest({
      chainId: CHAIN_ID,
      address: tokenAddress,
      abi: rwaTokenAbi,
      functionName: "invest",
      args: [investAmountBigInt, 0n],
    });
  }

  function handleRedeem() {
    writeRedeem({
      chainId: CHAIN_ID,
      address: tokenAddress,
      abi: rwaTokenAbi,
      functionName: "redeem",
      args: [redeemAmountBigInt, 0n],
    });
  }

  const maxUsdcLimit = 2n ** 128n;

  return (
    <div className="rounded-xl border border-slate-800 bg-slate-900/50 p-6">
      {/* Tabs */}
      <div className="mb-6 flex rounded-lg bg-slate-800/50 p-1">
        <button
          onClick={() => setActiveTab("invest")}
          className={`flex-1 rounded-md py-2 text-sm font-medium transition-colors ${
            activeTab === "invest"
              ? "bg-blue-600 text-white"
              : "text-slate-400 hover:text-white"
          }`}
        >
          Invest
        </button>
        <button
          onClick={() => setActiveTab("redeem")}
          className={`flex-1 rounded-md py-2 text-sm font-medium transition-colors ${
            activeTab === "redeem"
              ? "bg-blue-600 text-white"
              : "text-slate-400 hover:text-white"
          }`}
        >
          Redeem
        </button>
      </div>

      {activeTab === "invest" ? (
        <div className="space-y-4">
          <div className="flex items-center justify-between text-sm">
            <span className="text-slate-400">Your {pSymbol} Balance</span>
            <span className="font-medium text-white">
              {address && usdcBalance !== undefined
                ? formatUSDC(usdcBalance)
                : "--"}
            </span>
          </div>

          <div className="rounded-lg border border-slate-700 bg-slate-800/50 p-4">
            <div className="flex items-center justify-between">
              <input
                type="number"
                placeholder="0.00"
                value={investAmount}
                onChange={(e) => setInvestAmount(e.target.value)}
                className="w-full bg-transparent text-2xl font-medium text-white outline-none placeholder:text-slate-600"
              />
              <span className="ml-3 text-sm font-medium text-slate-400">
                {pSymbol}
              </span>
            </div>
            {usdcBalance !== undefined && (
              <button
                onClick={() =>
                  setInvestAmount(formatUnits(usdcBalance, decimals))
                }
                className="mt-2 text-xs text-blue-400 hover:text-blue-300"
              >
                Max
              </button>
            )}
          </div>

          {estimatedTokensOut > 0n && (
            <div className="rounded-lg bg-slate-800/30 p-3 text-sm">
              <span className="text-slate-400">You will receive ~ </span>
              <span className="font-medium text-white">
                {formatTokens(estimatedTokensOut)} tokens
              </span>
            </div>
          )}

          {investCapacity !== undefined && investCapacity < maxUsdcLimit && (
            <p className="text-xs text-slate-500">
              Daily limit remaining: {formatUSDC(investCapacity)} {pSymbol}
            </p>
          )}

          {!address ? (
            <p className="text-center text-sm text-slate-500">
              Connect your wallet to invest
            </p>
          ) : needsApproval ? (
            <button
              onClick={handleApprove}
              disabled={isApprovePending || isApproveConfirming}
              className="w-full rounded-lg bg-amber-600 py-3 text-sm font-medium text-white transition-colors hover:bg-amber-700 disabled:opacity-50"
            >
              {isApprovePending
                ? "Confirm in wallet..."
                : isApproveConfirming
                  ? "Approving..."
                  : `Approve ${pSymbol}`}
            </button>
          ) : (
            <button
              onClick={handleInvest}
              disabled={
                investAmountBigInt === 0n ||
                isInvestPending ||
                isInvestConfirming
              }
              className="w-full rounded-lg bg-blue-600 py-3 text-sm font-medium text-white transition-colors hover:bg-blue-700 disabled:opacity-50"
            >
              {isInvestPending
                ? "Confirm in wallet..."
                : isInvestConfirming
                  ? "Investing..."
                  : "Invest"}
            </button>
          )}

          {isInvestSuccess && (
            <p className="text-center text-sm text-emerald-400">
              Investment successful!
            </p>
          )}
        </div>
      ) : (
        <div className="space-y-4">
          <div className="flex items-center justify-between text-sm">
            <span className="text-slate-400">Your Token Balance</span>
            <span className="font-medium text-white">
              {address && tokenBalance !== undefined
                ? formatTokens(tokenBalance)
                : "--"}
            </span>
          </div>

          <div className="rounded-lg border border-slate-700 bg-slate-800/50 p-4">
            <div className="flex items-center justify-between">
              <input
                type="number"
                placeholder="0.00"
                value={redeemAmount}
                onChange={(e) => setRedeemAmount(e.target.value)}
                className="w-full bg-transparent text-2xl font-medium text-white outline-none placeholder:text-slate-600"
              />
              <span className="ml-3 text-sm font-medium text-slate-400">
                Tokens
              </span>
            </div>
            {tokenBalance !== undefined && tokenBalance > 0n && (
              <button
                onClick={() => setRedeemAmount(formatUnits(tokenBalance, 18))}
                className="mt-2 text-xs text-blue-400 hover:text-blue-300"
              >
                Max
              </button>
            )}
          </div>

          {estimatedPaymentOut > 0n && (
            <div className="rounded-lg bg-slate-800/30 p-3 text-sm">
              <span className="text-slate-400">You will receive ~ </span>
              <span className="font-medium text-white">
                {formatUSDC(estimatedPaymentOut)} {pSymbol}
              </span>
            </div>
          )}

          {redeemCapacity !== undefined && redeemCapacity < maxUsdcLimit && (
            <p className="text-xs text-slate-500">
              Daily limit remaining: {formatTokens(redeemCapacity)} tokens
            </p>
          )}

          {!address ? (
            <p className="text-center text-sm text-slate-500">
              Connect your wallet to redeem
            </p>
          ) : (
            <button
              onClick={handleRedeem}
              disabled={
                redeemAmountBigInt === 0n ||
                isRedeemPending ||
                isRedeemConfirming
              }
              className="w-full rounded-lg bg-blue-600 py-3 text-sm font-medium text-white transition-colors hover:bg-blue-700 disabled:opacity-50"
            >
              {isRedeemPending
                ? "Confirm in wallet..."
                : isRedeemConfirming
                  ? "Redeeming..."
                  : "Redeem"}
            </button>
          )}

          {isRedeemSuccess && (
            <p className="text-center text-sm text-emerald-400">
              Redemption successful!
            </p>
          )}
        </div>
      )}
    </div>
  );
}
