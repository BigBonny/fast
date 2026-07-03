"use client";

import React, { useState, useEffect } from "react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { motion } from "framer-motion";
import { orderApi, restaurantApi } from "@/api/fastBackend";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useAuth } from "@/lib/AuthContext";
import Toast, { showToast } from "./Toast";
import KitchenScreen from "./KitchenScreen";
import SideMenu from "./SideMenu";
import RushBar from "./RushBar";
import useOrderNotifications from "./useOrderNotifications";

const tabs = [
  { id: "orders", icon: "ðŸ›ï¸", label: "COMMANDES", href: "/partner/orders", badge: true },
  { id: "menu", icon: "ðŸ½ï¸", label: "MENU", href: "/partner/menu" },
  { id: "settings", icon: "âš™ï¸", label: "RÃ‰GLAGES", href: "/partner/settings" },
  { id: "analytics/profile", icon: "ðŸª", label: "PROFIL", href: "/partner/analytics/profile" },
  { id: "analytics", icon: "ðŸ“Š", label: "STATISTIQUES", href: "/partner/analytics" },
];

function currentTabId(pathname: string) {
  return tabs.find((t) => pathname.startsWith(t.href))?.id || "orders";
}

export default function PartnerLayout({ children }: { children: React.ReactNode }) {
  const [kitchenOpen, setKitchenOpen] = useState(false);
  const [sideOpen, setSideOpen] = useState(false);
  const [rushActive, setRushActive] = useState(() => {
    try {
      return JSON.parse(localStorage.getItem("fast_rush") || "false");
    } catch {
      return false;
    }
  });
  const queryClient = useQueryClient();
  const router = useRouter();
  const pathname = usePathname();
  const { user, isAuthenticated, isLoadingAuth } = useAuth();

  useEffect(() => {
    if (!isLoadingAuth && (!isAuthenticated || user?.role !== "RESTAURANT")) {
      router.replace("/login");
    }
  }, [isLoadingAuth, isAuthenticated, user, router]);

  useOrderNotifications(queryClient);

  const { data: orders = [] } = useQuery({
    queryKey: ["orders"],
    queryFn: () => orderApi.restaurantOrders(),
    refetchInterval: 10000,
  });

  const { data: settings, isLoading: settingsLoading } = useQuery({
    queryKey: ["settings"],
    queryFn: () => restaurantApi.mine(),
    staleTime: 0,
    refetchOnMount: true,
  });

  useEffect(() => {
    const theme = localStorage.getItem("fast_r_theme") || "dark";
    document.documentElement.setAttribute("data-theme", theme);
  }, []);

  useEffect(() => {
    if (settings?.isRushMode !== undefined) {
      setRushActive(settings.isRushMode);
      localStorage.setItem("fast_rush", JSON.stringify(settings.isRushMode));
    }
  }, [settings]);

  const pendingCount = orders.filter((o: any) => o.status === "PLACED").length;
  const s = settings || {};

  const toggleRush = async () => {
    try {
      const result = await restaurantApi.toggleRush();
      const next = result?.isRushMode ?? !rushActive;
      setRushActive(next);
      localStorage.setItem("fast_rush", JSON.stringify(next));
      showToast(next ? "ðŸ”¥ Mode Rush activÃ© !" : "âœ… Mode Rush dÃ©sactivÃ©");
    } catch (e) {
      console.error("toggleRush failed", e);
      showToast("âŒ Erreur mode rush");
    }
  };

  const activeTabId = currentTabId(pathname);
  const isOnboarding = pathname === "/partner/onboarding";

  if (isLoadingAuth || settingsLoading) {
    return (
      <div className="fixed inset-0 flex items-center justify-center" style={{ background: "#020617" }}>
        <div className="font-bebas text-3xl tracking-[8px] animate-pulse" style={{ color: "#00c8b3" }}>
          âš¡ FAST
        </div>
      </div>
    );
  }

  if (!isAuthenticated || user?.role !== "RESTAURANT") {
    return null;
  }

  if (isOnboarding) {
    return (
      <div style={{ background: "var(--bg)", minHeight: "100vh" }}>
        <Toast />
        {children}
      </div>
    );
  }

  return (
    <div style={{ background: "var(--bg)", minHeight: "100vh", color: "var(--blk)" }}>
      <Toast />

      {/* Header */}
      <header className="bg-[#020617] px-4 h-[56px] flex items-center justify-between sticky top-0 z-[1000] border-b border-white/[0.08] shadow-[0_8px_30px_rgba(0,0,0,0.3)]">
        <Link href="/partner/orders" className="no-underline group">
          <div className="font-bebas text-[24px] tracking-[5px] bg-gradient-to-br from-[#00c8b3] via-[#00c8b3] to-[#ff0066] bg-clip-text text-transparent leading-none group-hover:brightness-110 transition-all">
            âš¡ FAST
          </div>
          <div className="text-[9px] text-slate-500 font-semibold tracking-[2px] uppercase">RESTAURATEUR PRO</div>
        </Link>
        <div className="flex items-center gap-2">
          <div className="flex items-center gap-1.5 px-2 py-1 rounded-full bg-white/[0.04] border border-white/10">
            <div className="w-2 h-2 rounded-full bg-green-500 relative flex-shrink-0">
              <span className="absolute inset-0 rounded-full bg-green-500 animate-ping opacity-75" />
            </div>
            <span className="text-[10px] font-bold text-green-400">En ligne</span>
          </div>
          <button
            onClick={() => setSideOpen(true)}
            className="bg-white/[0.07] border border-white/10 text-slate-200 w-8 h-8 rounded-lg flex items-center justify-center text-xs font-semibold hover:bg-white/12 transition-all active:scale-95"
          >
            â˜°
          </button>
          <button
            onClick={() => setKitchenOpen(true)}
            className="px-3 h-8 rounded-lg text-xs font-bold text-white border-none shadow-lg shadow-[#00c8b3]/20 hover:shadow-[#00c8b3]/40 hover:scale-105 transition-all active:scale-95"
            style={{ background: "linear-gradient(135deg, #00c8b3, #00a090)" }}
          >
            ðŸ³ Cuisine
          </button>
        </div>
      </header>

      <RushBar active={rushActive} />

      {/* Tabs */}
      <div className="bg-[#020617] border-b border-white/[0.07] flex overflow-x-auto scrollbar-hide px-1">
        {tabs.map((tab) => {
          const isActive = activeTabId === tab.id;
          return (
            <Link
              key={tab.id}
              href={tab.href}
              className="relative px-4 py-3 text-xs font-black whitespace-nowrap transition-all flex items-center gap-1.5 border-b-2 no-underline"
              style={{
                color: isActive ? "#00c8b3" : "rgba(148,163,184,0.7)",
                borderColor: isActive ? "#00c8b3" : "transparent",
                textShadow: isActive ? "0 0 12px rgba(0,200,179,0.25)" : "none",
              }}
            >
              {isActive && (
                <motion.div
                  layoutId="partner-tab"
                  className="absolute inset-0 rounded-lg bg-[#00c8b3]/8 border border-[#00c8b3]/10"
                  transition={{ type: "spring", stiffness: 400, damping: 30 }}
                />
              )}
              <span className="relative z-10">{tab.icon}</span>
              <span className="relative z-10">{tab.label}</span>
              {tab.badge && pendingCount > 0 && (
                <span className="relative z-10 bg-red-500 text-white min-w-[16px] h-4 px-1 rounded-full text-[10px] flex items-center justify-center font-black border border-[#020617]">
                  {pendingCount}
                </span>
              )}
            </Link>
          );
        })}
      </div>

      <main className="p-3 max-w-2xl mx-auto">{children}</main>

      <KitchenScreen open={kitchenOpen} onClose={() => setKitchenOpen(false)} orders={orders} />
      <SideMenu
        open={sideOpen}
        onClose={() => setSideOpen(false)}
        settings={s}
        rushActive={rushActive}
        onToggleRush={toggleRush}
        onOpenKitchen={() => setKitchenOpen(true)}
      />
    </div>
  );
}


