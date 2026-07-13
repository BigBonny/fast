"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/AuthContext";
import { ArrowLeft, MapPin, Plus, Home } from "lucide-react";
import Link from "next/link";

export default function AddressesPage() {
  const router = useRouter();
  const { isAuthenticated, user } = useAuth();

  useEffect(() => {
    if (!isAuthenticated) router.replace("/login");
  }, [isAuthenticated, router]);

  if (!isAuthenticated) return null;

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-gray-950 pb-20">
      <div className="bg-white dark:bg-gray-900 px-5 py-4 flex items-center gap-3 border-b border-gray-100 dark:border-gray-800 sticky top-0 z-20">
        <Link href="/profile" className="w-9 h-9 bg-gray-50 dark:bg-gray-800 rounded-xl flex items-center justify-center">
          <ArrowLeft className="w-4 h-4 text-gray-600 dark:text-gray-300" />
        </Link>
        <h1 className="font-bold text-gray-900 dark:text-white">Mes adresses</h1>
      </div>

      <div className="px-5 pt-5">
        <div className="bg-white dark:bg-gray-900 rounded-2xl p-4 flex items-center gap-4 shadow-sm border border-gray-100 dark:border-gray-800">
          <div className="w-12 h-12 bg-emerald-100 dark:bg-emerald-500/15 rounded-xl flex items-center justify-center">
            <Home className="w-6 h-6 text-emerald-600 dark:text-emerald-400" />
          </div>
          <div className="flex-1">
            <p className="font-bold text-gray-900 dark:text-white">Adresse principale</p>
            <p className="text-sm text-gray-500 dark:text-gray-400">{user?.email || "Non renseignée"}</p>
          </div>
          <span className="text-xs font-bold text-emerald-600 dark:text-emerald-400 bg-emerald-50 dark:bg-emerald-500/15 px-2 py-1 rounded-lg">Défaut</span>
        </div>
      </div>

      <div className="px-5 mt-4">
        <button className="w-full border-2 border-dashed border-gray-300 dark:border-gray-700 rounded-2xl p-4 flex items-center justify-center gap-2 text-gray-500 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-900 transition-colors">
          <Plus className="w-5 h-5" />
          <span className="font-medium">Ajouter une adresse</span>
        </button>
      </div>
    </div>
  );
}
