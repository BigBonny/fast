"use client";

import React from "react";
import { motion, AnimatePresence } from "framer-motion";
import { X, UtensilsCrossed, BrainCircuit } from "lucide-react";

export default function LiveGpsMap({ orders, showGps, onToggle }: { orders: any[]; showGps: boolean; onToggle: () => void }) {
  const active = orders
    .filter((o: any) => (o.status === "PLACED" || o.status === "PREPARING") && (o.gpsProgress || 0) < 100)
    .slice(0, 20);

  if (active.length === 0) return null;

  return (
    <div className="mb-3">
      <AnimatePresence>
        {showGps && (
          <motion.div
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: "auto" }}
            exit={{ opacity: 0, height: 0 }}
            transition={{ duration: 0.25 }}
            className="overflow-hidden rounded-xl border mb-2"
            style={{ borderColor: "rgba(0,200,179,.25)" }}
          >
            {/* Header */}
            <div
              className="flex items-center justify-between px-3 py-2 border-b"
              style={{ background: "#010d1a", borderColor: "rgba(0,200,179,.15)" }}
            >
              <div className="flex items-center gap-2">
                <div className="w-2 h-2 rounded-full bg-green-400 animate-pulse" />
                <span className="text-[11px] font-extrabold tracking-widest uppercase" style={{ color: "#00c8b3" }}>
                  Suivi GPS en direct
                </span>
                <span
                  className="text-[10px] px-1.5 py-0.5 rounded-full font-bold"
                  style={{ background: "rgba(0,200,179,.15)", color: "#00c8b3" }}
                >
                  {active.length} en route
                </span>
              </div>
              <button
                onClick={onToggle}
                className="w-6 h-6 rounded-full flex items-center justify-center"
                style={{ background: "rgba(255,255,255,.1)", color: "#94a3b8" }}
              >
                <X className="w-3.5 h-3.5" />
              </button>
            </div>

            {/* Carte */}
            <RoadScene clients={active} />

            {/* Ordre IA */}
            <IAQueue orders={active} />
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

function RoadScene({ clients }: { clients: any[] }) {
  const sorted = [...clients].sort((a: any, b: any) => (b.gpsProgress || 0) - (a.gpsProgress || 0));

  return (
    <div
      className="relative overflow-hidden"
      style={{ height: "140px", background: "linear-gradient(160deg,#010d1a 0%,#040f1c 100%)" }}
    >
      {[...Array(18)].map((_, i) => (
        <div
          key={i}
          className="absolute rounded-full"
          style={{
            width: i % 3 === 0 ? "2px" : "1px",
            height: i % 3 === 0 ? "2px" : "1px",
            background: "rgba(255,255,255,0.4)",
            left: `${(i * 37 + 7) % 90 + 5}%`,
            top: `${(i * 23 + 5) % 35 + 3}%`,
          }}
        />
      ))}

      <div className="absolute top-0 left-0 right-0" style={{ height: "30px", background: "#0a1f0a" }} />
      <div className="absolute bottom-0 left-0 right-0" style={{ height: "30px", background: "#0a1f0a" }} />

      <div
        className="absolute left-0 right-0"
        style={{
          top: "50%",
          transform: "translateY(-50%)",
          height: "44px",
          background: "linear-gradient(180deg, #1c2a1c 0%, #253525 50%, #1c2a1c 100%)",
          borderTop: "2px solid rgba(255,255,255,0.12)",
          borderBottom: "2px solid rgba(255,255,255,0.08)",
        }}
      >
        <div
          className="absolute left-0 right-0"
          style={{
            top: "50%",
            height: "2px",
            background:
              "repeating-linear-gradient(90deg, rgba(255,255,200,0.5) 0px, rgba(255,255,200,0.5) 18px, transparent 18px, transparent 36px)",
          }}
        />
      </div>

      <div
        className="absolute flex flex-col items-center z-20"
        style={{ left: "6px", top: "50%", transform: "translateY(-54%)" }}
      >
        <UtensilsCrossed className="w-9 h-9 text-[#00c8b3]" />
        <div className="text-[8px] font-black tracking-widest" style={{ color: "#00c8b3" }}>
          ICI
        </div>
      </div>

      <div
        className="absolute z-10"
        style={{
          left: "14%",
          top: "50%",
          transform: "translateY(-50%)",
          width: "2px",
          height: "50px",
          background: "rgba(0,200,179,0.6)",
          boxShadow: "0 0 8px rgba(0,200,179,0.5)",
        }}
      />

      {sorted.map((c: any) => {
        const progress = Math.min(95, c.gpsProgress || 0);
        const xPct = 88 - (progress / 100) * 72;
        const urg = progress >= 75 || (typeof c.arrivalMinutes === "number" && c.arrivalMinutes <= 3);
        const shortNum = (c.orderNumber || c.order_number || "").replace("#", "").slice(-4);

        return (
          <div
            key={c.id}
            className="absolute flex flex-col items-center"
            style={{
              left: `${xPct}%`,
              top: "50%",
              transform: "translate(-50%, -52%)",
              zIndex: 15,
              transition: "left 3s linear",
            }}
          >
            <div
              className="text-[8px] font-black px-1 py-[1px] rounded leading-none mb-[2px]"
              style={{
                color: urg ? "#fff" : "#00c8b3",
                background: urg ? "#ef4444" : "rgba(0,200,179,.25)",
                whiteSpace: "nowrap",
              }}
            >
              {shortNum}
            </div>
            <div
              style={{
                fontSize: "32px",
                lineHeight: 1,
                filter: urg ? "drop-shadow(0 0 6px #ef4444)" : "drop-shadow(0 0 5px rgba(0,200,179,.9))",
              }}
            >
              🧍
            </div>
          </div>
        );
      })}

      <div className="absolute bottom-1 right-2 flex items-center gap-3">
        <div className="flex items-center gap-1">
          <div className="w-1.5 h-1.5 rounded-full bg-red-500" />
          <span className="text-[8px]" style={{ color: "rgba(255,255,255,.3)" }}>
            Urgent
          </span>
        </div>
        <div className="flex items-center gap-1">
          <div className="w-1.5 h-1.5 rounded-full" style={{ background: "#00c8b3" }} />
          <span className="text-[8px]" style={{ color: "rgba(255,255,255,.3)" }}>
            En route
          </span>
        </div>
      </div>
    </div>
  );
}

function IAQueue({ orders }: { orders: any[] }) {
  const sorted = [...orders].sort((a: any, b: any) => (a.arrivalMinutes || 99) - (b.arrivalMinutes || 99));
  if (sorted.length === 0) return null;

  return (
    <div className="px-3 py-2 border-t" style={{ background: "var(--card)", borderColor: "var(--bdr)" }}>
      <div className="flex items-center gap-1.5 mb-1.5">
        <BrainCircuit className="w-3.5 h-3.5 text-[#00c8b3]" />
        <span className="text-[10px] font-extrabold uppercase tracking-widest" style={{ color: "#00c8b3" }}>
          IA · Ordre de préparation
        </span>
      </div>
      <div className="flex gap-2 overflow-x-auto pb-0.5 scrollbar-hide">
        {sorted.map((o: any, i: number) => (
          <div
            key={o.id}
            className="flex-shrink-0 flex items-center gap-1.5 px-2 py-1.5 rounded-lg border"
            style={{
              background:
                i === 0 ? "rgba(239,68,68,.08)" : i === 1 ? "rgba(249,115,22,.06)" : "rgba(0,200,179,.04)",
              borderColor: i === 0 ? "rgba(239,68,68,.3)" : i === 1 ? "rgba(249,115,22,.2)" : "rgba(0,200,179,.12)",
              minWidth: "80px",
            }}
          >
            <span
              className="text-[11px] font-black w-3"
              style={{ color: i === 0 ? "#ef4444" : i === 1 ? "#f97316" : "#00c8b3" }}
            >
              {i + 1}
            </span>
            <div>
              <div className="text-[11px] font-extrabold" style={{ color: "var(--blk)" }}>
                {o.orderNumber || o.order_number}
              </div>
              <div className="text-[9px]" style={{ color: "var(--gray)" }}>
                {typeof o.arrivalMinutes === "number" ? `${o.arrivalMinutes} min` : "bientôt"}
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
