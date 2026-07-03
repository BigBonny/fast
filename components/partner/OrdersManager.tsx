"use client";

import { useState } from "react";
import { useQuery, useQueryClient, useMutation } from "@tanstack/react-query";
import { motion } from "framer-motion";
import { Clock, Package, CheckCircle, XCircle, ChefHat, Utensils, User, ChevronDown, ChevronUp } from "lucide-react";
import { orderApi } from "@/api/fastBackend";
import { showToast } from "@/components/partner/Toast";

const STATUS_TABS = [
  { id: "ALL", label: "Toutes", color: "text-white" },
  { id: "PLACED", label: "Nouvelles", color: "text-blue-400" },
  { id: "PREPARING", label: "En prep", color: "text-yellow-400" },
  { id: "READY_FOR_PICKUP", label: "Prêtes", color: "text-orange-400" },
  { id: "COMPLETED", label: "Terminées", color: "text-green-400" },
  { id: "CANCELLED", label: "Annulées", color: "text-red-400" },
];

const STATUS_LABELS: Record<string, string> = {
  PLACED: "Reçue",
  PREPARING: "En préparation",
  READY_FOR_PICKUP: "Prête à récupérer",
  COMPLETED: "Terminée",
  CANCELLED: "Annulée",
};

const STATUS_ACTIONS: Record<string, { next: string; label: string; icon: any; color: string }[]> = {
  PLACED: [{ next: "PREPARING", label: "Préparer", icon: ChefHat, color: "bg-yellow-500" }],
  PREPARING: [{ next: "READY_FOR_PICKUP", label: "Prête", icon: Utensils, color: "bg-orange-500" }],
  READY_FOR_PICKUP: [{ next: "COMPLETED", label: "Récupérée", icon: CheckCircle, color: "bg-green-500" }],
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

  const filtered = activeTab === "ALL" ? orders : orders.filter((o: any) => o.status === activeTab);

  const updateMutation = useMutation({
    mutationFn: ({ id, status }: { id: string; status: string }) => orderApi.updateStatus(id, status),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["orders"] });
      showToast(" Statut mis à jour");
    },
    onError: (err: any) => showToast(err?.message || " Erreur"),
  });

  const formatTime = (date: string) => {
    const d = new Date(date);
    return d.toLocaleTimeString("fr-FR", { hour: "2-digit", minute: "2-digit" });
  };

  const toggleExpand = (id: string) => setExpanded((prev) => ({ ...prev, [id]: !prev[id] }));

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-lg font-black text-white">Commandes</h1>
        <span className="text-xs text-slate-400">{orders.length} commande{orders.length > 1 ? "s" : ""}</span>
      </div>

      <div className="flex overflow-x-auto gap-2 pb-1 scrollbar-hide">
        {STATUS_TABS.map((tab) => {
          const count = tab.id === "ALL" ? orders.length : orders.filter((o: any) => o.status === tab.id).length;
          const active = activeTab === tab.id;
          return (
            <button key={tab.id} onClick={() => setActiveTab(tab.id)} className={`flex-shrink-0 px-3 py-2 rounded-xl text-[11px] font-black border transition-all ${active ? "bg-[#00c8b3]/10 border-[#00c8b3]/40 text-[#00c8b3]" : "bg-[#0B1120] border-white/[0.06] text-slate-400 hover:border-white/10"}`}>
              {tab.label} <span className="ml-1 opacity-70">({count})</span>
            </button>
          );
        })}
      </div>

      {isLoading ? (
        <div className="py-12 text-center text-slate-500 text-sm">Chargement des commandes...</div>
      ) : filtered.length === 0 ? (
        <div className="bg-[#0B1120] border border-white/[0.08] rounded-2xl p-8 text-center text-slate-400 text-sm">
          <Package className="w-8 h-8 mx-auto mb-2 text-slate-500" />Aucune commande dans cette catégorie.
        </div>
      ) : (
        <div className="space-y-3">
          {filtered.map((order: any) => (
            <motion.div key={order.id} layout className="bg-[#0B1120] border border-white/[0.08] rounded-2xl overflow-hidden">
              <button onClick={() => toggleExpand(order.id)} className="w-full px-4 py-3 flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-white/[0.06] flex items-center justify-center text-lg flex-shrink-0">{order.status === "COMPLETED" ? "" : order.status === "CANCELLED" ? "" : ""}</div>
                <div className="flex-1 text-left">
                  <div className="flex items-center gap-2">
                    <span className="text-sm font-black text-white">#{order.id?.slice(-6).toUpperCase()}</span>
                    <span className={`text-[10px] font-black px-1.5 py-0.5 rounded-full bg-white/[0.06] ${STATUS_TABS.find((t) => t.id === order.status)?.color || "text-white"}`}>{STATUS_LABELS[order.status] || order.status}</span>
                  </div>
                  <div className="text-xs text-slate-400 flex items-center gap-2 mt-0.5"><User className="w-3 h-3" /> {order.user?.name || "Client"}  <Clock className="w-3 h-3" /> {formatTime(order.createdAt)}</div>
                </div>
                <div className="text-right">
                  <p className="text-sm font-black text-[#00c8b3]">{order.total?.toFixed(2)} </p>
                  {expanded[order.id] ? <ChevronUp className="w-4 h-4 text-slate-500" /> : <ChevronDown className="w-4 h-4 text-slate-500" />}
                </div>
              </button>

              {expanded[order.id] && (
                <div className="px-4 pb-4 border-t border-white/[0.06]">
                  <div className="py-3 space-y-2">
                    {order.items?.map((item: any) => (
                      <div key={item.id} className="flex items-center justify-between text-sm">
                        <span className="text-slate-300"><span className="font-black text-white">{item.quantity}x</span> {item.menuItem?.name || "Article"}</span>
                        <span className="text-slate-400">{(item.quantity * (item.menuItem?.price || 0)).toFixed(2)} </span>
                      </div>
                    ))}
                    {order.allergyNotes && <div className="text-xs text-yellow-400 bg-yellow-400/10 border border-yellow-400/20 rounded-lg px-2 py-1.5">Allergies/notes: {order.allergyNotes}</div>}
                    <div className="flex items-center justify-between text-xs text-slate-500 pt-2 border-t border-white/[0.06]"><span>Sous-total</span><span>{order.subtotal?.toFixed(2)} </span></div>
                    <div className="flex items-center justify-between text-xs text-slate-500"><span>Frais de service</span><span>{order.serviceFee?.toFixed(2)} </span></div>
                  </div>
                  <div className="flex flex-wrap gap-2 mt-3">
                    {(STATUS_ACTIONS[order.status] || []).map((action) => {
                      const Icon = action.icon;
                      return (
                        <button key={action.next} onClick={() => updateMutation.mutate({ id: order.id, status: action.next })} disabled={updateMutation.isPending} className={`flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-black text-white ${action.color} disabled:opacity-50`}>
                          <Icon className="w-4 h-4" /> {action.label}
                        </button>
                      );
                    })}
                    {order.status !== "CANCELLED" && order.status !== "COMPLETED" && (
                      <button onClick={() => updateMutation.mutate({ id: order.id, status: "CANCELLED" })} disabled={updateMutation.isPending} className="flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-black text-white bg-red-500 disabled:opacity-50">
                        <XCircle className="w-4 h-4" /> Annuler
                      </button>
                    )}
                  </div>
                </div>
              )}
            </motion.div>
          ))}
        </div>
      )}
    </div>
  );
}
