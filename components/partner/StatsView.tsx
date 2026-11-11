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
    { label: "Commandes totales", value: stats?.totalOrders ?? 0, icon: ShoppingBag, color: "text-blue-500" },
    { label: "Ce mois", value: stats?.monthOrders ?? 0, icon: TrendingUp, color: "text-fast-teal" },
    { label: "Terminées", value: stats?.completedOrders ?? 0, icon: Activity, color: "text-green-500" },
    { label: "Chiffre d'affaires", value: `${(stats?.totalRevenue ?? 0).toFixed(2)} `, icon: DollarSign, color: "text-violet-500" },
    { label: "Note moyenne", value: stats?.averageRating ?? 0, icon: Star, color: "text-yellow-500" },
    { label: "Taux d'annulation", value: `${stats?.cancellationRate ?? 0}%`, icon: AlertCircle, color: "text-red-500" },
  ];

  const maxDaily = Math.max(1, ...(stats?.dailyOrders?.map((d: any) => d.count) || [0]));
  const popularItems = stats?.popularItems || [];

  return (
    <div className="space-y-8">
      <div className="flex items-center justify-between">
        <h1 className="font-display text-2xl font-bold text-foreground">Statistiques</h1>
      </div>

      {isLoading ? (
        <div className="py-12 text-center text-muted-foreground text-sm">Chargement des statistiques...</div>
      ) : (
        <>
          <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
            {statCards.map((card) => {
              const Icon = card.icon;
              return (
                <div key={card.label} className="bg-card border border-border rounded-2xl p-4">
                  <div className="w-9 h-9 rounded-xl bg-muted flex items-center justify-center mb-3">
                    <Icon className={`w-4 h-4 ${card.color}`} />
                  </div>
                  <p className="font-display text-2xl font-bold text-foreground tabular-nums">{card.value}</p>
                  <p className="text-xs text-muted-foreground font-bold uppercase tracking-wide mt-1">{card.label}</p>
                </div>
              );
            })}
          </div>

          <section className="space-y-3">
            <div className="flex items-center gap-2 px-1">
              <Flame className="w-4 h-4 text-fast-teal" />
              <p className="text-xs font-bold uppercase tracking-wide text-muted-foreground">Commandes sur 7 jours</p>
            </div>
            <div className="bg-card border border-border rounded-2xl p-4">
              <div className="flex items-end gap-2 h-36">
                {stats?.dailyOrders?.map((day: any, i: number) => (
                  <div key={i} className="flex-1 h-full flex flex-col items-center justify-end gap-1">
                    <div className="w-full flex-1 flex items-end">
                      <div className="w-full bg-fast-teal rounded-t-lg" style={{ height: `${Math.max(8, (day.count / maxDaily) * 100)}%` }} />
                    </div>
                    <span className="text-xs text-muted-foreground font-semibold tabular-nums">{day.date?.slice(5)}</span>
                    <span className="text-xs font-bold text-foreground tabular-nums">{day.count}</span>
                  </div>
                ))}
              </div>
            </div>
          </section>

          <section className="space-y-3">
            <div className="flex items-center gap-2 px-1">
              <Flame className="w-4 h-4 text-[color:var(--ac)]" />
              <p className="text-xs font-bold uppercase tracking-wide text-muted-foreground">Plats les plus vendus</p>
            </div>
            <div className="bg-card border border-border rounded-2xl p-4">
              {popularItems.length === 0 ? (
                <p className="text-sm text-muted-foreground">Aucune donnée de vente pour le moment.</p>
              ) : (
                <div className="divide-y divide-border">
                  {popularItems.map((item: any, i: number) => (
                    <div key={i} className="flex items-center justify-between gap-3 py-3 first:pt-0 last:pb-0">
                      <div className="flex items-center gap-3 min-w-0">
                        <span className="w-6 h-6 rounded-full bg-muted text-xs font-bold text-muted-foreground flex items-center justify-center tabular-nums flex-shrink-0">{i + 1}</span>
                        <span className="text-sm text-foreground truncate">{item.name}</span>
                      </div>
                      <span className="text-xs font-bold text-foreground tabular-nums flex-shrink-0">{item.totalSold} vendus</span>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </section>
        </>
      )}
    </div>
  );
}
