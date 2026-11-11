"use client";

import { m, AnimatePresence } from "framer-motion";
import { X, User, UserPlus, ShoppingBag, Heart, MapPin, Settings, Shield, FileText, LogOut, LogIn, Store, LucideIcon, Star, ChevronRight } from "lucide-react";
import Link from "next/link";
import { useAuth } from "@/lib/AuthContext";
import { useI18n, LANGUAGES } from "@/lib/i18n";

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
  const { lang, setLang, t } = useI18n();

  const handleLogout = async () => {
    await logout(true);
  };

  const isRestaurant = user?.role === "RESTAURANT";

  const menuItems: MenuItem[] = [
    ...(isRestaurant
      ? [
          { icon: Store, label: t("resto_space"), href: "/partner", isPartner: true },
          { icon: ShoppingBag, label: t("resto_orders"), href: "/partner/orders" },
          { icon: Settings, label: t("resto_settings"), href: "/partner/settings" },
        ]
      : []),
    { icon: User, label: t("my_account"), href: "/profile" },
    { icon: ShoppingBag, label: t("my_orders"), href: "/orders" },
    { icon: Heart, label: t("my_favorites"), href: "/favorites" },
    { icon: MapPin, label: t("my_addresses"), href: "/profile/addresses" },
    { icon: Settings, label: t("settings"), href: "/profile/settings" },
    { icon: Shield, label: t("privacy"), href: "/privacy-policy" },
    { icon: FileText, label: t("cgu"), href: "/terms-of-service" },
  ];

  // Hairline dividers between groups: partner / account / legal.
  const groupStarts = new Set(["/profile", "/privacy-policy"]);

  return (
    <AnimatePresence>
      {isOpen && (
        <>
          {/* Overlay */}
          <m.div
            className="fixed inset-0 z-40 bg-black/60 backdrop-blur-sm"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={onClose}
          />

          {/* Drawer */}
          <m.div
            className="fixed top-0 left-0 bottom-0 z-50 w-72 flex flex-col bg-card text-foreground border-r border-border shadow-2xl"
            initial={{ x: -288 }}
            animate={{ x: 0 }}
            exit={{ x: -288 }}
            transition={{ type: "spring", stiffness: 300, damping: 30 }}
          >
            {/* Header */}
            <div className="night-band pt-12 pb-6 px-6">
              <div className="flex items-center justify-between mb-6">
                <span className="text-neon font-black text-3xl italic tracking-tight pr-1">
                  <span className="notranslate" translate="no">FAST</span>
                </span>
                <button
                  onClick={onClose}
                  className="w-11 h-11 -mr-2 rounded-full bg-white/10 hover:bg-white/15 transition-colors flex items-center justify-center"
                >
                  <X className="w-5 h-5 text-white" />
                </button>
              </div>

              {/* Avatar user */}
              <div className="flex items-center gap-3">
                <div className="w-12 h-12 shrink-0 rounded-full flex items-center justify-center text-xl font-extrabold bg-primary text-primary-foreground">
                  {user?.name ? user.name[0].toUpperCase() : <User className="w-6 h-6" />}
                </div>
                <div className="min-w-0">
                  <p className="font-display text-white font-bold text-lg leading-tight truncate">{user?.name || t("my_account")}</p>
                  <p className="on-night-muted text-xs truncate">{user?.email || ""}</p>
                </div>
              </div>

              {/* Points */}
              <div className="mt-5 flex items-center gap-3 rounded-2xl bg-white/[0.06] border border-white/10 px-3 py-2.5">
                <span className="w-8 h-8 shrink-0 rounded-full bg-fast-gold flex items-center justify-center">
                  <Star className="w-4 h-4 text-fast-ink fill-fast-ink" />
                </span>
                <div>
                  <p className="text-white font-extrabold text-sm tabular-nums">{user?.points ?? 0} Points</p>
                  <p className="on-night-muted text-xs">{t("wallet")}</p>
                </div>
              </div>
            </div>

            {/* Menu items */}
            <div className="flex-1 px-3 py-3 overflow-y-auto">
              {menuItems.map((item, idx) => {
                const Icon = item.icon;
                return (
                  <m.div
                    key={item.label}
                    initial={{ opacity: 0, x: -20 }}
                    animate={{ opacity: 1, x: 0 }}
                    transition={{ delay: idx * 0.05 }}
                  >
                    {idx > 0 && groupStarts.has(item.href) && (
                      <div className="my-2 mx-3 border-t border-border" />
                    )}
                    <Link href={item.href} onClick={onClose}>
                      <div className="flex items-center gap-3 px-3 min-h-[48px] rounded-xl hover:bg-muted transition-colors active:scale-[0.98]">
                        <Icon
                          className={`w-5 h-5 shrink-0 ${item.isPartner ? "text-fast-rose" : "text-muted-foreground"}`}
                          strokeWidth={1.8}
                        />
                        <span className="text-foreground text-sm font-semibold">
                          {item.label}
                        </span>
                        <ChevronRight className="ml-auto w-4 h-4 shrink-0 text-muted-foreground rtl:rotate-180" />
                      </div>
                    </Link>
                  </m.div>
                );
              })}
            </div>

            {/* Footer */}
            <div className="px-4 pb-8 pt-4 space-y-3 border-t border-border">
              <select
                value={lang}
                onChange={(e) => setLang(e.target.value)}
                aria-label="Language"
                className="w-full h-11 px-4 rounded-full bg-transparent text-foreground text-sm font-bold border border-border outline-none cursor-pointer focus-visible:ring-2 focus-visible:ring-ring"
              >
                {LANGUAGES.map((l) => (
                  <option key={l.code} value={l.code} className="text-black">
                    {l.label}
                  </option>
                ))}
              </select>
              {isAuthenticated ? (
                <button
                  className="w-full flex items-center justify-center gap-2 min-h-[44px] px-4 rounded-full border border-red-500/60 text-red-600 dark:text-red-400 text-sm font-bold hover:bg-red-500/10 transition-colors"
                  onClick={handleLogout}
                >
                  <LogOut className="w-4 h-4" />
                  <span>{t("logout")}</span>
                </button>
              ) : (
                <div className="space-y-2">
                  <Link href="/login" onClick={onClose} className="block">
                    <div className="btn-neon w-full text-sm">
                      <LogIn className="w-4 h-4" />
                      <span>{t("login_submit")}</span>
                    </div>
                  </Link>
                  <Link href="/register" onClick={onClose} className="block">
                    <div className="btn-outline w-full text-sm">
                      <UserPlus className="w-4 h-4" />
                      <span>{t("signup_btn")}</span>
                    </div>
                  </Link>
                </div>
              )}
            </div>
          </m.div>
        </>
      )}
    </AnimatePresence>
  );
}
