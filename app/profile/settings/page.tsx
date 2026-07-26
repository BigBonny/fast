"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/AuthContext";
import { ArrowLeft, Settings, Globe, Lock, HelpCircle, Shield, FileText } from "lucide-react";
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
    <div className="min-h-screen bg-gray-50 dark:bg-gray-950 pb-20">
      <div className="bg-white dark:bg-gray-900 px-5 py-4 flex items-center gap-3 border-b border-gray-100 dark:border-gray-800 sticky top-0 z-20">
        <Link href="/profile" className="w-9 h-9 bg-gray-50 dark:bg-gray-800 rounded-xl flex items-center justify-center">
          <ArrowLeft className="w-4 h-4 text-gray-600 dark:text-gray-300" />
        </Link>
        <h1 className="font-bold text-gray-900 dark:text-white">Paramètres</h1>
      </div>

      <div className="px-5 pt-5">
        <div className="bg-white dark:bg-gray-900 rounded-2xl p-4 flex items-center gap-4 shadow-sm border border-gray-100 dark:border-gray-800 mb-4">
          <div className="w-12 h-12 bg-cyan-100 dark:bg-cyan-500/15 rounded-xl flex items-center justify-center">
            <Settings className="w-6 h-6 text-cyan-600 dark:text-cyan-400" />
          </div>
          <div>
            <p className="font-bold text-gray-900 dark:text-white">Paramètres du compte</p>
            <p className="text-sm text-gray-500 dark:text-gray-400">{user?.email}</p>
          </div>
        </div>

        <div className="space-y-2">
          {items.map((item) => {
            const row = (
              <div className="bg-white dark:bg-gray-900 rounded-2xl p-4 flex items-center gap-3 shadow-sm border border-gray-100 dark:border-gray-800">
                <div className="w-10 h-10 bg-gray-100 dark:bg-gray-800 rounded-xl flex items-center justify-center">
                  <item.icon className="w-5 h-5 text-gray-600 dark:text-gray-300" />
                </div>
                <span className="font-medium text-gray-900 dark:text-white flex-1">{item.label}</span>
                {item.value ? (
                  <span className="text-sm text-gray-500 dark:text-gray-400">{item.value}</span>
                ) : (
                  <span className="text-gray-400" aria-hidden="true">›</span>
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
