"use client";

import { useState, useEffect } from "react";
import { m } from "framer-motion";
import { MapPin, Navigation, Bike, Zap, Wallet, Package, Star, Search, Moon } from "lucide-react";
import { authApi } from "@/api/fastBackend";

export default function DeliverPage() {
  const [isActive, setIsActive] = useState(false);
  const [user, setUser] = useState<any>(null);
  const [isDeliverer, setIsDeliverer] = useState(false);
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
    if (typeof window !== "undefined") {
      authApi.me().then((u: any) => {
        setUser(u);
        setIsDeliverer(u?.role === "ADMIN" || u?.role === "DELIVERER" || false);
      }).catch(() => {});
    }
  }, []);

  const handleBecomeDeliverer = async () => {
    await authApi.updateProfile({ name: user?.name });
    setIsDeliverer(true);
  };

  const toggleActive = () => {
    setIsActive(!isActive);
  };

  if (!mounted) {
    return <div className="min-h-screen bg-white dark:bg-gray-950" />;
  }

  if (!isDeliverer) {
    return (
      <div className="min-h-screen bg-white dark:bg-gray-950 flex flex-col items-center justify-center px-8 text-center">
        <div className="w-24 h-24 rounded-3xl bg-gradient-to-br from-amber-100 to-orange-100 dark:from-amber-500/15 dark:to-orange-500/15 flex items-center justify-center mb-6">
          <Bike className="w-12 h-12 text-orange-500" />
        </div>
        <h1 className="text-2xl font-black text-gray-900 dark:text-white mb-2">Devenez livreur FAST</h1>
        <p className="text-gray-400 text-sm leading-relaxed mb-8 max-w-xs">
          Vous êtes près d'un restaurant ? Livrez des commandes autour de vous et gagnez de l'argent facilement.
        </p>

        <div className="w-full max-w-xs space-y-4 mb-10">
          {[
            { Icon: MapPin, color: "text-red-500 bg-red-50", title: "Restez géolocalisé", desc: "L'app détecte automatiquement les restaurants proches" },
            { Icon: Zap, color: "text-amber-500 bg-amber-50", title: "Livraison en 10 min", desc: "Uniquement les clients à moins de 10 minutes de vous" },
            { Icon: Wallet, color: "text-emerald-500 bg-emerald-50", title: "Gagnez de l'argent", desc: "Chaque livraison vous rapporte directement" },
          ].map((item) => (
            <div key={item.title} className="flex items-start gap-4 text-left bg-gray-50 dark:bg-gray-900 rounded-2xl p-4">
              <span className={`w-10 h-10 rounded-xl flex items-center justify-center shrink-0 ${item.color}`}><item.Icon className="w-5 h-5" /></span>
              <div>
                <p className="font-bold text-gray-800 dark:text-gray-100 text-sm">{item.title}</p>
                <p className="text-xs text-gray-400 mt-0.5">{item.desc}</p>
              </div>
            </div>
          ))}
        </div>

        <m.button
          whileTap={{ scale: 0.96 }}
          onClick={handleBecomeDeliverer}
          className="w-full max-w-xs bg-gradient-to-r from-amber-400 to-orange-400 text-white font-black text-lg py-4 rounded-2xl shadow-lg shadow-amber-200"
        >
          <span className="inline-flex items-center gap-2">Devenir livreur <Zap className="w-5 h-5 fill-white" /></span>
        </m.button>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-white dark:bg-gray-950 px-5 pt-8 pb-24 max-w-2xl mx-auto">
      {/* Header */}
      <div className="flex items-center justify-between mb-8">
        <div>
          <h1 className="text-2xl font-black text-gray-900 dark:text-white">Mode livreur</h1>
          <p className="text-sm text-gray-400 mt-0.5">
            {isActive ? "Vous êtes visible pour les clients" : "Activez pour recevoir des livraisons"}
          </p>
        </div>
        <div className={`w-16 h-16 rounded-2xl flex items-center justify-center ${isActive ? "bg-emerald-100 dark:bg-emerald-500/15" : "bg-gray-100 dark:bg-gray-800"}`}>
          <Bike className={`w-8 h-8 ${isActive ? "text-emerald-500" : "text-gray-400"}`} />
        </div>
      </div>

      {/* Toggle actif */}
      <m.button
        whileTap={{ scale: 0.97 }}
        onClick={toggleActive}
        className={`w-full py-5 rounded-3xl font-black text-lg mb-8 transition-all duration-300 shadow-lg ${
          isActive
            ? "bg-gradient-to-r from-emerald-400 to-green-500 text-white shadow-emerald-200"
            : "bg-gradient-to-r from-amber-400 to-orange-400 text-white shadow-amber-200"
        }`}
      >
        <span className="inline-flex items-center justify-center gap-2">
          {isActive ? <><span className="w-2.5 h-2.5 rounded-full bg-white animate-pulse" /> En ligne — Tap pour vous déconnecter</> : <><Zap className="w-5 h-5 fill-white" /> Me connecter comme livreur</>}
        </span>
      </m.button>

      {isActive ? (
        <div className="space-y-4">
          {/* GPS simulé */}
          <div className="bg-gradient-to-br from-cyan-50 to-blue-50 dark:from-cyan-500/10 dark:to-blue-500/10 rounded-3xl p-5 border border-cyan-100 dark:border-cyan-500/20">
            <div className="flex items-center gap-3 mb-3">
              <Navigation className="w-5 h-5 text-cyan-500" />
              <p className="font-bold text-gray-800 dark:text-gray-100">GPS actif</p>
              <div className="ml-auto flex items-center gap-1.5">
                <div className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
                <span className="text-xs font-medium text-emerald-500">En direct</span>
              </div>
            </div>
            <p className="text-sm text-gray-500 dark:text-gray-400">Votre position est partagée avec les clients à proximité.</p>
          </div>

          {/* Stats */}
          <div className="grid grid-cols-3 gap-3">
            {[
              { label: "Livraisons", value: "0", Icon: Package, color: "text-violet-500" },
              { label: "Revenus", value: "0€", Icon: Wallet, color: "text-emerald-500" },
              { label: "Note", value: "—", Icon: Star, color: "text-amber-500" },
            ].map((s) => (
              <div key={s.label} className="bg-gray-50 dark:bg-gray-900 rounded-2xl p-3 text-center">
                <s.Icon className={`w-5 h-5 mx-auto ${s.color}`} />
                <div className="font-black text-gray-900 dark:text-white text-lg leading-none mt-1">{s.value}</div>
                <div className="text-[10px] text-gray-400 mt-0.5">{s.label}</div>
              </div>
            ))}
          </div>

          {/* En attente */}
          <div className="bg-gray-50 dark:bg-gray-900 rounded-3xl p-6 text-center mt-2">
            <Search className="w-10 h-10 text-gray-300 dark:text-gray-600 mx-auto mb-3" />
            <p className="font-bold text-gray-700 dark:text-gray-200">En attente de commandes</p>
            <p className="text-sm text-gray-400 mt-1">Vous recevrez une notification dès qu'une commande proche est disponible.</p>
          </div>
        </div>
      ) : (
        <div className="bg-gray-50 dark:bg-gray-900 rounded-3xl p-6 text-center">
          <Moon className="w-10 h-10 text-gray-300 dark:text-gray-600 mx-auto mb-3" />
          <p className="font-bold text-gray-700 dark:text-gray-200">Vous êtes hors ligne</p>
          <p className="text-sm text-gray-400 mt-1">Activez le mode livreur pour voir les commandes autour de vous.</p>
        </div>
      )}
    </div>
  );
}
