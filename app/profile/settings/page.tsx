"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/AuthContext";
import { ArrowLeft, Settings, Globe, Lock, HelpCircle } from "lucide-react";
import Link from "next/link";

export default function SettingsPage() {
  const router = useRouter();
  const { isAuthenticated, user } = useAuth();

  useEffect(() => {
    if (!isAuthenticated) router.replace("/login");
  }, [isAuthenticated, router]);

  if (!isAuthenticated) return null;

  const items = [
    { icon: Globe, label: "Langue", value: "Français" },
    { icon: Lock, label: "Changer le mot de passe", href: "#" },
    { icon: HelpCircle, label: "Aide & support", href: "#" },
  ];

  return (
    <div className="min-h-screen bg-gray-50 pb-20">
      <div className="bg-white px-5 py-4 flex items-center gap-3 border-b border-gray-100 sticky top-0 z-20">
        <Link href="/profile" className="w-9 h-9 bg-gray-50 rounded-xl flex items-center justify-center">
          <ArrowLeft className="w-4 h-4 text-gray-600" />
        </Link>
        <h1 className="font-bold text-gray-900">Paramètres</h1>
      </div>

      <div className="px-5 pt-5">
        <div className="bg-white rounded-2xl p-4 flex items-center gap-4 shadow-sm border border-gray-100 mb-4">
          <div className="w-12 h-12 bg-cyan-100 rounded-xl flex items-center justify-center">
            <Settings className="w-6 h-6 text-cyan-600" />
          </div>
          <div>
            <p className="font-bold text-gray-900">Paramètres du compte</p>
            <p className="text-sm text-gray-500">{user?.email}</p>
          </div>
        </div>

        <div className="space-y-2">
          {items.map((item) => (
            <div key={item.label} className="bg-white rounded-2xl p-4 flex items-center gap-3 shadow-sm border border-gray-100">
              <div className="w-10 h-10 bg-gray-100 rounded-xl flex items-center justify-center">
                <item.icon className="w-5 h-5 text-gray-600" />
              </div>
              <span className="font-medium text-gray-900 flex-1">{item.label}</span>
              {item.value ? (
                <span className="text-sm text-gray-500">{item.value}</span>
              ) : (
                <span className="text-gray-400">›</span>
              )}
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
