"use client";

import { useQuery } from "@tanstack/react-query";
import { orderApi } from "@/api/fastBackend";
import {
  ArrowLeft, Package, Clock, CheckCircle2, Bike, Inbox,
  ChevronRight, Store, XCircle, Radio,
} from "lucide-react";
import { m } from "framer-motion";
import Link from "next/link";

const STATUS_CONFIG: Record<string, {
  label: string;
  icon: any;
  pill: string;
  step: number;
}> = {
  PLACED: {
    label: "En attente",
    icon: Clock,
    pill: "bg-muted text-foreground",
    step: 1,
  },
  PREPARING: {
    label: "En préparation",
    icon: Package,
    pill: "bg-fast-rose/10 text-fast-rose",
    step: 2,
  },
  READY_FOR_PICKUP: {
    label: "Prête",
    icon: Bike,
    pill: "bg-fast-gold text-fast-ink",
    step: 3,
  },
  COMPLETED: {
    label: "Récupérée",
    icon: CheckCircle2,
    pill: "bg-emerald-500/10 text-emerald-700 dark:text-emerald-400",
    step: 4,
  },
  CANCELLED: {
    label: "Annulée",
    icon: XCircle,
    pill: "bg-red-500/10 text-red-600 dark:text-red-400",
    step: 0,
  },
};

const TOTAL_STEPS = 4;

function OrderMeta({ order }: { order: any }) {
  const count = order.cartItems?.length || order.items?.length || 0;
  return (
    <div className="flex items-center gap-2 mt-4 text-sm text-muted-foreground">
      <span>{count} article{count > 1 ? "s" : ""}</span>
      <span aria-hidden="true">·</span>
      <span>
        {new Date(order.createdAt || order.created_date).toLocaleDateString("fr-FR", { day: "numeric", month: "short" })}
      </span>
      <span className="ml-auto font-bold text-foreground tabular-nums">{order.total?.toFixed(2)} €</span>
    </div>
  );
}

function StatusPill({ status }: { status: (typeof STATUS_CONFIG)[string] }) {
  const Icon = status.icon;
  return (
    <div className={`flex items-center gap-1.5 px-3 py-1.5 rounded-full shrink-0 ${status.pill}`}>
      <Icon className="w-3.5 h-3.5" />
      <span className="text-xs font-bold whitespace-nowrap">{status.label}</span>
    </div>
  );
}

export default function OrdersPage() {
  const { data: orders = [], isLoading } = useQuery({
    queryKey: ["orders"],
    queryFn: () => orderApi.mine(),
    refetchInterval: 10000,
  });

  const activeOrders = orders.filter((o: any) => o.status !== "COMPLETED" && o.status !== "CANCELLED");
  const pastOrders = orders.filter((o: any) => o.status === "COMPLETED" || o.status === "CANCELLED");

  return (
    <div className="min-h-screen bg-background pb-24">
      {/* Header */}
      <div className="bg-background/90 backdrop-blur-md px-4 sm:px-6 py-3 border-b border-border sticky top-0 md:top-16 z-20">
        <div className="max-w-2xl mx-auto flex items-center gap-3">
          <Link href="/" className="w-11 h-11 rounded-full border border-border bg-card flex items-center justify-center hover:bg-muted transition-colors active:scale-95 shrink-0">
            <ArrowLeft className="w-5 h-5 text-foreground" />
          </Link>
          <div className="flex-1 min-w-0">
            <h1 className="font-display font-bold text-xl text-foreground leading-tight">Mes commandes</h1>
            <p className="text-xs font-medium text-muted-foreground">
              {orders.length} commande{orders.length > 1 ? "s" : ""} au total
            </p>
          </div>
          {activeOrders.length > 0 && (
            <div className="flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-emerald-500/10">
              <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse" />
              <span className="text-xs font-bold text-emerald-700 dark:text-emerald-400">
                {activeOrders.length} en cours
              </span>
            </div>
          )}
        </div>
      </div>

      {isLoading ? (
        <div className="px-4 sm:px-6 pt-6 space-y-3 max-w-2xl mx-auto">
          {[1, 2, 3].map((i) => (
            <div key={i} className="h-32 rounded-2xl skeleton-shimmer" />
          ))}
        </div>
      ) : orders.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-24 px-4">
          <div className="w-24 h-24 rounded-full bg-muted flex items-center justify-center mb-6">
            <Inbox className="w-10 h-10 text-muted-foreground" />
          </div>
          <h2 className="font-display font-bold text-foreground text-2xl mb-2">Aucune commande</h2>
          <p className="text-sm text-muted-foreground text-center mb-7 max-w-[260px]">
            Passez votre première commande et suivez-la ici en temps réel
          </p>
          <Link href="/">
            <m.button whileTap={{ scale: 0.96 }} className="btn-neon">
              Commander maintenant
            </m.button>
          </Link>
        </div>
      ) : (
        <div className="px-4 sm:px-6 pt-6 max-w-2xl mx-auto space-y-10">
          {/* Active orders */}
          {activeOrders.length > 0 && (
            <section>
              <div className="flex items-center gap-2 mb-4 border-b border-border">
                <h2 className="inline-flex items-center gap-2 font-display font-bold text-xl text-foreground pb-2 border-b-2 border-fast-rose -mb-px">
                  <Radio className="w-4 h-4 text-fast-rose" />
                  En cours
                </h2>
              </div>
              <div className="space-y-3">
                {activeOrders.map((order: any, index: number) => {
                  const status = STATUS_CONFIG[order.status] || STATUS_CONFIG.PLACED;
                  const progress = (status.step / TOTAL_STEPS) * 100;

                  return (
                    <m.div
                      key={order.id}
                      initial={{ opacity: 0, y: 12 }}
                      animate={{ opacity: 1, y: 0 }}
                      transition={{ delay: index * 0.06 }}
                    >
                      <Link href={`/order-tracking/${order.id}`} className="block">
                        <div className="bg-card border border-border rounded-2xl p-4 card-lift cursor-pointer active:scale-[0.98] transition-transform">
                          <div className="flex items-start justify-between gap-3">
                            <div className="flex items-center gap-3 min-w-0">
                              <div className="w-11 h-11 rounded-full bg-fast-rose/10 flex items-center justify-center shrink-0">
                                <Store className="w-5 h-5 text-fast-rose" />
                              </div>
                              <div className="min-w-0">
                                <h3 className="font-display font-bold text-lg text-foreground truncate leading-tight">
                                  {order.restaurant?.name || order.restaurantName || "Restaurant"}
                                </h3>
                                <p className="text-xs font-semibold text-muted-foreground mt-0.5 tabular-nums">
                                  #{order.id?.slice(-6).toUpperCase()}
                                </p>
                              </div>
                            </div>
                            <StatusPill status={status} />
                          </div>

                          {/* Progress */}
                          <div className="mt-4">
                            <div className="h-1.5 rounded-full bg-muted overflow-hidden">
                              <m.div
                                className="h-full rounded-full bg-neon"
                                initial={{ width: 0 }}
                                animate={{ width: `${progress}%` }}
                                transition={{ duration: 0.8, ease: "easeOut" }}
                              />
                            </div>
                            <div className="flex items-center justify-between mt-2">
                              <span className="text-xs font-bold text-muted-foreground tabular-nums">
                                Étape {status.step}/{TOTAL_STEPS}
                              </span>
                              <span className="flex items-center gap-1.5 text-xs font-bold text-fast-rose">
                                <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse" />
                                Suivi en direct
                                <ChevronRight className="w-3.5 h-3.5" />
                              </span>
                            </div>
                          </div>

                          <OrderMeta order={order} />
                        </div>
                      </Link>
                    </m.div>
                  );
                })}
              </div>
            </section>
          )}

          {/* Past orders */}
          {pastOrders.length > 0 && (
            <section>
              <div className="flex items-center gap-2 mb-4 border-b border-border">
                <h2 className="inline-flex items-center gap-2 font-display font-bold text-xl text-foreground pb-2 -mb-px">
                  <Clock className="w-4 h-4 text-muted-foreground" />
                  Historique
                </h2>
              </div>
              <div className="space-y-3">
                {pastOrders.map((order: any, index: number) => {
                  const status = STATUS_CONFIG[order.status] || STATUS_CONFIG.PLACED;

                  return (
                    <m.div
                      key={order.id}
                      initial={{ opacity: 0, y: 10 }}
                      animate={{ opacity: 1, y: 0 }}
                      transition={{ delay: 0.1 + index * 0.04 }}
                    >
                      <Link href={`/order-tracking/${order.id}`} className="block">
                        <div className="bg-card rounded-2xl p-4 border border-border card-lift cursor-pointer active:scale-[0.98] transition-transform">
                          <div className="flex items-start justify-between gap-3">
                            <div className="flex items-center gap-3 min-w-0">
                              <div className="w-11 h-11 rounded-full bg-muted flex items-center justify-center shrink-0">
                                <Store className="w-5 h-5 text-muted-foreground" />
                              </div>
                              <div className="min-w-0">
                                <h3 className="font-bold text-foreground truncate">
                                  {order.restaurant?.name || order.restaurantName || "Restaurant"}
                                </h3>
                                <p className="text-xs font-medium text-muted-foreground mt-0.5 tabular-nums">
                                  #{order.id?.slice(-6).toUpperCase()}
                                </p>
                              </div>
                            </div>
                            <StatusPill status={status} />
                          </div>
                          <OrderMeta order={order} />
                        </div>
                      </Link>
                    </m.div>
                  );
                })}
              </div>
            </section>
          )}
        </div>
      )}
    </div>
  );
}
