"use client";

import { Suspense } from "react";
import { useQuery } from "@tanstack/react-query";
import { orderApi } from "@/api/fastBackend";
import { m, AnimatePresence } from "framer-motion";
import { ArrowLeft, Star, Clock, CheckCircle2, Circle, ChefHat, Package, Bike, PartyPopper, Inbox } from "lucide-react";
import Link from "next/link";
import { useParams } from "next/navigation";

const STATUS_STEPS = [
  { key: "PLACED", label: "Commande reçue", icon: Circle, color: "var(--fast-rose)" },
  { key: "PREPARING", label: "En préparation", icon: ChefHat, color: "var(--fast-rose)" },
  { key: "READY_FOR_PICKUP", label: "Prête à récupérer", icon: Package, color: "var(--fast-rose)" },
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
      <div className="min-h-screen flex items-center justify-center bg-background">
        <div className="w-10 h-10 border-4 border-fast-rose border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  if (!order) {
    return (
      <div className="min-h-screen flex flex-col items-center justify-center px-4 bg-background">
        <div className="w-24 h-24 rounded-full bg-muted flex items-center justify-center mb-6">
          <Inbox className="w-10 h-10 text-muted-foreground" />
        </div>
        <p className="font-display text-foreground font-bold text-2xl mb-2">Aucune commande active</p>
        <p className="text-muted-foreground text-sm text-center max-w-xs">Tes commandes apparaîtront ici une fois passées.</p>
        <Link href="/" className="mt-7">
          <button className="btn-neon">
            Commander maintenant
          </button>
        </Link>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background pb-24">
      {/* Header */}
      <div className="px-4 sm:px-6 pt-4 pb-4 flex items-center justify-between gap-3 max-w-2xl mx-auto">
        <Link href="/orders">
          <button className="w-11 h-11 rounded-full border border-border bg-card flex items-center justify-center hover:bg-muted transition-colors">
            <ArrowLeft className="w-5 h-5 text-foreground" />
          </button>
        </Link>
        <div className="flex items-center gap-1.5 bg-emerald-500/10 rounded-full px-3 py-1.5">
          <div className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse" />
          <span className="text-emerald-700 dark:text-emerald-400 text-xs font-bold tracking-wide">EN DIRECT</span>
        </div>
      </div>

      {/* Commande */}
      <div className="px-4 sm:px-6 max-w-2xl mx-auto mb-8">
        <div className="night-surface p-6 text-center">
          <p className="on-night-muted text-xs font-bold tracking-wide tabular-nums">#{order.id?.slice(-6).toUpperCase()}</p>
          <p className="font-display font-extrabold text-3xl leading-tight mt-2">{order.restaurant?.name || "Restaurant"}</p>
          <span className="inline-flex items-center rounded-full bg-white/10 border border-white/15 px-3 py-1.5 text-xs font-bold mt-4">
            {STATUS_STEPS[currentStep]?.label}
          </span>
        </div>
      </div>

      {/* Étapes de progression */}
      <div className="mx-4 sm:mx-6 md:mx-auto md:max-w-2xl rounded-2xl border border-border bg-card p-5 mb-5">
        <p className="font-display text-foreground font-bold text-lg mb-5">Progression de ta commande</p>

        <div className="relative">
          <div className="absolute left-4 top-4 bottom-4 w-0.5 bg-border" />
          <div
            className="absolute left-4 top-4 w-0.5 transition-all duration-1000 bg-fast-rose"
            style={{
              height: `${(currentStep / (STATUS_STEPS.length - 1)) * 100}%`,
            }}
          />

          <div className="space-y-5">
            {STATUS_STEPS.map((step, index) => {
              const isDone = index <= currentStep;
              const isCurrent = index === currentStep;
              const Icon = step.icon;

              return (
                <m.div
                  key={step.key}
                  className="flex items-center gap-4 relative"
                  initial={{ opacity: 0, x: -10 }}
                  animate={{ opacity: 1, x: 0 }}
                  transition={{ delay: index * 0.08 }}
                >
                  <div
                    className={`w-8 h-8 rounded-full flex items-center justify-center z-10 transition-all duration-500 ${isDone ? "" : "bg-muted"} ${isCurrent ? "ring-2 ring-fast-rose/40 ring-offset-2 ring-offset-card" : ""}`}
                    style={isDone ? { background: step.color } : undefined}
                  >
                    <Icon className={`w-4 h-4 ${isDone ? "text-white" : "text-muted-foreground"}`} />
                  </div>

                  <div className="flex-1">
                    <p className={`text-sm font-bold transition-colors ${isDone ? "text-foreground" : "text-muted-foreground"}`}>
                      {step.label}
                    </p>
                    {isCurrent && (
                      <m.p
                        className="text-xs font-semibold mt-0.5"
                        style={{ color: step.color }}
                        initial={{ opacity: 0 }}
                        animate={{ opacity: 1 }}
                      >
                        Étape en cours...
                      </m.p>
                    )}
                  </div>

                  {isCurrent && (
                    <div className="w-2 h-2 rounded-full animate-pulse" style={{ background: step.color }} />
                  )}
                  {isDone && index < currentStep && (
                    <CheckCircle2 className="w-4 h-4 text-emerald-500" />
                  )}
                </m.div>
              );
            })}
          </div>
        </div>
      </div>

      {/* Récapitulatif commande */}
      <div className="mx-4 sm:mx-6 md:mx-auto md:max-w-2xl rounded-2xl border border-border bg-card p-5 mb-6">
        <p className="font-display text-foreground font-bold text-lg mb-4">Récapitulatif</p>
        <div className="space-y-2.5">
          {(order.items || []).map((item, i) => {
            const qty = item.quantity || 1;
            const name = item.menuItem?.name || "Article";
            const price = item.menuItem?.price ?? item.price ?? 0;
            return (
              <div key={i} className="flex items-center justify-between gap-3">
                <span className="text-muted-foreground text-sm">
                  {qty}x {name}
                </span>
                <span className="text-foreground text-sm font-bold tabular-nums">
                  {(price * qty).toFixed(2)}€
                </span>
              </div>
            );
          })}
        </div>
        <div className="mt-4 pt-4 border-t border-border flex justify-between items-center">
          <span className="text-foreground text-sm font-bold">Total</span>
          <span className="text-foreground font-extrabold text-lg tabular-nums">{order.total?.toFixed(2)}€</span>
        </div>
      </div>
    </div>
  );
}

export default function OrderTrackingPage({ params }: { params: { id: string } }) {
  return (
    <Suspense fallback={<div className="min-h-screen flex items-center justify-center bg-background">
      <div className="w-10 h-10 border-4 border-fast-rose border-t-transparent rounded-full animate-spin" />
    </div>}>
      <OrderTrackingContent orderId={params.id} />
    </Suspense>
  );
}
