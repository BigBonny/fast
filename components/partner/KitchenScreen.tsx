"use client";

import React, { useState, useEffect } from "react";
import { motion } from "framer-motion";

export default function KitchenScreen({ open, onClose, orders = [] }: { open: boolean; onClose: () => void; orders?: any[] }) {
  const [time, setTime] = useState("");

  useEffect(() => {
    if (!open) return;
    const interval = setInterval(() => {
      const now = new Date();
      setTime(
        `${String(now.getHours()).padStart(2, "0")}:${String(now.getMinutes()).padStart(2, "0")}:${String(now.getSeconds()).padStart(2, "0")}`
      );
    }, 1000);
    return () => clearInterval(interval);
  }, [open]);

  if (!open) return null;

  const pending = orders.filter((o: any) => o.status === "PLACED").slice(0, 6);

  return (
    <div className="fixed inset-0 bg-[#020617] z-[9999] flex flex-col overflow-hidden p-4">
      {/* Header */}
      <div className="flex justify-between items-center mb-5 pb-3 border-b border-slate-800/60">
        <div className="flex items-center gap-3">
          <div className="w-11 h-11 rounded-2xl bg-gradient-to-br from-[#00c8b3] to-[#ff0066] flex items-center justify-center text-2xl shadow-lg shadow-[#00c8b3]/20">
            ⚡
          </div>
          <div className="font-bebas text-[34px] tracking-[5px] bg-gradient-to-br from-[#00c8b3] to-[#ff0066] bg-clip-text text-transparent">
            FAST CUISINE
          </div>
        </div>
        <div className="flex items-center gap-4">
          <div className="px-4 py-1.5 rounded-2xl bg-slate-900 border border-slate-800">
            <div className="text-3xl font-black text-white font-bebas tracking-wider">{time}</div>
          </div>
          <button
            onClick={onClose}
            className="bg-slate-800/80 hover:bg-slate-700 text-slate-200 px-4 py-2.5 rounded-xl text-[13px] font-black transition-all active:scale-95 border border-slate-700"
          >
            ✕ Fermer
          </button>
        </div>
      </div>

      {/* Orders grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 flex-1 overflow-auto">
        {pending.length === 0 ? (
          <div className="col-span-full flex flex-col items-center justify-center py-10">
            <div className="text-6xl mb-4 opacity-20">🍳</div>
            <div className="text-slate-500 text-lg font-black">AUCUNE COMMANDE EN ATTENTE</div>
          </div>
        ) : (
          pending.map((o: any, idx: number) => (
            <motion.div
              key={o.id}
              initial={{ opacity: 0, scale: 0.95 }}
              animate={{ opacity: 1, scale: 1 }}
              transition={{ delay: idx * 0.05 }}
              className={`rounded-2xl p-4 relative overflow-hidden border-2 ${
                (o.arrival_minutes || 15) <= 5
                  ? "border-red-500 shadow-[0_0_30px_rgba(239,68,68,0.25)]"
                  : "border-orange-500 shadow-[0_0_30px_rgba(249,115,22,0.25)]"
              }`}
              style={{ background: "linear-gradient(145deg, #0f172a, #1e293b)" }}
            >
              <div className="absolute top-0 left-0 w-full h-1 bg-gradient-to-r from-[#00c8b3] to-[#ff0066]" />
              <div
                className={`font-bebas text-[28px] absolute top-3 right-3 ${
                  (o.arrival_minutes || 15) <= 5 ? "text-red-500 animate-pulse" : "text-green-500"
                }`}
              >
                {o.arrival_minutes || "?"}min
              </div>
              <div className="font-bebas text-[38px] text-[#00c8b3] tracking-wider mb-1">{o.order_number}</div>
              <div className="text-xs font-black text-slate-400 mb-3 uppercase tracking-wider">
                {o.order_type === "sur_place" ? "🪑 Sur place" : "📦 À emporter"} · Priorité {idx + 1}
              </div>
              {(o.items || []).map((item: any, i: number) => (
                <div key={i} className="text-sm text-slate-200 py-1.5 border-b border-slate-700/50 last:border-b-0 font-semibold">
                  <span className="text-[#00c8b3] font-black mr-2">{item.qty}×</span>
                  {item.name}
                </div>
              ))}
            </motion.div>
          ))
        )}
      </div>

      {/* Scrolling bar */}
      <div className="bg-slate-900/80 border-t border-slate-800 py-3 overflow-hidden mt-4 rounded-2xl">
        <div className="flex gap-10 animate-[scroll-left_20s_linear_infinite] whitespace-nowrap">
          {[...pending, ...pending].map((o, i) => (
            <span key={i} className="text-sm text-slate-400 font-black inline-flex items-center gap-2">
              ⚡ {o.order_number} — {o.order_type === "sur_place" ? "Sur place" : "À emporter"} — Dans {o.arrival_minutes || "?"} min
            </span>
          ))}
          {pending.length === 0 && (
            <span className="text-sm text-slate-500 font-black">⚡ FAST — En attente de commandes...</span>
          )}
        </div>
      </div>
    </div>
  );
}
