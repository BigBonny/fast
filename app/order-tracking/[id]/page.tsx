"use client";

import { Suspense } from "react";
import { useQuery } from "@tanstack/react-query";
import { orderApi } from "@/api/fastBackend";
import { motion, AnimatePresence } from "framer-motion";
import { ArrowLeft, Star, Clock, CheckCircle2, Circle, ChefHat, Package, Bike, PartyPopper } from "lucide-react";
import Link from "next/link";
import { useParams } from "next/navigation";

const STATUS_STEPS = [
  { key: "PLACED", label: "Commande reçue", icon: Circle, color: "#6b7280" },
  { key: "PREPARING", label: "En préparation", icon: ChefHat, color: "#8b5cf6" },
  { key: "READY_FOR_PICKUP", label: "Prête à récupérer", icon: Package, color: "#f59e0b" },
  { key: "COMPLETED", label: "Récupérée !", icon: PartyPopper, color: "#10b981" },
];

const STATUS_INDEX: Record<string, number> = {
  PLACED: 0,
  PREPARING: 1,
  READY_FOR_PICKUP: 2,
  COMPLETED: 3,
};

function OrderTrackingContent({ orderId }: { orderId: string }) {
  const { data: orders, isLoading } = useQuery({
    queryKey: ["orders"],
    queryFn: () => orderApi.mine(),
    refetchInterval: 5000,
  });
  const order = orders?.find((o: any) => o.id === orderId);

  const currentStep = STATUS_INDEX[order?.status] ?? 0;

  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center" style={{ background: "#0a0e1a" }}>
        <div className="w-10 h-10 border-4 border-violet-500 border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  if (!order) {
    return (
      <div className="min-h-screen flex flex-col items-center justify-center gap-4 px-6" style={{ background: "#0a0e1a" }}>
        <div className="text-6xl">📭</div>
        <p className="text-white font-bold text-lg">Aucune commande active</p>
        <p className="text-gray-400 text-sm text-center">Tes commandes apparaîtront ici une fois passées.</p>
        <Link href="/">
          <button className="mt-4 px-6 py-3 rounded-xl font-bold text-white" style={{ background: "linear-gradient(135deg, #7c3aed, #06b6d4)" }}>
            Commander maintenant
          </button>
        </Link>
      </div>
    );
  }

  return (
    <div className="min-h-screen" style={{ background: "#0a0e1a" }}>
      {/* Header */}
      <div className="px-5 pt-5 pb-4 flex items-center justify-between">
        <Link href="/orders">
          <button className="w-9 h-9 rounded-xl bg-white/10 flex items-center justify-center">
            <ArrowLeft className="w-4 h-4 text-white" />
          </button>
        </Link>
        <div className="text-center">
          <p className="text-white font-black text-base">{order.restaurant?.name || order.restaurantName || "Restaurant"}</p>
          <p className="text-gray-400 text-xs">#{order.id?.slice(-6).toUpperCase()}</p>
        </div>
        <div className="flex items-center gap-1.5 bg-emerald-500/20 rounded-full px-3 py-1">
          <div className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
          <span className="text-emerald-400 text-xs font-bold">EN DIRECT</span>
        </div>
      </div>

      {/* Étapes de progression */}
      <div className="mx-5 rounded-2xl p-5 mb-5" style={{ background: "#1a1f2e" }}>
        <p className="text-white font-black text-sm mb-4">Progression de ta commande</p>

        <div className="relative">
          <div className="absolute left-4 top-4 bottom-4 w-0.5" style={{ background: "#2a2f3e" }} />
          <div
            className="absolute left-4 top-4 w-0.5 transition-all duration-1000"
            style={{
              background: "linear-gradient(180deg, #06b6d4, #8b5cf6)",
              height: `${(currentStep / (STATUS_STEPS.length - 1)) * 100}%`,
            }}
          />

          <div className="space-y-5">
            {STATUS_STEPS.map((step, index) => {
              const isDone = index <= currentStep;
              const isCurrent = index === currentStep;
              const Icon = step.icon;

              return (
                <motion.div
                  key={step.key}
                  className="flex items-center gap-4 relative"
                  initial={{ opacity: 0, x: -10 }}
                  animate={{ opacity: 1, x: 0 }}
                  transition={{ delay: index * 0.08 }}
                >
                  <div
                    className={`w-8 h-8 rounded-full flex items-center justify-center z-10 transition-all duration-500 ${isCurrent ? "ring-2 ring-offset-2 ring-offset-[#1a1f2e]" : ""}`}
                    style={{
                      background: isDone ? step.color : "#2a2f3e",
                    }}
                  >
                    <Icon className="w-4 h-4" style={{ color: isDone ? "white" : "#4b5563" }} />
                  </div>

                  <div className="flex-1">
                    <p className={`text-sm font-bold transition-colors ${isDone ? "text-white" : "text-gray-600"}`}>
                      {step.label}
                    </p>
                    {isCurrent && (
                      <motion.p
                        className="text-xs mt-0.5"
                        style={{ color: step.color }}
                        initial={{ opacity: 0 }}
                        animate={{ opacity: 1 }}
                      >
                        Étape en cours...
                      </motion.p>
                    )}
                  </div>

                  {isCurrent && (
                    <div className="w-2 h-2 rounded-full animate-pulse" style={{ background: step.color }} />
                  )}
                  {isDone && index < currentStep && (
                    <CheckCircle2 className="w-4 h-4 text-emerald-500" />
                  )}
                </motion.div>
              );
            })}
          </div>
        </div>
      </div>

      {/* Récapitulatif commande */}
      <div className="mx-5 rounded-2xl p-5 mb-6" style={{ background: "#1a1f2e" }}>
        <p className="text-white font-black text-sm mb-3">Récapitulatif</p>
        <div className="space-y-2">
          {(order.cartItems || order.items || []).map((item: any, i: number) => {
            const qty = item.quantity || item.qty || 1;
            const name = item.menuItem?.name || item.name || "Article";
            const price = item.menuItem?.price || item.price || 0;
            return (
              <div key={i} className="flex items-center justify-between">
                <span className="text-gray-300 text-sm">
                  {qty}x {name}
                </span>
                <span className="text-white text-sm font-bold">
                  {(price * qty).toFixed(2)}€
                </span>
              </div>
            );
          })}
        </div>
        <div className="mt-3 pt-3 border-t border-white/10 flex justify-between">
          <span className="text-gray-400 text-sm">Total</span>
          <span className="text-yellow-400 font-black">{order.total?.toFixed(2)}€</span>
        </div>
      </div>
    </div>
  );
}

export default function OrderTrackingPage({ params }: { params: { id: string } }) {
  return (
    <Suspense fallback={<div className="min-h-screen flex items-center justify-center" style={{ background: "#0a0e1a" }}>
      <div className="w-10 h-10 border-4 border-violet-500 border-t-transparent rounded-full animate-spin" />
    </div>}>
      <OrderTrackingContent orderId={params.id} />
    </Suspense>
  );
}
