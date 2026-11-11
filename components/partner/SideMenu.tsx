"use client";

import React from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { m, AnimatePresence } from "framer-motion";
import { useTheme } from "@/lib/useTheme";
import type { Restaurant } from "@/lib/types";
import {
  Store, ShoppingBag, UtensilsCrossed, Settings, TrendingUp, BrainCircuit,
  Users, LayoutDashboard, Radio, FileText, CircleUser, Moon, Sun, Zap,
  Flame, ChefHat, Antenna, X, ChevronRight, type LucideIcon,
} from "lucide-react";

const navItems = [
  { Icon: Store, label: "Mon Service", href: "/partner" },
  { Icon: ShoppingBag, label: "Commandes", href: "/partner/orders" },
  { Icon: UtensilsCrossed, label: "Menu", href: "/partner/menu" },
  { Icon: Settings, label: "Réglages", href: "/partner/settings" },
];

const extraItems = [
  { Icon: TrendingUp, label: "Statistiques", href: "/partner/stats" },
  { Icon: BrainCircuit, label: "Intelligence IA", href: "/partner/ai" },
  { Icon: Users, label: "Mon Équipe", href: "/partner/team" },
];

const proItems = [
  { Icon: LayoutDashboard, label: "Tableau de bord", href: "/partner/analytics" },
  { Icon: Radio, label: "Commandes live", href: "/partner/analytics/orders" },
  { Icon: FileText, label: "Menu professionnel", href: "/partner/analytics/menu" },
  { Icon: CircleUser, label: "Profil restaurant", href: "/partner/analytics/profile" },
];

const sectionLabel = "text-xs font-bold uppercase tracking-wide text-muted-foreground mb-1 px-3 mt-5";
const rowBase =
  "group flex items-center gap-3 w-full min-h-[44px] px-3 rounded-full text-sm font-semibold cursor-pointer mb-0.5 transition-colors no-underline text-left active:scale-[0.99] focus-visible:outline-fast-teal";
const rowIdle = "text-foreground hover:bg-muted";
const rowSelected = "bg-fast-teal/15 text-foreground";

function NavRow({ item, pathname, onClose }: { item: { Icon: LucideIcon; label: string; href: string }; pathname: string; onClose: () => void }) {
  const selected = pathname === item.href;
  return (
    <Link
      href={item.href}
      onClick={onClose}
      aria-current={selected ? "page" : undefined}
      className={`${rowBase} ${selected ? rowSelected : rowIdle}`}
    >
      <item.Icon className={`w-5 h-5 flex-shrink-0 ${selected ? "text-fast-teal" : "text-muted-foreground"}`} />
      <span className="flex-1">{item.label}</span>
      <ChevronRight className="w-4 h-4 text-muted-foreground" aria-hidden="true" />
    </Link>
  );
}

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
  settings: Partial<Restaurant>;
  onToggleRush: () => void;
  rushActive: boolean;
  onOpenKitchen: () => void;
}) {
  const { theme, toggleTheme } = useTheme();
  const pathname = usePathname() || "";

  return (
    <AnimatePresence>
      {open && (
        <>
          <m.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-[8000] bg-black/55 backdrop-blur-[4px]"
            onClick={onClose}
          />
          <m.div
            initial={{ x: -280 }}
            animate={{ x: 0 }}
            exit={{ x: -280 }}
            transition={{ type: "spring", damping: 30, stiffness: 300 }}
            className="fixed left-0 top-0 bottom-0 w-[280px] bg-background text-foreground z-[8001] overflow-y-auto pb-10 border-r border-border shadow-2xl"
          >
            {/* Header: the brand block */}
            <div className="night-band p-4">
              <div className="flex justify-between items-center mb-4">
                <div className="font-bebas text-[20px] tracking-[4px] flex items-center gap-1.5">
                  <Zap className="w-5 h-5 text-fast-orange fill-current" aria-hidden="true" />
                  <span className="notranslate text-neon" translate="no">FAST</span>
                </div>
                <button
                  onClick={onClose}
                  aria-label="Fermer"
                  className="bg-white/[0.08] border border-white/10 text-white w-11 h-11 rounded-full cursor-pointer flex items-center justify-center hover:bg-white/15 transition-colors active:scale-95 focus-visible:outline-fast-teal"
                >
                  <X className="w-4 h-4" />
                </button>
              </div>
              <div className="flex items-center gap-3">
                <div className="w-12 h-12 rounded-2xl bg-white/[0.08] border border-white/10 flex items-center justify-center flex-shrink-0">
                  <ChefHat className="w-6 h-6 text-white" />
                </div>
                <div className="min-w-0">
                  <div className="font-display text-base font-bold text-white truncate">{settings?.name || "Mon Restaurant"}</div>
                  <div className="text-xs on-night-muted font-medium">{settings?.cuisineType || "Restaurateur"} — <span className="notranslate" translate="no">FAST</span> Pro</div>
                </div>
              </div>
            </div>

            <div className="px-2 pb-2">
              <div className={sectionLabel}>Navigation</div>
              {navItems.map((item) => (
                <NavRow key={item.href} item={item} pathname={pathname} onClose={onClose} />
              ))}

              <div className={sectionLabel}>Outils avancés</div>
              {extraItems.map((item) => (
                <NavRow key={item.href} item={item} pathname={pathname} onClose={onClose} />
              ))}

              <div className={sectionLabel}>Espace Pro</div>
              {proItems.map((item) => (
                <NavRow key={item.href} item={item} pathname={pathname} onClose={onClose} />
              ))}

              <div className={sectionLabel}>Apparence</div>
              <button onClick={toggleTheme} className={`${rowBase} ${rowIdle} justify-between`}>
                <span className="flex items-center gap-3">
                  {theme === "dark" ? <Moon className="w-5 h-5 text-muted-foreground" /> : <Sun className="w-5 h-5 text-muted-foreground" />}
                  <span>{theme === "dark" ? "Mode nuit" : "Mode jour"}</span>
                </span>
                <span className="text-xs font-bold text-muted-foreground bg-muted px-2.5 py-1 rounded-full">
                  {theme === "dark" ? "Sombre" : "Clair"}
                </span>
              </button>

              <div className={sectionLabel}>Outils</div>
              <button
                onClick={() => {
                  onToggleRush();
                  onClose();
                }}
                className={`${rowBase} ${rowIdle}`}
              >
                <Flame className={`w-5 h-5 flex-shrink-0 ${rushActive ? "text-[color:var(--ac)] fill-current" : "text-muted-foreground"}`} />
                <span>Mode Rush {rushActive ? "(Actif)" : ""}</span>
              </button>
              <button
                onClick={() => {
                  onOpenKitchen();
                  onClose();
                }}
                className={`${rowBase} ${rowIdle}`}
              >
                <ChefHat className="w-5 h-5 flex-shrink-0 text-muted-foreground" />
                <span>Écran cuisine</span>
              </button>
              <Link href="/partner/orders" onClick={onClose} className={`${rowBase} ${rowIdle}`}>
                <Antenna className="w-5 h-5 flex-shrink-0 text-muted-foreground" />
                <span>Radar GPS — Suivi clients</span>
              </Link>
            </div>
          </m.div>
        </>
      )}
    </AnimatePresence>
  );
}
