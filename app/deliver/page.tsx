"use client";

import { useState, useEffect } from "react";
import { motion } from "framer-motion";
import { MapPin, Navigation } from "lucide-react";
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
    return <div className="min-h-screen bg-white" />;
  }

  if (!isDeliverer) {
    return (
      <div className="min-h-screen bg-white flex flex-col items-center justify-center px-8 text-center">
        <div className="text-7xl mb-6">🛵</div>
        <h1 className="text-2xl font-black text-gray-900 mb-2">Devenez livreur FAST</h1>
        <p className="text-gray-400 text-sm leading-relaxed mb-8 max-w-xs">
          Vous êtes près d'un restaurant ? Livrez des commandes autour de vous et gagnez de l'argent facilement.
        </p>

        <div className="w-full max-w-xs space-y-4 mb-10">
          {[
            { icon: "📍", title: "Restez géolocalisé", desc: "L'app détecte automatiquement les restaurants proches" },
            { icon: "⚡", title: "Livraison en 10 min", desc: "Uniquement les clients à moins de 10 minutes de vous" },
            { icon: "💰", title: "Gagnez de l'argent", desc: "Chaque livraison vous rapporte directement" },
          ].map((item) => (
            <div key={item.title} className="flex items-start gap-4 text-left bg-gray-50 rounded-2xl p-4">
              <span className="text-2xl">{item.icon}</span>
              <div>
                <p className="font-bold text-gray-800 text-sm">{item.title}</p>
                <p className="text-xs text-gray-400 mt-0.5">{item.desc}</p>
              </div>
            </div>
          ))}
        </div>

        <motion.button
          whileTap={{ scale: 0.96 }}
          onClick={handleBecomeDeliverer}
          className="w-full max-w-xs bg-gradient-to-r from-amber-400 to-orange-400 text-white font-black text-lg py-4 rounded-2xl shadow-lg shadow-amber-200"
        >
          Devenir livreur ⚡
        </motion.button>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-white px-5 pt-8 pb-24">
      {/* Header */}
      <div className="flex items-center justify-between mb-8">
        <div>
          <h1 className="text-2xl font-black text-gray-900">Mode livreur</h1>
          <p className="text-sm text-gray-400 mt-0.5">
            {isActive ? "Vous êtes visible pour les clients" : "Activez pour recevoir des livraisons"}
          </p>
        </div>
        <div className={`w-16 h-16 rounded-2xl flex items-center justify-center ${isActive ? "bg-emerald-100" : "bg-gray-100"}`}>
          <span className="text-3xl">🛵</span>
        </div>
      </div>

      {/* Toggle actif */}
      <motion.button
        whileTap={{ scale: 0.97 }}
        onClick={toggleActive}
        className={`w-full py-5 rounded-3xl font-black text-lg mb-8 transition-all duration-300 shadow-lg ${
          isActive
            ? "bg-gradient-to-r from-emerald-400 to-green-500 text-white shadow-emerald-200"
            : "bg-gradient-to-r from-amber-400 to-orange-400 text-white shadow-amber-200"
        }`}
      >
        {isActive ? "🟢 En ligne — Tap pour vous déconnecter" : "⚡ Me connecter comme livreur"}
      </motion.button>

      {isActive ? (
        <div className="space-y-4">
          {/* GPS simulé */}
          <div className="bg-gradient-to-br from-cyan-50 to-blue-50 rounded-3xl p-5 border border-cyan-100">
            <div className="flex items-center gap-3 mb-3">
              <Navigation className="w-5 h-5 text-cyan-500" />
              <p className="font-bold text-gray-800">GPS actif</p>
              <div className="ml-auto flex items-center gap-1.5">
                <div className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
                <span className="text-xs font-medium text-emerald-500">En direct</span>
              </div>
            </div>
            <p className="text-sm text-gray-500">Votre position est partagée avec les clients à proximité.</p>
          </div>

          {/* Stats */}
          <div className="grid grid-cols-3 gap-3">
            {[
              { label: "Livraisons", value: "0", icon: "📦" },
              { label: "Revenus", value: "0€", icon: "💰" },
              { label: "Note", value: "—", icon: "⭐" },
            ].map((s) => (
              <div key={s.label} className="bg-gray-50 rounded-2xl p-3 text-center">
                <div className="text-xl">{s.icon}</div>
                <div className="font-black text-gray-900 text-lg leading-none mt-1">{s.value}</div>
                <div className="text-[10px] text-gray-400 mt-0.5">{s.label}</div>
              </div>
            ))}
          </div>

          {/* En attente */}
          <div className="bg-gray-50 rounded-3xl p-6 text-center mt-2">
            <div className="text-4xl mb-3">🔍</div>
            <p className="font-bold text-gray-700">En attente de commandes</p>
            <p className="text-sm text-gray-400 mt-1">Vous recevrez une notification dès qu'une commande proche est disponible.</p>
          </div>
        </div>
      ) : (
        <div className="bg-gray-50 rounded-3xl p-6 text-center">
          <div className="text-4xl mb-3">💤</div>
          <p className="font-bold text-gray-700">Vous êtes hors ligne</p>
          <p className="text-sm text-gray-400 mt-1">Activez le mode livreur pour voir les commandes autour de vous.</p>
        </div>
      )}
    </div>
  );
}
