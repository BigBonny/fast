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
    pill: "bg-sky-50 text-sky-600 dark:bg-sky-500/10 dark:text-sky-400",
    step: 1,
  },
  PREPARING: {
    label: "En préparation",
    icon: Package,
    pill: "bg-violet-50 text-violet-600 dark:bg-violet-500/10 dark:text-violet-400",
    step: 2,
  },
  READY_FOR_PICKUP: {
    label: "Prête",
    icon: Bike,
    pill: "bg-amber-50 text-amber-600 dark:bg-amber-500/10 dark:text-amber-400",
    step: 3,
  },
  COMPLETED: {
    label: "Récupérée",
    icon: CheckCircle2,
    pill: "bg-emerald-50 text-emerald-600 dark:bg-emerald-500/10 dark:text-emerald-400",
    step: 4,
  },
  CANCELLED: {
    label: "Annulée",
    icon: XCircle,
    pill: "bg-red-50 text-red-500 dark:bg-red-500/10 dark:text-red-400",
    step: 0,
  },
};

const TOTAL_STEPS = 4;

function OrderMeta({ order }: { order: any }) {
  const count = order.cartItems?.length || order.items?.length || 0;
  return (
    <div className="flex items-center gap-2 mt-3 text-xs text-gray-500 dark:text-gray-400">
      <span>{count} article{count > 1 ? "s" : ""}</span>
      <span className="text-gray-300 dark:text-gray-700">•</span>
      <span className="font-bold text-gray-900 dark:text-white">{order.total?.toFixed(2)} €</span>
      <span className="text-gray-300 dark:text-gray-700">•</span>
      <span>
        {new Date(order.createdAt || order.created_date).toLocaleDateString("fr-FR", { day: "numeric", month: "short" })}
      </span>
    </div>
  );
}

function StatusPill({ status }: { status: (typeof STATUS_CONFIG)[string] }) {
  const Icon = status.icon;
  return (
    <div className={`flex items-center gap-1.5 px-2.5 py-1 rounded-full shrink-0 ${status.pill}`}>
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
    <div className="min-h-screen bg-gray-50/50 dark:bg-gray-950 pb-24">
      {/* Header */}
      <div className="bg-white/90 dark:bg-gray-950/90 backdrop-blur-md px-5 pt-4 pb-3 border-b border-gray-100 dark:border-gray-800/80 sticky top-0 md:top-16 z-20">
        <div className="max-w-2xl mx-auto flex items-center gap-3">
          <Link href="/" className="w-9 h-9 bg-gray-100 dark:bg-gray-800/80 rounded-xl flex items-center justify-center hover:bg-gray-200 dark:hover:bg-gray-700 transition-colors active:scale-95">
            <ArrowLeft className="w-4 h-4 text-gray-600 dark:text-gray-300" />
          </Link>
          <div className="flex-1">
            <h1 className="font-black text-lg text-gray-900 dark:text-white leading-tight">Mes commandes</h1>
            <p className="text-[11px] font-medium text-gray-400 dark:text-gray-500">
              {orders.length} commande{orders.length > 1 ? "s" : ""} au total
            </p>
          </div>
          {activeOrders.length > 0 && (
            <div className="flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-emerald-50 dark:bg-emerald-500/10">
              <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse" />
              <span className="text-[11px] font-bold text-emerald-600 dark:text-emerald-400">
                {activeOrders.length} en cours
              </span>
            </div>
          )}
        </div>
      </div>

      {isLoading ? (
        <div className="px-5 pt-5 space-y-3 max-w-2xl mx-auto">
          {[1, 2, 3].map((i) => (
            <div key={i} className="h-32 rounded-3xl skeleton-shimmer" />
          ))}
        </div>
      ) : orders.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-24 px-5">
          <div className="w-24 h-24 rounded-[28px] bg-gradient-to-br from-violet-100 to-cyan-100 dark:from-violet-500/10 dark:to-cyan-500/10 flex items-center justify-center mb-5 rotate-3">
            <Inbox className="w-11 h-11 text-violet-400 dark:text-violet-500/70 -rotate-3" />
          </div>
          <h2 className="font-black text-gray-900 dark:text-white text-xl mb-1.5">Aucune commande</h2>
          <p className="text-sm text-gray-400 dark:text-gray-500 text-center mb-7 max-w-[240px]">
            Passez votre première commande et suivez-la ici en temps réel
          </p>
          <Link href="/">
            <m.button
              whileTap={{ scale: 0.96 }}
              className="px-7 py-3.5 rounded-2xl font-black text-white shadow-lg shadow-violet-500/25"
              style={{ background: "linear-gradient(135deg, #7c3aed, #06b6d4)" }}
            >
              Commander maintenant
            </m.button>
          </Link>
        </div>
      ) : (
        <div className="px-5 pt-5 max-w-2xl mx-auto space-y-7">
          {/* Active orders */}
          {activeOrders.length > 0 && (
            <section>
              <div className="flex items-center gap-2 mb-3">
                <Radio className="w-4 h-4 text-emerald-500" />
                <h2 className="font-black text-sm uppercase tracking-wider text-gray-900 dark:text-white">En cours</h2>
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
                      <Link href={`/order-tracking/${order.id}`}>
                        <div className="relative rounded-3xl p-[1.5px] bg-gradient-to-br from-violet-400/60 via-cyan-400/40 to-emerald-400/60 card-lift cursor-pointer active:scale-[0.98] transition-transform">
                          <div className="bg-white dark:bg-gray-900 rounded-[calc(1.5rem-1.5px)] p-4">
                            <div className="flex items-start justify-between gap-3">
                              <div className="flex items-center gap-3 min-w-0">
                                <div className="w-11 h-11 rounded-2xl bg-gradient-to-br from-violet-500 to-cyan-500 flex items-center justify-center shrink-0 shadow-md shadow-violet-500/20">
                                  <Store className="w-5 h-5 text-white" />
                                </div>
                                <div className="min-w-0">
                                  <h3 className="font-extrabold text-gray-900 dark:text-white truncate">
                                    {order.restaurant?.name || order.restaurantName || "Restaurant"}
                                  </h3>
                                  <p className="text-[11px] font-semibold text-gray-400 dark:text-gray-500 mt-0.5">
                                    #{order.id?.slice(-6).toUpperCase()}
                                  </p>
                                </div>
                              </div>
                              <StatusPill status={status} />
                            </div>

                            {/* Progress */}
                            <div className="mt-4">
                              <div className="h-1.5 rounded-full bg-gray-100 dark:bg-gray-800 overflow-hidden">
                                <m.div
                                  className="h-full rounded-full"
                                  style={{ background: "linear-gradient(90deg, #8b5cf6, #06b6d4)" }}
                                  initial={{ width: 0 }}
                                  animate={{ width: `${progress}%` }}
                                  transition={{ duration: 0.8, ease: "easeOut" }}
                                />
                              </div>
                              <div className="flex items-center justify-between mt-2">
                                <span className="text-[11px] font-bold text-gray-400 dark:text-gray-500">
                                  Étape {status.step}/{TOTAL_STEPS}
                                </span>
                                <span className="flex items-center gap-1.5 text-[11px] font-bold text-emerald-500">
                                  <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse" />
                                  Suivi en direct
                                  <ChevronRight className="w-3.5 h-3.5" />
                                </span>
                              </div>
                            </div>

                            <OrderMeta order={order} />
                          </div>
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
              <div className="flex items-center gap-2 mb-3">
                <Clock className="w-4 h-4 text-gray-400 dark:text-gray-500" />
                <h2 className="font-black text-sm uppercase tracking-wider text-gray-500 dark:text-gray-400">Historique</h2>
              </div>
              <div className="space-y-2.5">
                {pastOrders.map((order: any, index: number) => {
                  const status = STATUS_CONFIG[order.status] || STATUS_CONFIG.PLACED;

                  return (
                    <m.div
                      key={order.id}
                      initial={{ opacity: 0, y: 10 }}
                      animate={{ opacity: 1, y: 0 }}
                      transition={{ delay: 0.1 + index * 0.04 }}
                    >
                      <Link href={`/order-tracking/${order.id}`}>
                        <div className="bg-white dark:bg-gray-900 rounded-2xl p-4 border border-gray-100 dark:border-gray-800/80 card-lift cursor-pointer active:scale-[0.98] transition-transform">
                          <div className="flex items-start justify-between gap-3">
                            <div className="flex items-center gap-3 min-w-0">
                              <div className="w-10 h-10 rounded-xl bg-gray-100 dark:bg-gray-800 flex items-center justify-center shrink-0">
                                <Store className="w-5 h-5 text-gray-400 dark:text-gray-500" />
                              </div>
                              <div className="min-w-0">
                                <h3 className="font-bold text-gray-900 dark:text-white text-sm truncate">
                                  {order.restaurant?.name || order.restaurantName || "Restaurant"}
                                </h3>
                                <p className="text-[11px] font-medium text-gray-400 dark:text-gray-500 mt-0.5">
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
