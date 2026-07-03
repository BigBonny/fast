"use client";

import { motion, AnimatePresence } from "framer-motion";
import { X, User, ShoppingBag, Heart, MapPin, Settings, Shield, FileText, LogOut, Store, LucideIcon } from "lucide-react";
import Link from "next/link";
import { useAuth } from "@/lib/AuthContext";

interface MenuItem {
  icon: LucideIcon;
  label: string;
  href: string;
  isPartner?: boolean;
}

interface SideMenuProps {
  isOpen: boolean;
  onClose: () => void;
}

export default function SideMenu({ isOpen, onClose }: SideMenuProps) {
  const { user, isAuthenticated, logout } = useAuth();

  const handleLogout = () => {
    logout();
    if (typeof window !== "undefined") {
      window.location.href = "/";
    }
  };

  const isRestaurant = user?.role === "RESTAURANT";

  const menuItems: MenuItem[] = [
    ...(isRestaurant
      ? [
          { icon: Store, label: "Espace Restaurateur", href: "/partner", isPartner: true },
          { icon: ShoppingBag, label: "Commandes restaurant", href: "/partner/orders" },
          { icon: Settings, label: "Paramètres restaurant", href: "/partner/settings" },
        ]
      : []),
    { icon: User, label: "Mon compte", href: "/profile" },
    { icon: ShoppingBag, label: "Mes commandes", href: "/orders" },
    { icon: Heart, label: "Mes favoris", href: "/favorites" },
    { icon: MapPin, label: "Mes adresses", href: "/profile/addresses" },
    { icon: Settings, label: "Paramètres", href: "/profile/settings" },
    { icon: Shield, label: "Confidentialité", href: "/privacy-policy" },
    { icon: FileText, label: "CGU", href: "/terms-of-service" },
  ];

  return (
    <AnimatePresence>
      {isOpen && (
        <>
          {/* Overlay */}
          <motion.div
            className="fixed inset-0 z-40 bg-black/60 backdrop-blur-sm"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={onClose}
          />

          {/* Drawer */}
          <motion.div
            className="fixed top-0 left-0 bottom-0 z-50 w-72 flex flex-col"
            style={{ background: "#0d1117" }}
            initial={{ x: -288 }}
            animate={{ x: 0 }}
            exit={{ x: -288 }}
            transition={{ type: "spring", stiffness: 300, damping: 30 }}
          >
            {/* Header */}
            <div className="pt-12 pb-6 px-6" style={{ background: "linear-gradient(135deg, #1a0533, #0a1628)" }}>
              <div className="flex items-center justify-between mb-5">
                <div className="flex items-center gap-1">
                  <span className="text-lg">⚡</span>
                  <span className="font-black text-xl italic" style={{
                    background: "linear-gradient(90deg, #06b6d4, #8b5cf6, #ec4899)",
                    WebkitBackgroundClip: "text",
                    WebkitTextFillColor: "transparent",
                    transform: "skewX(-8deg)",
                    display: "inline-block"
                  }}>FAST</span>
                  <span className="text-lg">⚡</span>
                </div>
                <button onClick={onClose} className="w-8 h-8 rounded-full bg-white/10 flex items-center justify-center">
                  <X className="w-4 h-4 text-white" />
                </button>
              </div>

              {/* Avatar user */}
              <div className="flex items-center gap-3">
                <div className="w-12 h-12 rounded-2xl flex items-center justify-center text-xl font-black text-white"
                  style={{ background: "linear-gradient(135deg, #7c3aed, #06b6d4)" }}>
                  {user?.name ? user.name[0].toUpperCase() : "👤"}
                </div>
                <div>
                  <p className="text-white font-bold text-sm">{user?.name || "Mon compte"}</p>
                  <p className="text-gray-400 text-xs">{user?.email || ""}</p>
                </div>
              </div>

              {/* Points */}
              <div className="mt-4 flex items-center gap-2 bg-yellow-400/10 rounded-xl px-3 py-2">
                <span className="text-yellow-400 text-lg">⭐</span>
                <div>
                  <p className="text-yellow-400 font-black text-sm">85 Points</p>
                  <p className="text-gray-400 text-xs">Portefeuille FAST</p>
                </div>
              </div>
            </div>

            {/* Menu items */}
            <div className="flex-1 px-4 py-4 space-y-1 overflow-y-auto">
              {menuItems.map((item, idx) => {
                const Icon = item.icon;
                return (
                  <motion.div
                    key={item.label}
                    initial={{ opacity: 0, x: -20 }}
                    animate={{ opacity: 1, x: 0 }}
                    transition={{ delay: idx * 0.05 }}
                  >
                    <Link href={item.href} onClick={onClose}>
                      <div className="flex items-center gap-3 px-4 py-3 rounded-2xl hover:bg-white/8 transition-all group active:scale-[0.98]">
                        <div
                          className="w-9 h-9 rounded-xl flex items-center justify-center transition-all group-hover:scale-110"
                          style={{
                            background: item.isPartner
                              ? "linear-gradient(135deg, #00c8b3, #7c3aed)"
                              : "linear-gradient(135deg, #1a1f2e, #111827)",
                            boxShadow: item.isPartner ? "0 4px 12px rgba(0,200,179,0.25)" : "none",
                          }}
                        >
                          <Icon className={`w-4 h-4 ${item.isPartner ? "text-white" : "text-violet-400"}`} />
                        </div>
                        <span className="text-white text-sm font-bold group-hover:text-violet-300 transition-colors">
                          {item.label}
                        </span>
                        <span className="ml-auto text-gray-500 group-hover:text-white/70 transition-colors">›</span>
                      </div>
                    </Link>
                  </motion.div>
                );
              })}
            </div>

            {/* Footer */}
            <div className="px-4 pb-8 space-y-1 border-t border-white/5 pt-4">
              {isAuthenticated ? (
                <button
                  className="w-full flex items-center gap-3 px-4 py-3 rounded-xl hover:bg-red-500/10 transition-colors"
                  onClick={handleLogout}
                >
                  <div className="w-8 h-8 rounded-lg flex items-center justify-center bg-red-500/20">
                    <LogOut className="w-4 h-4 text-red-400" />
                  </div>
                  <span className="text-red-400 text-sm font-medium">Se déconnecter</span>
                </button>
              ) : (
                <div className="space-y-2">
                  <Link href="/login" onClick={onClose}>
                    <div className="w-full flex items-center gap-3 px-4 py-3 rounded-xl bg-white/5 hover:bg-white/10 transition-colors">
                      <div className="w-8 h-8 rounded-lg flex items-center justify-center bg-emerald-500/20">
                        <User className="w-4 h-4 text-emerald-400" />
                      </div>
                      <span className="text-emerald-400 text-sm font-medium">Se connecter</span>
                    </div>
                  </Link>
                  <Link href="/register" onClick={onClose}>
                    <div className="w-full flex items-center gap-3 px-4 py-3 rounded-xl bg-white/5 hover:bg-white/10 transition-colors">
                      <div className="w-8 h-8 rounded-lg flex items-center justify-center bg-violet-500/20">
                        <User className="w-4 h-4 text-violet-400" />
                      </div>
                      <span className="text-violet-400 text-sm font-medium">S'inscrire</span>
                    </div>
                  </Link>
                </div>
              )}
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}
