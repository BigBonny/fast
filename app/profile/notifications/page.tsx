"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/AuthContext";
import {
  NotificationPreferences,
  defaultNotificationPreferences,
  getNotificationPreferences,
  setNotificationPreference,
} from "@/lib/localPreferences";
import { ArrowLeft, Bell, Package, Tag, Info } from "lucide-react";
import Link from "next/link";

const OPTIONS: {
  key: keyof NotificationPreferences;
  icon: typeof Package;
  label: string;
  desc: string;
}[] = [
  { key: "orderStatus", icon: Package, label: "Statut des commandes", desc: "Recevoir des notifications sur mes commandes" },
  { key: "promotions", icon: Tag, label: "Promotions", desc: "Offres et réductions personnalisées" },
  { key: "news", icon: Info, label: "Actualités FAST", desc: "Nouvelles fonctionnalités et mises à jour" },
];

export default function NotificationsPage() {
  const router = useRouter();
  const { isAuthenticated } = useAuth();
  const [prefs, setPrefs] = useState<NotificationPreferences>(defaultNotificationPreferences);

  useEffect(() => {
    if (!isAuthenticated) router.replace("/login");
  }, [isAuthenticated, router]);

  useEffect(() => {
    setPrefs(getNotificationPreferences());
  }, []);

  if (!isAuthenticated) return null;

  const toggle = (key: keyof NotificationPreferences) => {
    setPrefs(setNotificationPreference(key, !prefs[key]));
  };

  return (
    <div className="min-h-screen bg-background pb-24">
      <div className="bg-background/90 backdrop-blur-md px-4 sm:px-6 py-3 border-b border-border sticky top-0 z-20">
        <div className="max-w-2xl mx-auto flex items-center gap-3">
          <Link href="/profile" className="w-11 h-11 rounded-full border border-border bg-card flex items-center justify-center hover:bg-muted transition-colors shrink-0">
            <ArrowLeft className="w-5 h-5 text-foreground" />
          </Link>
          <h1 className="font-display font-bold text-xl text-foreground">Notifications</h1>
        </div>
      </div>

      <div className="px-4 sm:px-6 pt-6 max-w-2xl mx-auto">
        <div className="night-surface p-5 flex items-center gap-4 mb-8">
          <div className="w-12 h-12 bg-white/10 border border-white/15 rounded-full flex items-center justify-center shrink-0">
            <Bell className="w-5 h-5 text-fast-gold" />
          </div>
          <div className="min-w-0">
            <p className="font-display font-bold text-xl leading-tight">Notifications push</p>
            <p className="text-sm on-night-muted mt-0.5">Activer les notifications</p>
          </div>
        </div>

        <div className="border-y border-border divide-y divide-border">
          {OPTIONS.map((opt) => {
            const value = prefs[opt.key];
            return (
              <button
                key={opt.key}
                type="button"
                role="switch"
                aria-checked={value}
                onClick={() => toggle(opt.key)}
                className="w-full text-left py-4 flex items-center gap-3 hover:bg-muted/60 transition-colors"
              >
                <opt.icon className="w-5 h-5 text-muted-foreground shrink-0" />
                <div className="flex-1 min-w-0">
                  <p className="font-semibold text-foreground">{opt.label}</p>
                  <p className="text-xs text-muted-foreground mt-0.5">{opt.desc}</p>
                </div>
                <div className={`w-11 h-6 rounded-full p-1 transition-colors shrink-0 ${value ? "bg-primary" : "bg-muted-foreground/30"}`}>
                  <div className={`w-4 h-4 rounded-full bg-white shadow transition-transform ${value ? "translate-x-5" : "translate-x-0"}`} />
                </div>
              </button>
            );
          })}
        </div>
      </div>
    </div>
  );
}
