"use client";

import React, { useState, useEffect } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { m } from "framer-motion";
import { getCart, getCartCount } from "@/lib/localCart";
import { Home, ClipboardList, ShoppingCart, Bike, Users } from "lucide-react";
import Navbar from "@/components/Navbar";

const applyTheme = (mode: string) => {
  const root = document.documentElement;
  if (mode === "dark") {
    root.classList.add("dark");
  } else if (mode === "light") {
    root.classList.remove("dark");
  } else {
    const prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches;
    prefersDark ? root.classList.add("dark") : root.classList.remove("dark");
  }
};

const navItems = [
  { name: "Accueil", path: "/", icon: Home, color: "#06b6d4" },
  { name: "Commandes", path: "/orders", icon: ClipboardList, color: "#8b5cf6" },
  { name: "Groupe", path: "/group-order", icon: Users, color: "#ec4899" },
  { name: "Livrer", path: "/deliver", icon: Bike, color: "#f59e0b" },
  { name: "Panier", path: "/cart", icon: ShoppingCart, color: "#10b981" },
];

const hideNavPaths = ["/welcome", "/profile", "/login", "/register"];

export default function Layout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const [mounted, setMounted] = useState(false);
  const [cartCount, setCartCount] = useState(0);

  useEffect(() => {
    setMounted(true);
    setCartCount(getCartCount(getCart()));
    const savedMode = localStorage.getItem("fast_theme") || "system";
    applyTheme(savedMode);

    const mq = window.matchMedia("(prefers-color-scheme: dark)");
    const handler = () => {
      if ((localStorage.getItem("fast_theme") || "system") === "system") {
        applyTheme("system");
      }
    };
    mq.addEventListener("change", handler);

    const onStorage = () => setCartCount(getCartCount(getCart()));
    window.addEventListener("storage", onStorage);
    return () => {
      mq.removeEventListener("change", handler);
      window.removeEventListener("storage", onStorage);
    };
  }, []);
  const showNav = !hideNavPaths.some((path) => pathname?.startsWith(path));

  if (!mounted) {
    return <div className="min-h-screen bg-white dark:bg-gray-950">{children}</div>;
  }

  return (
    <div className="min-h-screen bg-white dark:bg-gray-950">
      <style>{`
        :root { --fast-primary: #7c3aed; --fast-secondary: #10b981; }
        .scrollbar-hide::-webkit-scrollbar { display: none; }
        .scrollbar-hide { -ms-overflow-style: none; scrollbar-width: none; }
      `}</style>

      {showNav && <Navbar />}

      <main className={showNav ? "pb-20 md:pb-0 md:pt-16" : ""}>{children}</main>

      {showNav && (
        <nav className="md:hidden fixed bottom-4 left-4 right-4 z-50 max-w-lg mx-auto">
          <div
            className="flex items-center justify-between px-2 py-2 rounded-3xl border border-white/10 shadow-2xl"
            style={{
              background: "rgba(13, 15, 24, 0.82)",
              backdropFilter: "blur(24px) saturate(180%)",
              boxShadow: "0 12px 40px rgba(0,0,0,0.35), 0 0 0 1px rgba(255,255,255,0.06) inset",
            }}
          >
            {navItems.map((item) => {
              const isActive = pathname === item.path;
              const Icon = item.icon;

              return (
                <Link
                  key={item.path}
                  href={item.path}
                  className="relative flex flex-col items-center justify-center gap-0.5 py-1.5 px-3 rounded-2xl transition-all duration-300 group"
                  style={{
                    background: isActive ? `rgba(255,255,255,0.08)` : "transparent",
                    boxShadow: isActive ? `0 0 20px ${item.color}40` : "none",
                  }}
                >
                  {isActive && (
                    <m.div
                      layoutId="nav-indicator"
                      className="absolute inset-0 rounded-2xl border border-white/10"
                      style={{ background: `linear-gradient(180deg, ${item.color}22, transparent)` }}
                      transition={{ type: "spring", stiffness: 400, damping: 30 }}
                    />
                  )}

                  <div className="relative">
                    <Icon
                      className="w-[18px] h-[18px] transition-all duration-300 group-hover:scale-110"
                      style={{ color: isActive ? item.color : "rgba(255,255,255,0.65)" }}
                      strokeWidth={isActive ? 2.6 : 2}
                    />
                    {item.path === "/cart" && cartCount > 0 && (
                      <div className="absolute -top-2 -right-2.5 min-w-[16px] h-4 px-1 bg-red-500 rounded-full flex items-center justify-center border border-[#0d0f18]">
                        <span className="text-[9px] font-black text-white">{cartCount}</span>
                      </div>
                    )}
                  </div>

                  <span
                    className="text-[9px] font-bold transition-all duration-300 relative z-10"
                    style={{ color: isActive ? "#fff" : "rgba(255,255,255,0.55)" }}
                  >
                    {item.name}
                  </span>

                  {isActive && (
                    <div
                      className="absolute -bottom-0.5 left-1/2 -translate-x-1/2 w-5 h-1 rounded-full"
                      style={{ background: item.color }}
                    />
                  )}
                </Link>
              );
            })}
          </div>
        </nav>
      )}
    </div>
  );
}
