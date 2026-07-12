"use client";

import React, { useState, useEffect, useRef } from "react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { m, AnimatePresence } from "framer-motion";
import {
  Zap, Home, ClipboardList, Users, Bike, ShoppingCart,
  User, Store, Heart, Settings, LogOut, ChevronDown,
} from "lucide-react";
import { useAuth } from "@/lib/AuthContext";
import { getCart, getCartCount } from "@/lib/localCart";

const navLinks = [
  { label: "Accueil", href: "/", icon: Home },
  { label: "Commandes", href: "/orders", icon: ClipboardList },
  { label: "Groupe", href: "/group-order", icon: Users },
  { label: "Livrer", href: "/deliver", icon: Bike },
];

export default function Navbar() {
  const pathname = usePathname();
  const router = useRouter();
  const { user, isAuthenticated, logout } = useAuth();
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

  const handleLogout = () => {
    logout();
    setUserMenuOpen(false);
    router.push("/");
  };

  const isActive = (href: string) =>
    href === "/" ? pathname === "/" : pathname?.startsWith(href);

  return (
    <header
      className="hidden md:flex fixed top-0 left-0 right-0 z-50 items-center justify-between px-8 h-16 border-b border-white/8"
      style={{
        background: "rgba(8,9,15,0.88)",
        backdropFilter: "blur(20px) saturate(180%)",
        boxShadow: "0 1px 0 rgba(255,255,255,0.06)",
      }}
    >
      {/* Logo */}
      <Link href="/" className="flex items-center gap-1.5 shrink-0">
        <Zap className="w-6 h-6 text-amber-400 fill-amber-400" />
        <span
          className="font-black text-2xl italic tracking-tight"
          style={{
            background: "linear-gradient(90deg, #f59e0b, #fbbf24, #f97316)",
            WebkitBackgroundClip: "text",
            WebkitTextFillColor: "transparent",
          }}
        >
          FAST
        </span>
        <Zap className="w-6 h-6 text-amber-400 fill-amber-400" />
      </Link>

      {/* Nav links */}
      <nav className="flex items-center gap-1">
        {navLinks.map(({ label, href, icon: Icon }) => {
          const active = isActive(href);
          return (
            <Link
              key={href}
              href={href}
              className="relative flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-semibold transition-all duration-200 group"
              style={{
                color: active ? "#fff" : "rgba(255,255,255,0.55)",
                background: active ? "rgba(255,255,255,0.08)" : "transparent",
              }}
            >
              <Icon
                className="w-4 h-4 transition-colors"
                style={{ color: active ? "#06b6d4" : "rgba(255,255,255,0.45)" }}
              />
              {label}
              {active && (
                <m.div
                  layoutId="navbar-indicator"
                  className="absolute bottom-0 left-1/2 -translate-x-1/2 w-6 h-0.5 rounded-full bg-cyan-400"
                  transition={{ type: "spring", stiffness: 400, damping: 30 }}
                />
              )}
            </Link>
          );
        })}

        {user?.role === "RESTAURANT" && (
          <Link
            href="/partner/orders"
            className="flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-bold text-white ml-2"
            style={{ background: "linear-gradient(135deg, #00c8b3, #7c3aed)" }}
          >
            <Store className="w-4 h-4" />
            Espace Pro
          </Link>
        )}
      </nav>

      {/* Right actions */}
      <div className="flex items-center gap-2 shrink-0">
        {/* Cart */}
        <Link href="/cart">
          <button
            className="relative w-10 h-10 rounded-xl flex items-center justify-center transition-colors hover:bg-white/10"
            style={{ background: "rgba(255,255,255,0.06)" }}
          >
            <ShoppingCart className="w-5 h-5 text-white/70" />
            {cartCount > 0 && (
              <span className="absolute -top-1 -right-1 min-w-[18px] h-[18px] px-1 bg-red-500 rounded-full flex items-center justify-center text-[10px] font-black text-white border-2 border-[#08090f]">
                {cartCount}
              </span>
            )}
          </button>
        </Link>

        {/* Favorites */}
        <Link href="/favorites">
          <button
            className="w-10 h-10 rounded-xl flex items-center justify-center transition-colors hover:bg-white/10"
            style={{ background: "rgba(255,255,255,0.06)" }}
          >
            <Heart className="w-5 h-5 text-white/70" />
          </button>
        </Link>

        {/* User menu */}
        {isAuthenticated ? (
          <div ref={userMenuRef} className="relative">
            <button
              onClick={() => setUserMenuOpen((o) => !o)}
              className="flex items-center gap-2 px-3 py-2 rounded-xl transition-colors hover:bg-white/10"
              style={{ background: "rgba(255,255,255,0.06)" }}
            >
              <div
                className="w-7 h-7 rounded-lg flex items-center justify-center text-sm font-black text-white"
                style={{ background: "linear-gradient(135deg, #14b8a6, #8b5cf6)" }}
              >
                {user?.name ? user.name[0].toUpperCase() : <User className="w-4 h-4" />}
              </div>
              <span className="text-sm font-semibold text-white/80 max-w-[100px] truncate hidden lg:block">
                {user?.name?.split(" ")[0]}
              </span>
              <ChevronDown
                className="w-3.5 h-3.5 text-white/40 transition-transform"
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
                  className="absolute right-0 top-12 w-56 rounded-2xl border border-white/10 overflow-hidden shadow-2xl"
                  style={{ background: "#0d1117" }}
                >
                  <div className="px-4 py-3 border-b border-white/8">
                    <p className="text-white font-bold text-sm">{user?.name}</p>
                    <p className="text-gray-400 text-xs truncate">{user?.email}</p>
                  </div>
                  <div className="p-2 space-y-0.5">
                    <Link href="/profile" onClick={() => setUserMenuOpen(false)}>
                      <div className="flex items-center gap-3 px-3 py-2.5 rounded-xl hover:bg-white/8 transition-colors group cursor-pointer">
                        <User className="w-4 h-4 text-violet-400" />
                        <span className="text-sm text-white/80 group-hover:text-white">Mon compte</span>
                      </div>
                    </Link>
                    <Link href="/orders" onClick={() => setUserMenuOpen(false)}>
                      <div className="flex items-center gap-3 px-3 py-2.5 rounded-xl hover:bg-white/8 transition-colors group cursor-pointer">
                        <ClipboardList className="w-4 h-4 text-cyan-400" />
                        <span className="text-sm text-white/80 group-hover:text-white">Mes commandes</span>
                      </div>
                    </Link>
                    <Link href="/favorites" onClick={() => setUserMenuOpen(false)}>
                      <div className="flex items-center gap-3 px-3 py-2.5 rounded-xl hover:bg-white/8 transition-colors group cursor-pointer">
                        <Heart className="w-4 h-4 text-pink-400" />
                        <span className="text-sm text-white/80 group-hover:text-white">Mes favoris</span>
                      </div>
                    </Link>
                    <Link href="/profile/settings" onClick={() => setUserMenuOpen(false)}>
                      <div className="flex items-center gap-3 px-3 py-2.5 rounded-xl hover:bg-white/8 transition-colors group cursor-pointer">
                        <Settings className="w-4 h-4 text-gray-400" />
                        <span className="text-sm text-white/80 group-hover:text-white">Paramètres</span>
                      </div>
                    </Link>
                    <div className="border-t border-white/8 mt-1 pt-1">
                      <button
                        onClick={handleLogout}
                        className="w-full flex items-center gap-3 px-3 py-2.5 rounded-xl hover:bg-red-500/10 transition-colors group"
                      >
                        <LogOut className="w-4 h-4 text-red-400" />
                        <span className="text-sm text-red-400 group-hover:text-red-300">Se déconnecter</span>
                      </button>
                    </div>
                  </div>
                </m.div>
              )}
            </AnimatePresence>
          </div>
        ) : (
          <div className="flex items-center gap-2">
            <Link href="/login">
              <button className="px-4 py-2 rounded-xl text-sm font-semibold text-white/70 hover:text-white hover:bg-white/8 transition-colors">
                Connexion
              </button>
            </Link>
            <Link href="/register">
              <button
                className="px-4 py-2 rounded-xl text-sm font-bold text-white"
                style={{ background: "linear-gradient(135deg, #7c3aed, #06b6d4)" }}
              >
                S'inscrire
              </button>
            </Link>
          </div>
        )}
      </div>
    </header>
  );
}
