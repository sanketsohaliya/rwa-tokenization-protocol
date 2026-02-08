"use client";

import { useReadContract, useReadContracts } from "wagmi";
import { assetFactoryAbi } from "@/lib/abi";
import { FACTORY_ADDRESS } from "@/lib/wagmi";
import { AssetCard } from "@/components/asset-card";

export default function Dashboard() {
  const isConfigured = !!FACTORY_ADDRESS && FACTORY_ADDRESS !== "0x...";

  const { data: assetCount, isLoading: isCountLoading } = useReadContract({
    address: FACTORY_ADDRESS,
    abi: assetFactoryAbi,
    functionName: "getDeployedAssetsCount",
    query: { enabled: isConfigured },
  });

  const count = assetCount ? Number(assetCount) : 0;

  const { data: assetsData, isLoading: isAssetsLoading } = useReadContracts({
    contracts: Array.from({ length: count }, (_, i) => ({
      address: FACTORY_ADDRESS,
      abi: assetFactoryAbi,
      functionName: "deployedAssets" as const,
      args: [BigInt(i)] as const,
    })),
    query: { enabled: count > 0 },
  });

  const assets =
    assetsData
      ?.map((result) => {
        if (result.status !== "success" || !result.result) return null;
        const [token, complianceRegistry, navOracle, assetType] =
          result.result as [string, string, string, string];
        return {
          token: token as `0x${string}`,
          complianceRegistry: complianceRegistry as `0x${string}`,
          navOracle: navOracle as `0x${string}`,
          assetType,
        };
      })
      .filter(Boolean) ?? [];

  return (
    <div>
      {isCountLoading || isAssetsLoading ? (
        <div className="flex items-center justify-center py-20">
          <div className="h-8 w-8 animate-spin rounded-full border-2 border-blue-500 border-t-transparent" />
        </div>
      ) : assets.length === 0 ? (
        <div className="rounded-xl border border-slate-800 bg-slate-900/50 p-12 text-center">
          <p className="text-lg text-slate-400">No assets deployed yet.</p>
          <p className="mt-2 text-sm text-slate-500">
            Head to{" "}
            <a href="/factory" className="text-blue-400 hover:text-blue-300">
              Create Asset
            </a>{" "}
            to deploy your first RWA token.
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-3">
          {assets.map(
            (asset, i) =>
              asset && (
                <AssetCard
                  key={i}
                  index={i}
                  token={asset.token}
                  navOracle={asset.navOracle}
                  assetType={asset.assetType}
                />
              )
          )}
        </div>
      )}
    </div>
  );
}
