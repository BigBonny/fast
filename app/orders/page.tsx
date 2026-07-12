"use client";

import { useQuery } from "@tanstack/react-query";
import { orderApi } from "@/api/fastBackend";
import { ArrowLeft, Package, Clock, CheckCircle2, Bike, Inbox } from "lucide-react";
import { m } from "framer-motion";
import Link from "next/link";

const STATUS_CONFIG: Record<string, { label: string; color: string; icon: any }> = {
  PLACED: { label: "En attente", color: "#6b7280", icon: Clock },
  PREPARING: { label: "En préparation", color: "#8b5cf6", icon: Package },
  READY_FOR_PICKUP: { label: "Prête", color: "#f59e0b", icon: Bike },
  COMPLETED: { label: "Récupérée", color: "#10b981", icon: CheckCircle2 },
  CANCELLED: { label: "Annulée", color: "#ef4444", icon: Clock },
};

export default function OrdersPage() {
  const { data: orders = [], isLoading } = useQuery({
    queryKey: ["orders"],
    queryFn: () => orderApi.mine(),
    refetchInterval: 10000,
  });

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-screen">
        <div className="w-8 h-8 border-2 border-violet-500 border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50/50 pb-20">
      {/* Header */}
      <div className="bg-white/90 backdrop-blur-md px-5 py-4 border-b border-gray-100 sticky top-0 md:top-16 z-20">
        <div className="max-w-2xl mx-auto flex items-center gap-3">
          <Link href="/" className="w-9 h-9 bg-gray-50 rounded-xl flex items-center justify-center hover:bg-gray-100 transition-colors">
            <ArrowLeft className="w-4 h-4 text-gray-600" />
          </Link>
          <div>
            <h1 className="font-bold text-gray-900">Mes commandes</h1>
            <p className="text-xs text-gray-400">{orders.length} commande{orders.length > 1 ? "s" : ""}</p>
          </div>
        </div>
      </div>

      {orders.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-24 px-5">
          <div className="w-20 h-20 rounded-3xl bg-gray-100 flex items-center justify-center mb-4">
            <Inbox className="w-10 h-10 text-gray-300" />
          </div>
          <h2 className="font-bold text-gray-900 text-lg mb-1">Aucune commande</h2>
          <p className="text-sm text-gray-400 text-center mb-6">
            Passez votre première commande dès maintenant
          </p>
          <Link href="/">
            <m.button
              whileTap={{ scale: 0.98 }}
              className="px-6 py-3 rounded-xl font-bold text-white"
              style={{ background: "linear-gradient(135deg, #7c3aed, #06b6d4)" }}
            >
              Commander maintenant
            </m.button>
          </Link>
        </div>
      ) : (
        <div className="px-5 pt-4 space-y-3 max-w-2xl mx-auto">
          {orders.map((order: any, index: number) => {
            const status = STATUS_CONFIG[order.status] || STATUS_CONFIG.PLACED;
            const Icon = status.icon;
            const isActive = order.status !== "COMPLETED" && order.status !== "CANCELLED";

            return (
              <m.div
                key={order.id}
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: index * 0.05 }}
              >
                <Link href={`/order-tracking/${order.id}`}>
                  <div className={`bg-white rounded-2xl p-4 border ${isActive ? "border-violet-200" : "border-gray-100"} card-lift cursor-pointer`}>
                    <div className="flex items-start justify-between">
                      <div>
                        <h3 className="font-bold text-gray-900">{order.restaurant?.name || order.restaurantName || "Restaurant"}</h3>
                        <p className="text-xs text-gray-400 mt-0.5">#{order.id?.slice(-6).toUpperCase()}</p>
                      </div>
                      <div
                        className="flex items-center gap-1.5 px-2.5 py-1 rounded-full"
                        style={{ background: `${status.color}15` }}
                      >
                        <Icon className="w-3.5 h-3.5" style={{ color: status.color }} />
                        <span className="text-xs font-semibold" style={{ color: status.color }}>
                          {status.label}
                        </span>
                      </div>
                    </div>

                    <div className="flex items-center gap-4 mt-3 text-xs text-gray-500">
                      <span>{order.cartItems?.length || order.items?.length || 0} article{(order.cartItems?.length || order.items?.length || 0) > 1 ? "s" : ""}</span>
                      <span>•</span>
                      <span className="font-bold text-gray-900">{order.total?.toFixed(2)} €</span>
                      <span>•</span>
                      <span>{new Date(order.createdAt || order.created_date).toLocaleDateString("fr-FR")}</span>
                    </div>

                    {isActive && (
                      <div className="mt-3 flex items-center gap-2 text-violet-500 text-xs font-semibold">
                        <div className="w-1.5 h-1.5 rounded-full bg-violet-500 animate-pulse" />
                        Suivi en direct disponible
                      </div>
                    )}
                  </div>
                </Link>
              </m.div>
            );
          })}
        </div>
      )}
    </div>
  );
}
