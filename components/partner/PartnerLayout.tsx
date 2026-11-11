"use client";

import React, { useState, useEffect } from "react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { m } from "framer-motion";
import { Zap, ShoppingBag, UtensilsCrossed, Settings, CircleUser, BarChart3, Menu, ChefHat, Flame, CheckCircle2, X } from "lucide-react";
import { orderApi, restaurantApi } from "@/api/fastBackend";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useAuth } from "@/lib/AuthContext";
import type { Order } from "@/lib/types";
import Toast, { showToast } from "./Toast";
import KitchenScreen from "./KitchenScreen";
import SideMenu from "./SideMenu";
import RushBar from "./RushBar";
import useOrderNotifications from "./useOrderNotifications";

const tabs = [
  { id: "orders", Icon: ShoppingBag, label: "COMMANDES", href: "/partner/orders", badge: true },
  { id: "menu", Icon: UtensilsCrossed, label: "MENU", href: "/partner/menu" },
  { id: "settings", Icon: Settings, label: "RÉGLAGES", href: "/partner/settings" },
  { id: "analytics/profile", Icon: CircleUser, label: "PROFIL", href: "/partner/analytics/profile" },
  { id: "analytics", Icon: BarChart3, label: "STATISTIQUES", href: "/partner/analytics" },
];

function currentTabId(pathname: string) {
  return tabs.find((t) => pathname.startsWith(t.href))?.id || "orders";
}

export default function PartnerLayout({ children }: { children: React.ReactNode }) {
  const [kitchenOpen, setKitchenOpen] = useState(false);
  const [sideOpen, setSideOpen] = useState(false);
  // Server-authoritative; the local value below is only an optimistic first paint.
  const [rushActive, setRushActive] = useState(false);
  const queryClient = useQueryClient();
  const router = useRouter();
  const pathname = usePathname();
  const isOnboarding = pathname === "/partner/onboarding";
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

  const { data: settings, isLoading: settingsLoading, error: settingsError } = useQuery({
    queryKey: ["settings"],
    queryFn: () => restaurantApi.mine(),
    staleTime: 0,
    refetchOnMount: true,
    retry: false,
  });

  useEffect(() => {
    if (settingsError && !isOnboarding) {
      router.replace("/partner/onboarding");
    }
  }, [settingsError, isOnboarding, router]);

  useEffect(() => {
    try {
      setRushActive(JSON.parse(localStorage.getItem("fast_rush") || "false"));
    } catch {
      setRushActive(false);
    }
  }, []);

  useEffect(() => {
    if (settings?.isRushMode !== undefined) {
      setRushActive(settings.isRushMode);
      localStorage.setItem("fast_rush", JSON.stringify(settings.isRushMode));
    }
  }, [settings]);

  const pendingCount = orders.filter((o: Order) => o.status === "PLACED").length;
  const s = settings || {};

  const toggleRush = async () => {
    try {
      const result = await restaurantApi.toggleRush();
      const next = result?.isRushMode ?? !rushActive;
      setRushActive(next);
      localStorage.setItem("fast_rush", JSON.stringify(next));
      showToast(next ? "Mode Rush activé !" : "Mode Rush désactivé");
    } catch (e) {
      console.error("toggleRush failed", e);
      showToast("Erreur mode rush");
    }
  };

  const activeTabId = currentTabId(pathname);

  if (isLoadingAuth || (settingsLoading && !settingsError)) {
    return (
      <div className="fixed inset-0 flex flex-col items-center justify-center gap-5 bg-background">
        <div className="font-bebas text-3xl tracking-[8px] flex items-center gap-2">
          <Zap className="w-7 h-7 text-fast-orange fill-current" aria-hidden="true" />
          <span className="notranslate text-neon" translate="no">FAST</span>
        </div>
        <span className="w-5 h-5 rounded-full border-2 border-fast-teal/30 border-t-fast-teal animate-spin" aria-hidden="true" />
      </div>
    );
  }

  if (!isAuthenticated || user?.role !== "RESTAURANT") {
    return null;
  }

  if (isOnboarding) {
    return (
      <div className="min-h-screen bg-background text-foreground">
        <Toast />
        {children}
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background text-foreground">
      <Toast />

      {/* Header: the brand block */}
      <header className="night-band px-4 h-[56px] flex items-center justify-between sticky top-0 z-[1000] border-b border-white/10">
        <Link href="/partner/orders" className="no-underline group">
          <div className="font-bebas text-[24px] tracking-[5px] leading-none flex items-center gap-1.5">
            <Zap className="w-6 h-6 text-fast-orange fill-current" aria-hidden="true" />
            <span className="notranslate text-neon" translate="no">FAST</span>
          </div>
          <div className="text-xs on-night-muted font-bold tracking-wide uppercase leading-tight">RESTAURATEUR PRO</div>
        </Link>
        <div className="flex items-center gap-2">
          <div className="flex items-center gap-1.5 px-2.5 h-8 rounded-full bg-white/[0.06] border border-white/10">
            <div className="w-2 h-2 rounded-full bg-green-500 relative flex-shrink-0">
              <span className="absolute inset-0 rounded-full bg-green-500 animate-ping opacity-75" />
            </div>
            <span className="text-xs font-bold text-green-400">En ligne</span>
          </div>
          <button
            onClick={() => setSideOpen(true)}
            aria-label="Menu"
            className="bg-white/[0.07] border border-white/10 text-white w-11 h-11 rounded-full flex items-center justify-center hover:bg-white/[0.14] transition-colors active:scale-95 focus-visible:outline-fast-teal"
          >
            <Menu className="w-5 h-5" />
          </button>
          <button
            onClick={() => setKitchenOpen(true)}
            className="px-4 h-11 rounded-full text-sm font-bold bg-fast-teal text-fast-ink hover:brightness-110 transition-all active:scale-95 inline-flex items-center gap-1.5 focus-visible:outline-fast-teal"
          >
            <ChefHat className="w-4 h-4" /> Cuisine
          </button>
        </div>
      </header>

      <RushBar active={rushActive} />

      {/* Tabs */}
      <div className="bg-background border-b border-border flex gap-1 overflow-x-auto scrollbar-hide px-2 py-1.5">
        {tabs.map((tab) => {
          const isActive = activeTabId === tab.id;
          return (
            <Link
              key={tab.id}
              href={tab.href}
              aria-current={isActive ? "page" : undefined}
              className={`relative px-4 h-11 rounded-full text-xs font-bold tracking-wide whitespace-nowrap transition-colors flex items-center gap-1.5 no-underline focus-visible:outline-fast-teal ${
                isActive ? "text-foreground" : "text-muted-foreground hover:text-foreground"
              }`}
            >
              {isActive && (
                <m.div
                  layoutId="partner-tab"
                  className="absolute inset-0 rounded-full bg-fast-teal/15 border border-fast-teal/40"
                  transition={{ type: "spring", stiffness: 400, damping: 30 }}
                />
              )}
              <tab.Icon className={`w-4 h-4 relative z-10 ${isActive ? "text-fast-teal" : ""}`} />
              <span className="relative z-10">{tab.label}</span>
              {tab.badge && pendingCount > 0 && (
                <span className="relative z-10 bg-red-500 text-white min-w-[20px] h-5 px-1.5 rounded-full text-xs tabular-nums flex items-center justify-center font-bold">
                  {pendingCount}
                </span>
              )}
            </Link>
          );
        })}
      </div>

      <main className="px-4 py-6 sm:px-6 max-w-4xl mx-auto">{children}</main>

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
