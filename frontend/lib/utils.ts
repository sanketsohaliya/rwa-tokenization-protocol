import { formatUnits } from "viem";

/** Format a 6-decimal bigint (USDC) to a human-readable string like "1,000.00" */
export function formatUSDC(amount: bigint): string {
  const num = Number(formatUnits(amount, 6));
  return num.toLocaleString("en-US", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
}

/** Format an 18-decimal bigint (RWA token) to a human-readable string */
export function formatTokens(amount: bigint): string {
  const num = Number(formatUnits(amount, 18));
  return num.toLocaleString("en-US", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 4,
  });
}

/** Format NAV per token (18 decimals) to a dollar string like "$1.05" */
export function formatNAV(nav: bigint): string {
  const num = Number(formatUnits(nav, 18));
  return `$${num.toFixed(4)}`;
}

/** Shorten an address: 0x1234...5678 */
export function shortenAddress(address: string): string {
  if (!address || address.length < 10) return address;
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

/** Format basis points to percentage: 500 -> "5.00%" */
export function formatBps(bps: number | bigint): string {
  const n = typeof bps === "bigint" ? Number(bps) : bps;
  return `${(n / 100).toFixed(2)}%`;
}

/** Format a unix timestamp (bigint) to a readable date string */
export function formatTimestamp(ts: bigint): string {
  if (ts === 0n) return "N/A";
  return new Date(Number(ts) * 1000).toLocaleDateString("en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

/** Time ago string from a unix timestamp */
export function timeAgo(ts: bigint): string {
  if (ts === 0n) return "Never";
  const now = Math.floor(Date.now() / 1000);
  const diff = now - Number(ts);
  if (diff < 60) return `${diff}s ago`;
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  return `${Math.floor(diff / 86400)}d ago`;
}

/** Asset type to display label */
export function assetTypeLabel(assetType: string): string {
  switch (assetType) {
    case "BOND":
      return "Bond";
    case "REAL_ESTATE":
      return "Real Estate";
    case "COMMODITY":
      return "Commodity";
    default:
      return assetType;
  }
}

/** Asset type badge color classes */
export function assetTypeBadgeClasses(assetType: string): string {
  switch (assetType) {
    case "BOND":
      return "bg-blue-500/20 text-blue-400 border-blue-500/30";
    case "REAL_ESTATE":
      return "bg-emerald-500/20 text-emerald-400 border-emerald-500/30";
    case "COMMODITY":
      return "bg-amber-500/20 text-amber-400 border-amber-500/30";
    default:
      return "bg-slate-500/20 text-slate-400 border-slate-500/30";
  }
}
