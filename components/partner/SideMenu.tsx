"use client";

import React, { useState } from "react";
import Link from "next/link";
import { motion, AnimatePresence } from "framer-motion";

const navItems = [
  { icon: "📋", label: "Mon Service", href: "/partner" },
  { icon: "🛍️", label: "Commandes", href: "/partner/orders" },
  { icon: "🍽️", label: "Menu", href: "/partner/menu" },
  { icon: "⚙️", label: "Réglages", href: "/partner/settings" },
];

const extraItems = [
  { icon: "📈", label: "Statistiques", href: "/partner/stats" },
  { icon: "🤖", label: "Intelligence IA", href: "/partner/ai" },
  { icon: "👥", label: "Mon Équipe", href: "/partner/team" },
];

const proItems = [
  { icon: "📊", label: "Tableau de bord", href: "/partner/analytics" },
  { icon: "🔴", label: "Commandes live", href: "/partner/analytics/orders" },
  { icon: "🧾", label: "Menu professionnel", href: "/partner/analytics/menu" },
  { icon: "🏪", label: "Profil restaurant", href: "/partner/analytics/profile" },
];

export default function SideMenu({
  open,
  onClose,
  settings,
  onToggleRush,
  rushActive,
  onOpenKitchen,
}: {
  open: boolean;
  onClose: () => void;
  settings: any;
  onToggleRush: () => void;
  rushActive: boolean;
  onOpenKitchen: () => void;
}) {
  const [theme, setTheme] = useState(() => {
    if (typeof document !== "undefined") {
      return document.documentElement.getAttribute("data-theme") || "dark";
    }
    return "dark";
  });

  const toggleTheme = () => {
    const next = theme === "dark" ? "light" : "dark";
    setTheme(next);
    document.documentElement.setAttribute("data-theme", next);
    localStorage.setItem("fast_r_theme", next);
  };

  return (
    <AnimatePresence>
      {open && (
        <>
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-[8000] bg-black/55 backdrop-blur-[4px]"
            onClick={onClose}
          />
          <motion.div
            initial={{ x: -280 }}
            animate={{ x: 0 }}
            exit={{ x: -280 }}
            transition={{ type: "spring", damping: 30, stiffness: 300 }}
            className="fixed left-0 top-0 bottom-0 w-[280px] bg-[#020617] z-[8001] overflow-y-auto pb-10 border-r border-white/[0.06]"
            style={{ boxShadow: "20px 0 60px rgba(0,0,0,0.4)" }}
          >
            {/* Header */}
            <div className="p-4 border-b border-white/[0.07]" style={{ background: "linear-gradient(180deg, rgba(0,200,179,0.08), transparent)" }}>
              <div className="flex justify-between items-center mb-4">
                <div className="font-bebas text-[18px] tracking-[4px] bg-gradient-to-br from-[#00c8b3] to-[#ff0066] bg-clip-text text-transparent">
                  ⚡ FAST
                </div>
                <button
                  onClick={onClose}
                  className="bg-white/[0.08] border border-white/10 text-slate-200 w-8 h-8 rounded-full cursor-pointer text-sm flex items-center justify-center hover:bg-white/15 transition-all active:scale-95"
                >
                  ✕
                </button>
              </div>
              <div className="flex items-center gap-3">
                <div className="w-12 h-12 rounded-2xl bg-gradient-to-br from-[#00c8b3] to-[#ff0066] flex items-center justify-center text-2xl flex-shrink-0 shadow-lg shadow-[#00c8b3]/20">
                  👨‍🍳
                </div>
                <div>
                  <div className="text-sm font-black text-white">{settings?.name || "Mon Restaurant"}</div>
                  <div className="text-[11px] text-slate-400 font-medium">{settings?.cuisineType || "Restaurateur"} — FAST Pro</div>
                </div>
              </div>
            </div>

            <div className="p-2.5">
              <div className="text-[10px] font-black text-slate-600 uppercase tracking-[1.5px] mb-2 px-2.5 mt-3">Navigation</div>
              {navItems.map((item) => (
                <Link
                  key={item.href}
                  href={item.href}
                  onClick={onClose}
                  className="group flex items-center gap-2.5 w-full bg-white/[0.04] border border-transparent text-slate-200 px-3 py-2.5 rounded-xl text-[13px] font-semibold cursor-pointer mb-1.5 transition-all hover:bg-[#00c8b3]/[0.12] hover:border-[#00c8b3]/20 hover:text-[#00c8b3] no-underline active:scale-[0.98]"
                >
                  <span className="text-lg group-hover:scale-110 transition-transform">{item.icon}</span>
                  <span className="flex-1">{item.label}</span>
                  <span className="text-slate-600 group-hover:text-[#00c8b3] transition-colors">›</span>
                </Link>
              ))}

              <div className="text-[10px] font-black text-slate-600 uppercase tracking-[1.5px] mb-2 px-2.5 mt-4">Outils avancés</div>
              {extraItems.map((item) => (
                <Link
                  key={item.href}
                  href={item.href}
                  onClick={onClose}
                  className="group flex items-center gap-2.5 w-full bg-white/[0.04] border border-transparent text-slate-200 px-3 py-2.5 rounded-xl text-[13px] font-semibold cursor-pointer mb-1.5 transition-all hover:bg-[#00c8b3]/[0.12] hover:border-[#00c8b3]/20 hover:text-[#00c8b3] no-underline active:scale-[0.98]"
                >
                  <span className="text-lg group-hover:scale-110 transition-transform">{item.icon}</span>
                  <span className="flex-1">{item.label}</span>
                  <span className="text-slate-600 group-hover:text-[#00c8b3] transition-colors">›</span>
                </Link>
              ))}

              <div className="text-[10px] font-black text-slate-600 uppercase tracking-[1.5px] mb-2 px-2.5 mt-4">Espace Pro</div>
              {proItems.map((item) => (
                <Link
                  key={item.href}
                  href={item.href}
                  onClick={onClose}
                  className="group flex items-center gap-2.5 w-full bg-white/[0.04] border border-transparent text-slate-200 px-3 py-2.5 rounded-xl text-[13px] font-semibold cursor-pointer mb-1.5 transition-all hover:bg-[#00c8b3]/[0.12] hover:border-[#00c8b3]/20 hover:text-[#00c8b3] no-underline active:scale-[0.98]"
                >
                  <span className="text-lg group-hover:scale-110 transition-transform">{item.icon}</span>
                  <span className="flex-1">{item.label}</span>
                  <span className="text-slate-600 group-hover:text-[#00c8b3] transition-colors">›</span>
                </Link>
              ))}

              <div className="text-[10px] font-black text-slate-600 uppercase tracking-[1.5px] mb-2 px-2.5 mt-4">Apparence</div>
              <button
                onClick={toggleTheme}
                className="group flex items-center justify-between w-full bg-white/[0.04] border border-transparent text-slate-200 px-3 py-2.5 rounded-xl text-[13px] font-semibold cursor-pointer mb-1.5 transition-all hover:bg-[#00c8b3]/[0.12] hover:border-[#00c8b3]/20 hover:text-[#00c8b3] text-left active:scale-[0.98]"
              >
                <span className="flex items-center gap-2.5">
                  <span className="text-lg group-hover:scale-110 transition-transform">{theme === "dark" ? "🌙" : "☀️"}</span>
                  <span>{theme === "dark" ? "Mode nuit" : "Mode jour"}</span>
                </span>
                <span className="text-[11px] font-bold text-slate-500 bg-white/[0.08] px-2 py-0.5 rounded-full group-hover:text-[#00c8b3] transition-colors">
                  {theme === "dark" ? "Sombre" : "Clair"}
                </span>
              </button>

              <div className="text-[10px] font-black text-slate-600 uppercase tracking-[1.5px] mb-2 px-2.5 mt-4">Outils</div>
              <button
                onClick={() => {
                  onToggleRush();
                  onClose();
                }}
                className="group flex items-center gap-2.5 w-full bg-white/[0.04] border border-transparent text-slate-200 px-3 py-2.5 rounded-xl text-[13px] font-semibold cursor-pointer mb-1.5 transition-all hover:bg-[#ff0066]/[0.12] hover:border-[#ff0066]/20 hover:text-[#ff0066] text-left active:scale-[0.98]"
              >
                <span className="text-lg group-hover:scale-110 transition-transform">⚡</span>
                <span>Mode Rush {rushActive ? "(Actif 🔥)" : ""}</span>
              </button>
              <button
                onClick={() => {
                  onOpenKitchen();
                  onClose();
                }}
                className="group flex items-center gap-2.5 w-full bg-white/[0.04] border border-transparent text-slate-200 px-3 py-2.5 rounded-xl text-[13px] font-semibold cursor-pointer mb-1.5 transition-all hover:bg-[#00c8b3]/[0.12] hover:border-[#00c8b3]/20 hover:text-[#00c8b3] text-left active:scale-[0.98]"
              >
                <span className="text-lg group-hover:scale-110 transition-transform">🍳</span>
                <span>Écran cuisine</span>
              </button>
              <Link
                href="/partner/orders"
                onClick={onClose}
                className="group flex items-center gap-2.5 w-full bg-white/[0.04] border border-transparent text-slate-200 px-3 py-2.5 rounded-xl text-[13px] font-semibold cursor-pointer mb-1.5 transition-all hover:bg-[#00c8b3]/[0.12] hover:border-[#00c8b3]/20 hover:text-[#00c8b3] no-underline active:scale-[0.98]"
              >
                <span className="text-lg group-hover:scale-110 transition-transform">📡</span>
                <span>Radar GPS — Suivi clients</span>
              </Link>
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}
