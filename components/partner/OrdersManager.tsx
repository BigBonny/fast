"use client";

import { useState } from "react";
import { useQuery, useQueryClient, useMutation } from "@tanstack/react-query";
import { m } from "framer-motion";
import { Clock, Package, CheckCircle, XCircle, ChefHat, Utensils, User, ChevronDown, ChevronUp, type LucideIcon } from "lucide-react";
import { orderApi, getErrorMessage } from "@/api/fastBackend";
import type { Order, OrderStatus } from "@/lib/types";
import { showToast } from "@/components/partner/Toast";

// `color` is the status hue staff read; `dot`, `tint` and `border` are the
// same hue as a chip dot, chip background and card border.
const STATUS_TABS = [
  { id: "ALL", label: "Toutes", color: "text-white", dot: "", tint: "bg-muted", border: "border-border" },
  { id: "PLACED", label: "Nouvelles", color: "text-blue-400", dot: "bg-blue-400", tint: "bg-blue-400/15", border: "border-blue-400" },
  { id: "PREPARING", label: "En prep", color: "text-yellow-400", dot: "bg-yellow-400", tint: "bg-yellow-400/15", border: "border-yellow-400" },
  { id: "READY_FOR_PICKUP", label: "Prêtes", color: "text-orange-400", dot: "bg-orange-400", tint: "bg-orange-400/15", border: "border-orange-400" },
  { id: "COMPLETED", label: "Terminées", color: "text-green-400", dot: "bg-green-400", tint: "bg-green-400/15", border: "border-border" },
  { id: "CANCELLED", label: "Annulées", color: "text-red-400", dot: "bg-red-400", tint: "bg-red-400/15", border: "border-border" },
];

const STATUS_LABELS: Record<OrderStatus, string> = {
  PLACED: "Reçue",
  PREPARING: "En préparation",
  READY_FOR_PICKUP: "Prête à récupérer",
  COMPLETED: "Terminée",
  CANCELLED: "Annulée",
};

const STATUS_ACTIONS: Partial<
  Record<OrderStatus, { next: OrderStatus; label: string; icon: LucideIcon; color: string }[]>
> = {
  PLACED: [{ next: "PREPARING", label: "Préparer", icon: ChefHat, color: "bg-yellow-500 text-fast-ink" }],
  PREPARING: [{ next: "READY_FOR_PICKUP", label: "Prête", icon: Utensils, color: "bg-orange-500 text-white" }],
  READY_FOR_PICKUP: [{ next: "COMPLETED", label: "Récupérée", icon: CheckCircle, color: "bg-green-500 text-white" }],
};

export default function OrdersManager() {
  const queryClient = useQueryClient();
  const [activeTab, setActiveTab] = useState("ALL");
  const [expanded, setExpanded] = useState<Record<string, boolean>>({});

  const { data: orders = [], isLoading } = useQuery({
    queryKey: ["orders"],
    queryFn: () => orderApi.restaurantOrders(),
    refetchInterval: 10000,
  });

  const filtered = activeTab === "ALL" ? orders : orders.filter((o: Order) => o.status === activeTab);

  const updateMutation = useMutation({
    mutationFn: ({ id, status }: { id: string; status: OrderStatus }) => orderApi.updateStatus(id, status),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["orders"] });
      showToast("Statut mis à jour");
    },
    onError: (err: unknown) => showToast(getErrorMessage(err)),
  });

  const formatTime = (date: string) => {
    const d = new Date(date);
    return d.toLocaleTimeString("fr-FR", { hour: "2-digit", minute: "2-digit" });
  };

  const toggleExpand = (id: string) => setExpanded((prev) => ({ ...prev, [id]: !prev[id] }));

  return (
    <div className="space-y-5">
      <div className="flex items-end justify-between gap-3">
        <h1 className="font-display text-2xl font-bold text-foreground">Commandes</h1>
        <span className="text-xs text-muted-foreground tabular-nums">{orders.length} commande{orders.length > 1 ? "s" : ""}</span>
      </div>

      <div className="flex overflow-x-auto gap-2 pb-1 scrollbar-hide">
        {STATUS_TABS.map((tab) => {
          const count = tab.id === "ALL" ? orders.length : orders.filter((o: any) => o.status === tab.id).length;
          const active = activeTab === tab.id;
          return (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              aria-pressed={active}
              className={`flex-shrink-0 inline-flex items-center gap-1.5 px-4 h-11 rounded-full text-xs font-bold border transition-colors focus-visible:outline-fast-teal ${
                active ? "bg-fast-teal/15 border-fast-teal text-foreground" : "bg-card border-border text-muted-foreground hover:text-foreground"
              }`}
            >
              {tab.dot && <span className={`w-2 h-2 rounded-full ${tab.dot}`} aria-hidden="true" />}
              {tab.label} <span className="opacity-70 tabular-nums">({count})</span>
            </button>
          );
        })}
      </div>

      {isLoading ? (
        <div className="py-12 text-center text-muted-foreground text-sm">Chargement des commandes...</div>
      ) : filtered.length === 0 ? (
        <div className="bg-card border border-border rounded-2xl p-8 text-center text-muted-foreground text-sm">
          <Package className="w-8 h-8 mx-auto mb-2 text-muted-foreground" />Aucune commande dans cette catégorie.
        </div>
      ) : (
        <div className="space-y-3">
          {filtered.map((order: any) => {
            const style = STATUS_TABS.find((t) => t.id === order.status);
            const StatusIcon = order.status === "COMPLETED" ? CheckCircle : order.status === "CANCELLED" ? XCircle : Package;
            return (
              <m.div key={order.id} layout className={`bg-card border-2 ${style?.border || "border-border"} rounded-2xl overflow-hidden`}>
                <button
                  onClick={() => toggleExpand(order.id)}
                  aria-expanded={!!expanded[order.id]}
                  className="w-full px-4 py-3.5 flex items-center gap-3 focus-visible:outline-fast-teal"
                >
                  <div className="w-11 h-11 rounded-xl bg-muted text-muted-foreground flex items-center justify-center flex-shrink-0">
                    <StatusIcon className="w-5 h-5" />
                  </div>
                  <div className="flex-1 min-w-0 text-left">
                    <div className="flex items-center gap-2 flex-wrap">
                      <span className="text-sm font-bold text-foreground tabular-nums">#{order.id?.slice(-6).toUpperCase()}</span>
                      <span className={`inline-flex items-center gap-1.5 text-xs font-bold px-2.5 py-1 rounded-full text-foreground ${style?.tint || "bg-muted"}`}>
                        {style?.dot && <span className={`w-2 h-2 rounded-full ${style.dot}`} aria-hidden="true" />}
                        {STATUS_LABELS[order.status as OrderStatus] || order.status}
                      </span>
                    </div>
                    <div className="text-xs text-muted-foreground flex items-center gap-2 mt-1">
                      <User className="w-3.5 h-3.5" /> {order.user?.name || "Client"}
                      <Clock className="w-3.5 h-3.5 ml-1" /> <span className="tabular-nums">{formatTime(order.createdAt)}</span>
                    </div>
                  </div>
                  <div className="flex flex-col items-end gap-1">
                    <p className="text-base font-bold text-foreground tabular-nums">{order.total?.toFixed(2)} </p>
                    {expanded[order.id] ? <ChevronUp className="w-4 h-4 text-muted-foreground" /> : <ChevronDown className="w-4 h-4 text-muted-foreground" />}
                  </div>
                </button>

                {expanded[order.id] && (
                  <div className="px-4 pb-4 border-t border-border">
                    <div className="py-3 space-y-2">
                      {order.items?.map((item: any) => (
                        <div key={item.id} className="flex items-center justify-between gap-3 text-sm">
                          <span className="text-foreground"><span className="font-bold tabular-nums">{item.quantity}x</span> {item.menuItem?.name || "Article"}</span>
                          <span className="text-muted-foreground tabular-nums">{(item.quantity * (item.menuItem?.price || 0)).toFixed(2)} </span>
                        </div>
                      ))}
                      {order.allergyNotes && <div className="text-xs font-semibold text-foreground bg-yellow-400/15 border border-yellow-400/50 rounded-xl px-3 py-2">Allergies/notes: {order.allergyNotes}</div>}
                      <div className="flex items-center justify-between text-xs text-muted-foreground pt-2 border-t border-border"><span>Sous-total</span><span className="tabular-nums">{order.subtotal?.toFixed(2)} </span></div>
                      <div className="flex items-center justify-between text-xs text-muted-foreground"><span>Frais de service</span><span className="tabular-nums">{order.serviceFee?.toFixed(2)} </span></div>
                    </div>
                    <div className="flex flex-wrap gap-2 mt-1">
                      {(STATUS_ACTIONS[order.status as OrderStatus] || []).map((action) => {
                        const Icon = action.icon;
                        return (
                          <button key={action.next} onClick={() => updateMutation.mutate({ id: order.id, status: action.next })} disabled={updateMutation.isPending} className={`inline-flex items-center justify-center gap-2 px-5 h-12 rounded-full text-sm font-bold ${action.color} transition-transform active:scale-[0.97] disabled:opacity-50`}>
                            <Icon className="w-4 h-4" /> {action.label}
                          </button>
                        );
                      })}
                      {order.status !== "CANCELLED" && order.status !== "COMPLETED" && (
                        <button onClick={() => updateMutation.mutate({ id: order.id, status: "CANCELLED" })} disabled={updateMutation.isPending} className="inline-flex items-center justify-center gap-2 px-5 h-12 rounded-full text-sm font-bold text-white bg-red-500 transition-transform active:scale-[0.97] disabled:opacity-50">
                          <XCircle className="w-4 h-4" /> Annuler
                        </button>
                      )}
                    </div>
                  </div>
                )}
              </m.div>
            );
          })}
        </div>
      )}
    </div>
  );
}
