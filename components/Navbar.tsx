"use client";

import React, { useState, useEffect, useRef } from "react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { m, AnimatePresence } from "framer-motion";
import {
  Home, ClipboardList, Users, ShoppingCart,
  User, Store, Heart, Settings, LogOut, ChevronDown,
} from "lucide-react";
import { useAuth } from "@/lib/AuthContext";
import { useI18n, LANGUAGES } from "@/lib/i18n";
import { getCart, getCartCount } from "@/lib/localCart";

const navLinks = [
  { labelKey: "nav_home", href: "/", icon: Home },
  { labelKey: "nav_orders", href: "/orders", icon: ClipboardList },
  { labelKey: "nav_group", href: "/group-order", icon: Users },
];

const iconBtn =
  "relative w-11 h-11 rounded-full flex items-center justify-center text-muted-foreground transition-colors hover:bg-muted hover:text-foreground";
const menuRow =
  "flex items-center gap-3 px-3 min-h-[44px] rounded-xl text-foreground hover:bg-muted transition-colors cursor-pointer";

export default function Navbar() {
  const pathname = usePathname();
  const router = useRouter();
  const { user, isAuthenticated, logout } = useAuth();
  const { lang, setLang, t } = useI18n();
  const [cartCount, setCartCount] = useState(0);
  const [userMenuOpen, setUserMenuOpen] = useState(false);
  const userMenuRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    setCartCount(getCartCount(getCart()));
    const onStorage = () => setCartCount(getCartCount(getCart()));
    window.addEventListener("storage", onStorage);
    return () => window.removeEventListener("storage", onStorage);
  }, []);

  useEffect(() => {
    const handler = (e: MouseEvent) => {
      if (userMenuRef.current && !userMenuRef.current.contains(e.target as Node)) {
        setUserMenuOpen(false);
      }
    };
    document.addEventListener("mousedown", handler);
    return () => document.removeEventListener("mousedown", handler);
  }, []);

  const handleLogout = async () => {
    setUserMenuOpen(false);
    await logout();
    router.push("/");
  };

  const isActive = (href: string) =>
    href === "/" ? pathname === "/" : pathname?.startsWith(href);

  return (
    <header className="hidden md:flex fixed top-0 left-0 right-0 z-50 items-center justify-between px-8 h-16 border-b border-border bg-background/85 backdrop-blur-xl backdrop-saturate-150">
      {/* Logo */}
      <Link href="/" className="flex items-center shrink-0">
        <span
          className="text-neon font-black text-2xl italic tracking-tight notranslate pr-1"
          translate="no"
        >
          FAST
        </span>
      </Link>

      {/* Nav links */}
      <nav className="flex items-center gap-1">
        {navLinks.map(({ labelKey, href, icon: Icon }) => {
          const active = isActive(href);
          return (
            <Link
              key={href}
              href={href}
              aria-current={active ? "page" : undefined}
              className={`relative flex items-center gap-2 px-4 h-10 rounded-full text-sm font-semibold transition-colors duration-200 ${
                active ? "text-foreground" : "text-muted-foreground hover:text-foreground hover:bg-muted"
              }`}
            >
              <Icon className={`w-4 h-4 ${active ? "text-fast-rose" : ""}`} />
              {t(labelKey)}
              {active && (
                <m.div
                  layoutId="navbar-indicator"
                  className="absolute bottom-0 left-1/2 -translate-x-1/2 w-6 h-0.5 rounded-full bg-primary"
                  transition={{ type: "spring", stiffness: 400, damping: 30 }}
                />
              )}
            </Link>
          );
        })}

        {user?.role === "RESTAURANT" && (
          <Link
            href="/partner/orders"
            className="btn-outline !min-h-[2.5rem] !px-4 text-sm ml-2"
          >
            <Store className="w-4 h-4" />
            {t("pro_space")}
          </Link>
        )}
      </nav>

      {/* Right actions */}
      <div className="flex items-center gap-1.5 shrink-0">
        {/* Language picker */}
        <select
          value={lang}
          onChange={(e) => setLang(e.target.value)}
          aria-label="Language"
          className="h-10 px-3 rounded-full text-xs font-bold text-foreground bg-transparent border border-border cursor-pointer outline-none hover:bg-muted focus-visible:ring-2 focus-visible:ring-ring"
        >
          {LANGUAGES.map((l) => (
            <option key={l.code} value={l.code} className="text-black">
              {l.label}
            </option>
          ))}
        </select>

        {/* Cart */}
        <Link href="/cart">
          <button className={iconBtn}>
            <ShoppingCart className="w-5 h-5" />
            {cartCount > 0 && (
              <span className="absolute top-0.5 right-0.5 min-w-[18px] h-[18px] px-1 bg-fast-gold rounded-full flex items-center justify-center text-xs leading-none font-extrabold text-fast-ink tabular-nums">
                {cartCount}
              </span>
            )}
          </button>
        </Link>

        {/* Favorites */}
        <Link href="/favorites">
          <button className={iconBtn}>
            <Heart className="w-5 h-5" />
          </button>
        </Link>

        {/* User menu */}
        {isAuthenticated ? (
          <div ref={userMenuRef} className="relative">
            <button
              onClick={() => setUserMenuOpen((o) => !o)}
              className="flex items-center gap-2 pl-1.5 pr-3 h-11 rounded-full border border-border transition-colors hover:bg-muted"
            >
              <div className="w-8 h-8 rounded-full flex items-center justify-center text-sm font-extrabold bg-primary text-primary-foreground">
                {user?.name ? user.name[0].toUpperCase() : <User className="w-4 h-4" />}
              </div>
              <span className="text-sm font-semibold text-foreground max-w-[100px] truncate hidden lg:block">
                {user?.name?.split(" ")[0]}
              </span>
              <ChevronDown
                className="w-3.5 h-3.5 text-muted-foreground transition-transform"
                style={{ transform: userMenuOpen ? "rotate(180deg)" : "rotate(0deg)" }}
              />
            </button>

            <AnimatePresence>
              {userMenuOpen && (
                <m.div
                  initial={{ opacity: 0, y: -8, scale: 0.97 }}
                  animate={{ opacity: 1, y: 0, scale: 1 }}
                  exit={{ opacity: 0, y: -8, scale: 0.97 }}
                  transition={{ duration: 0.15 }}
                  className="absolute right-0 top-[3.25rem] w-60 rounded-2xl border border-border bg-popover text-popover-foreground overflow-hidden shadow-xl"
                >
                  <div className="px-4 py-3 border-b border-border">
                    <p className="text-foreground font-bold text-sm">{user?.name}</p>
                    <p className="text-muted-foreground text-xs truncate">{user?.email}</p>
                  </div>
                  <div className="p-2 space-y-0.5">
                    <Link href="/profile" onClick={() => setUserMenuOpen(false)}>
                      <div className={menuRow}>
                        <User className="w-4 h-4 text-muted-foreground" />
                        <span className="text-sm font-medium">{t("my_account")}</span>
                      </div>
                    </Link>
                    <Link href="/orders" onClick={() => setUserMenuOpen(false)}>
                      <div className={menuRow}>
                        <ClipboardList className="w-4 h-4 text-muted-foreground" />
                        <span className="text-sm font-medium">{t("my_orders")}</span>
                      </div>
                    </Link>
                    <Link href="/favorites" onClick={() => setUserMenuOpen(false)}>
                      <div className={menuRow}>
                        <Heart className="w-4 h-4 text-muted-foreground" />
                        <span className="text-sm font-medium">{t("my_favorites")}</span>
                      </div>
                    </Link>
                    <Link href="/profile/settings" onClick={() => setUserMenuOpen(false)}>
                      <div className={menuRow}>
                        <Settings className="w-4 h-4 text-muted-foreground" />
                        <span className="text-sm font-medium">{t("settings")}</span>
                      </div>
                    </Link>
                    <div className="border-t border-border mt-1 pt-1">
                      <button
                        onClick={handleLogout}
                        className="w-full flex items-center gap-3 px-3 min-h-[44px] rounded-xl text-red-600 dark:text-red-400 hover:bg-red-500/10 transition-colors"
                      >
                        <LogOut className="w-4 h-4" />
                        <span className="text-sm font-medium">{t("logout")}</span>
                      </button>
                    </div>
                  </div>
                </m.div>
              )}
            </AnimatePresence>
          </div>
        ) : (
          <div className="flex items-center gap-2 ml-1">
            <Link href="/login">
              <button className="btn-outline !min-h-[2.5rem] !px-4 text-sm">
                {t("login_btn")}
              </button>
            </Link>
            <Link href="/register">
              <button className="btn-neon !min-h-[2.5rem] !px-4 text-sm">
                {t("signup_btn")}
              </button>
            </Link>
          </div>
        )}
      </div>
    </header>
  );
}
