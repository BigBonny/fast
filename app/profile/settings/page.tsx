"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/AuthContext";
import { ArrowLeft, Settings, Globe, Lock, HelpCircle, Shield, FileText, ChevronRight } from "lucide-react";
import Link from "next/link";

export default function SettingsPage() {
  const router = useRouter();
  const { isAuthenticated, user } = useAuth();

  useEffect(() => {
    if (!isAuthenticated) router.replace("/login");
  }, [isAuthenticated, router]);

  if (!isAuthenticated) return null;

  // Password reset has no backend endpoint yet, so it routes to support rather
  // than a dead "#" link.
  const items = [
    { icon: Globe, label: "Langue", value: "Français" },
    { icon: Lock, label: "Changer le mot de passe", href: "mailto:support@fast.app?subject=Changement%20de%20mot%20de%20passe" },
    { icon: HelpCircle, label: "Aide & support", href: "mailto:support@fast.app?subject=Aide%20FAST" },
    { icon: Shield, label: "Confidentialité", href: "/privacy-policy" },
    { icon: FileText, label: "CGU", href: "/terms-of-service" },
  ];

  return (
    <div className="min-h-screen bg-background pb-24">
      <div className="bg-background/90 backdrop-blur-md px-4 sm:px-6 py-3 border-b border-border sticky top-0 z-20">
        <div className="max-w-2xl mx-auto flex items-center gap-3">
          <Link href="/profile" className="w-11 h-11 rounded-full border border-border bg-card flex items-center justify-center hover:bg-muted transition-colors shrink-0">
            <ArrowLeft className="w-5 h-5 text-foreground" />
          </Link>
          <h1 className="font-display font-bold text-xl text-foreground">Paramètres</h1>
        </div>
      </div>

      <div className="px-4 sm:px-6 pt-6 max-w-2xl mx-auto">
        <div className="night-surface p-5 flex items-center gap-4 mb-8">
          <div className="w-12 h-12 bg-white/10 border border-white/15 rounded-full flex items-center justify-center shrink-0">
            <Settings className="w-5 h-5 text-fast-gold" />
          </div>
          <div className="min-w-0">
            <p className="font-display font-bold text-xl leading-tight">Paramètres du compte</p>
            <p className="text-sm on-night-muted mt-0.5 truncate">{user?.email}</p>
          </div>
        </div>

        <div className="border-y border-border divide-y divide-border">
          {items.map((item) => {
            const row = (
              <div className="py-4 min-h-[56px] flex items-center gap-3 hover:bg-muted/60 transition-colors">
                <item.icon className="w-5 h-5 text-muted-foreground shrink-0" />
                <span className="font-semibold text-foreground flex-1">{item.label}</span>
                {item.value ? (
                  <span className="text-sm text-muted-foreground">{item.value}</span>
                ) : (
                  <ChevronRight className="w-4 h-4 text-muted-foreground shrink-0" aria-hidden="true" />
                )}
              </div>
            );

            if (!item.href) return <div key={item.label}>{row}</div>;

            return item.href.startsWith("mailto:") ? (
              <a key={item.label} href={item.href} className="block">
                {row}
              </a>
            ) : (
              <Link key={item.label} href={item.href} className="block">
                {row}
              </Link>
            );
          })}
        </div>
      </div>
    </div>
  );
}
