"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/AuthContext";
import { ArrowLeft, Bell, Package, Tag, Info } from "lucide-react";
import Link from "next/link";

export default function NotificationsPage() {
  const router = useRouter();
  const { isAuthenticated } = useAuth();

  useEffect(() => {
    if (!isAuthenticated) router.replace("/login");
  }, [isAuthenticated, router]);

  if (!isAuthenticated) return null;

  const options = [
    { icon: Package, label: "Statut des commandes", desc: "Recevoir des notifications sur mes commandes", value: true },
    { icon: Tag, label: "Promotions", desc: "Offres et réductions personnalisées", value: false },
    { icon: Info, label: "Actualités FAST", desc: "Nouvelles fonctionnalités et mises à jour", value: true },
  ];

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-gray-950 pb-20">
      <div className="bg-white dark:bg-gray-900 px-5 py-4 flex items-center gap-3 border-b border-gray-100 dark:border-gray-800 sticky top-0 z-20">
        <Link href="/profile" className="w-9 h-9 bg-gray-50 dark:bg-gray-800 rounded-xl flex items-center justify-center">
          <ArrowLeft className="w-4 h-4 text-gray-600 dark:text-gray-300" />
        </Link>
        <h1 className="font-bold text-gray-900 dark:text-white">Notifications</h1>
      </div>

      <div className="px-5 pt-5">
        <div className="bg-white dark:bg-gray-900 rounded-2xl p-4 flex items-center gap-4 shadow-sm border border-gray-100 dark:border-gray-800 mb-4">
          <div className="w-12 h-12 bg-violet-100 dark:bg-violet-500/15 rounded-xl flex items-center justify-center">
            <Bell className="w-6 h-6 text-violet-600 dark:text-violet-400" />
          </div>
          <div>
            <p className="font-bold text-gray-900 dark:text-white">Notifications push</p>
            <p className="text-sm text-gray-500 dark:text-gray-400">Activer les notifications</p>
          </div>
        </div>

        <div className="space-y-2">
          {options.map((opt) => (
            <div key={opt.label} className="bg-white dark:bg-gray-900 rounded-2xl p-4 flex items-center gap-3 shadow-sm border border-gray-100 dark:border-gray-800">
              <div className="w-10 h-10 bg-gray-100 dark:bg-gray-800 rounded-xl flex items-center justify-center">
                <opt.icon className="w-5 h-5 text-gray-600 dark:text-gray-300" />
              </div>
              <div className="flex-1">
                <p className="font-medium text-gray-900 dark:text-white">{opt.label}</p>
                <p className="text-xs text-gray-400">{opt.desc}</p>
              </div>
              <div className={`w-10 h-6 rounded-full p-1 transition-colors ${opt.value ? "bg-emerald-500" : "bg-gray-300 dark:bg-gray-600"}`}>
                <div className={`w-4 h-4 rounded-full bg-white transition-transform ${opt.value ? "translate-x-4" : "translate-x-0"}`} />
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
