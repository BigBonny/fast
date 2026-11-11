"use client";

import React, { useState, useEffect } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { m } from "framer-motion";
import { getCart, getCartCount } from "@/lib/localCart";
import { useTheme } from "@/lib/useTheme";
import { useI18n } from "@/lib/i18n";
import { Home, ClipboardList, ShoppingCart, Users } from "lucide-react";
import Navbar from "@/components/Navbar";

const navItems = [
  { labelKey: "nav_home", path: "/", icon: Home },
  { labelKey: "nav_orders", path: "/orders", icon: ClipboardList },
  { labelKey: "nav_group", path: "/group-order", icon: Users },
  { labelKey: "nav_cart", path: "/cart", icon: ShoppingCart },
];

const hideNavPaths = ["/welcome", "/profile", "/login", "/register"];

export default function Layout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const [mounted, setMounted] = useState(false);
  const [cartCount, setCartCount] = useState(0);

  // Theme is owned by useTheme so the client and partner shells stay in sync.
  useTheme();
  const { t } = useI18n();

  useEffect(() => {
    setMounted(true);
    setCartCount(getCartCount(getCart()));

    const onStorage = () => setCartCount(getCartCount(getCart()));
    window.addEventListener("storage", onStorage);
    return () => window.removeEventListener("storage", onStorage);
  }, []);

  // localStorage writes in this tab don't fire `storage`, so re-read on navigation.
  useEffect(() => {
    setCartCount(getCartCount(getCart()));
  }, [pathname]);

  const showNav = !hideNavPaths.some((path) => pathname?.startsWith(path));

  if (!mounted) {
    return <div className="min-h-screen bg-background">{children}</div>;
  }

  return (
    <div className="min-h-screen bg-background text-foreground">
      {showNav && <Navbar />}

      <main className={showNav ? "pb-24 md:pb-0 md:pt-16" : ""}>{children}</main>

      {showNav && (
        <nav
          className="md:hidden fixed left-3 right-3 z-50 max-w-lg mx-auto"
          style={{ bottom: "calc(1rem + env(safe-area-inset-bottom))" }}
        >
          {/* Floating frosted pill, as in the app. */}
          <div className="flex items-center justify-between gap-1 p-1.5 rounded-full border border-border bg-background/85 backdrop-blur-xl backdrop-saturate-150 shadow-[0_12px_32px_-12px_rgba(0,0,0,0.35)]">
            {navItems.map((item) => {
              const isActive = pathname === item.path;
              const Icon = item.icon;

              return (
                <Link
                  key={item.path}
                  href={item.path}
                  aria-current={isActive ? "page" : undefined}
                  className={`relative flex flex-1 min-w-0 flex-col items-center justify-center gap-0.5 min-h-[52px] px-1 rounded-full transition-colors duration-200 ${
                    isActive ? "text-white" : "text-muted-foreground hover:text-foreground"
                  }`}
                >
                  {isActive && (
                    <m.div
                      layoutId="nav-indicator"
                      className="absolute inset-0 rounded-full bg-primary"
                      transition={{ type: "spring", stiffness: 400, damping: 30 }}
                    />
                  )}

                  <div className="relative">
                    <Icon className="w-5 h-5" strokeWidth={isActive ? 2.4 : 2} />
                    {item.path === "/cart" && cartCount > 0 && (
                      <div className="absolute -top-2 -right-3 min-w-[18px] h-[18px] px-1 bg-fast-gold rounded-full flex items-center justify-center">
                        <span className="text-xs leading-none font-extrabold text-fast-ink tabular-nums">{cartCount}</span>
                      </div>
                    )}
                  </div>

                  <span className="relative z-10 max-w-full truncate text-xs font-bold leading-tight tracking-tight">
                    {t(item.labelKey)}
                  </span>
                </Link>
              );
            })}
          </div>
        </nav>
      )}
    </div>
  );
}
