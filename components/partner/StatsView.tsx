"use client";

import { useQuery } from "@tanstack/react-query";
import { TrendingUp, ShoppingBag, Star, DollarSign, Activity, Flame, AlertCircle } from "lucide-react";
import { statsApi } from "@/api/fastBackend";

export default function StatsView() {
  const { data: stats, isLoading } = useQuery({
    queryKey: ["stats"],
    queryFn: () => statsApi.get(),
  });

  const statCards = [
    { label: "Commandes totales", value: stats?.totalOrders ?? 0, icon: ShoppingBag, color: "bg-blue-500" },
    { label: "Ce mois", value: stats?.monthOrders ?? 0, icon: TrendingUp, color: "bg-[#00c8b3]" },
    { label: "Terminées", value: stats?.completedOrders ?? 0, icon: Activity, color: "bg-green-500" },
    { label: "Chiffre d'affaires", value: `${(stats?.revenue ?? 0).toFixed(2)} `, icon: DollarSign, color: "bg-violet-500" },
    { label: "Note moyenne", value: stats?.averageRating ?? 0, icon: Star, color: "bg-yellow-500" },
    { label: "Taux d'annulation", value: `${stats?.cancellationRate ?? 0}%`, icon: AlertCircle, color: "bg-red-500" },
  ];

  const maxDaily = Math.max(1, ...(stats?.dailyOrders?.map((d: any) => d.count) || [0]));
  const popularItems = stats?.popularItems || [];

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-lg font-black text-white">Statistiques</h1>
      </div>

      {isLoading ? (
        <div className="py-12 text-center text-slate-500 text-sm">Chargement des statistiques...</div>
      ) : (
        <>
          <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
            {statCards.map((card) => {
              const Icon = card.icon;
              return (
                <div key={card.label} className="bg-[#0B1120] border border-white/[0.08] rounded-2xl p-3">
                  <div className={`w-8 h-8 rounded-lg ${card.color}/20 flex items-center justify-center mb-2`}>
                    <Icon className={`w-4 h-4 ${card.color.replace("bg-", "text-")}`} />
                  </div>
                  <p className="text-xl font-black text-white">{card.value}</p>
                  <p className="text-[10px] text-slate-400 font-semibold uppercase tracking-wider">{card.label}</p>
                </div>
              );
            })}
          </div>

          <div className="bg-[#0B1120] border border-white/[0.08] rounded-2xl p-4">
            <div className="flex items-center gap-2 mb-4">
              <Flame className="w-4 h-4 text-[#00c8b3]" />
              <p className="text-sm font-bold text-white">Commandes sur 7 jours</p>
            </div>
            <div className="flex items-end gap-2 h-32">
              {stats?.dailyOrders?.map((day: any, i: number) => (
                <div key={i} className="flex-1 flex flex-col items-center gap-1">
                  <div className="w-full bg-[#00c8b3]/20 rounded-t-lg relative overflow-hidden" style={{ height: `${Math.max(8, (day.count / maxDaily) * 100)}%` }}>
                    <div className="absolute bottom-0 left-0 right-0 bg-[#00c8b3] rounded-t-lg" style={{ height: "100%" }} />
                  </div>
                  <span className="text-[9px] text-slate-500 font-semibold">{day.date?.slice(5)}</span>
                  <span className="text-[10px] font-black text-white">{day.count}</span>
                </div>
              ))}
            </div>
          </div>

          <div className="bg-[#0B1120] border border-white/[0.08] rounded-2xl p-4">
            <div className="flex items-center gap-2 mb-3">
              <Flame className="w-4 h-4 text-[#ff0066]" />
              <p className="text-sm font-bold text-white">Plats les plus vendus</p>
            </div>
            {popularItems.length === 0 ? (
              <p className="text-sm text-slate-500">Aucune donnée de vente pour le moment.</p>
            ) : (
              <div className="space-y-2">
                {popularItems.map((item: any, i: number) => (
                  <div key={i} className="flex items-center justify-between py-2 border-b border-white/[0.06] last:border-0">
                    <div className="flex items-center gap-2">
                      <span className="w-5 h-5 rounded-full bg-white/[0.06] text-[10px] font-black text-slate-400 flex items-center justify-center">{i + 1}</span>
                      <span className="text-sm text-slate-200">{item.name}</span>
                    </div>
                    <span className="text-xs font-black text-[#00c8b3]">{item.totalSold} vendus</span>
                  </div>
                ))}
              </div>
            )}
          </div>
        </>
      )}
    </div>
  );
}
