"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  useAccount,
  useConnect,
  useDisconnect,
  useBalance,
  useSwitchChain,
} from "wagmi";
import { injected } from "wagmi/connectors";
import { formatUnits } from "viem";
import { shortenAddress } from "@/lib/utils";
import { CHAIN_ID } from "@/lib/wagmi";

export function Navbar() {
  const pathname = usePathname();
  const { address, isConnected, chainId: walletChainId } = useAccount();
  const { connect, isPending: isConnecting } = useConnect();
  const { disconnect } = useDisconnect();
  const { data: balance } = useBalance({ address });
  const { switchChain, isPending: isSwitching } = useSwitchChain();

  const isWrongNetwork = isConnected && walletChainId !== CHAIN_ID;

  const navLinks = [
    { href: "/", label: "Dashboard" },
    { href: "/factory", label: "Create Asset" },
  ];

  return (
    <nav className="sticky top-0 z-50 border-b border-slate-800 bg-slate-950/80 backdrop-blur-md">
      <div className="mx-auto flex h-16 max-w-7xl items-center justify-between px-4 sm:px-6 lg:px-8">
        {/* Logo + App Name */}
        <div className="flex items-center gap-8">
          <Link href="/" className="flex items-center gap-2.5">
            <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-blue-600 text-sm font-bold text-white">
              R
            </div>
            <span className="text-lg font-semibold text-white">
              RWA Protocol
            </span>
          </Link>

          {/* Nav Links */}
          <div className="hidden items-center gap-1 sm:flex">
            {navLinks.map((link) => (
              <Link
                key={link.href}
                href={link.href}
                className={`rounded-lg px-3 py-2 text-sm font-medium transition-colors ${
                  pathname === link.href
                    ? "bg-slate-800 text-white"
                    : "text-slate-400 hover:bg-slate-800/50 hover:text-slate-200"
                }`}
              >
                {link.label}
              </Link>
            ))}
          </div>
        </div>

        {/* Wallet Connection */}
        <div className="flex items-center gap-3">
          {isConnected && address ? (
            <>
              {/* Wrong Network Warning */}
              {isWrongNetwork ? (
                <button
                  onClick={() => switchChain({ chainId: CHAIN_ID })}
                  disabled={isSwitching}
                  className="flex items-center gap-2 rounded-lg border border-red-500/50 bg-red-500/10 px-3 py-2 text-sm font-medium text-red-400 transition-colors hover:bg-red-500/20 disabled:opacity-50"
                >
                  <span className="h-2 w-2 rounded-full bg-red-400 animate-pulse" />
                  {isSwitching ? "Switching..." : "Switch to Sepolia"}
                </button>
              ) : (
                <>
                  <span className="hidden items-center gap-1.5 rounded-lg border border-slate-700 bg-slate-800/50 px-2.5 py-1.5 text-xs text-slate-400 sm:inline-flex">
                    Sepolia
                  </span>
                  {balance && (
                    <span className="hidden text-sm text-slate-400 sm:inline">
                      {Number(
                        formatUnits(balance.value, balance.decimals)
                      ).toFixed(3)}{" "}
                      {balance.symbol}
                    </span>
                  )}
                </>
              )}
              <div className="flex items-center gap-2 rounded-lg border border-slate-700 bg-slate-800 px-3 py-2">
                <div
                  className={`h-2 w-2 rounded-full ${isWrongNetwork ? "bg-red-400" : "bg-emerald-400"}`}
                />
                <span className="text-sm font-medium text-slate-200">
                  {shortenAddress(address)}
                </span>
              </div>
              <button
                onClick={() => disconnect()}
                className="rounded-lg px-3 py-2 text-sm text-slate-400 transition-colors hover:bg-slate-800 hover:text-slate-200"
              >
                Disconnect
              </button>
            </>
          ) : (
            <button
              onClick={() => connect({ connector: injected() })}
              disabled={isConnecting}
              className="rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-blue-700 disabled:opacity-50"
            >
              {isConnecting ? "Connecting..." : "Connect Wallet"}
            </button>
          )}
        </div>
      </div>
    </nav>
  );
}
