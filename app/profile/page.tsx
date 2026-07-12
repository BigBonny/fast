"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/AuthContext";
import { authApi } from "@/api/fastBackend";
import { ArrowLeft, User, MapPin, Moon, Bell, Shield, LogOut, Store, ShoppingBag, BarChart3, Settings, ChevronRight, Utensils, Phone, Save, X, CheckCircle, Star, Pencil, Zap } from "lucide-react";
import { m, AnimatePresence } from "framer-motion";
import Link from "next/link";

export default function ProfilePage() {
  const router = useRouter();
  const { user, isAuthenticated, logout, refreshUser } = useAuth();
  const [darkMode, setDarkMode] = useState(false);
  const [isEditing, setIsEditing] = useState(false);
  const [editName, setEditName] = useState("");
  const [editPhone, setEditPhone] = useState("");
  const [editLoading, setEditLoading] = useState(false);
  const [editError, setEditError] = useState("");
  const [editSuccess, setEditSuccess] = useState(false);

  useEffect(() => {
    if (!isAuthenticated) router.replace("/login");
  }, [isAuthenticated, router]);

  useEffect(() => {
    if (typeof window !== "undefined") {
      const saved = localStorage.getItem("fast_theme");
      const isDark = saved ? saved === "dark" : document.documentElement.classList.contains("dark");
      setDarkMode(isDark);
    }
  }, []);

  if (!isAuthenticated) return null;

  const handleLogout = () => { logout(); window.location.href = "/"; };
  const toggleDarkMode = () => { const next = !darkMode; setDarkMode(next); if (typeof window !== "undefined") { document.documentElement.classList.toggle("dark", next); localStorage.setItem("fast_theme", next ? "dark" : "light"); } };
  const openEdit = () => { setEditName(user?.name || ""); setEditPhone(user?.phone || ""); setEditError(""); setEditSuccess(false); setIsEditing(true); };
  const saveProfile = async (e: React.FormEvent) => { e.preventDefault(); setEditLoading(true); setEditError(""); setEditSuccess(false); try { await authApi.updateProfile({ name: editName, phone: editPhone }); await refreshUser(); setEditSuccess(true); setTimeout(() => { setEditSuccess(false); setIsEditing(false); }, 1200); } catch (err: any) { setEditError(err.message || "Erreur lors de la mise à jour"); } finally { setEditLoading(false); } };

  const isRestaurant = user?.role === "RESTAURANT";
  const roleLabel = isRestaurant ? "Restaurateur" : "Client";
  const roleColor = isRestaurant ? "bg-emerald-500" : "bg-violet-500";
  const clientMenu = [{ icon: User, label: "Informations personnelles", action: openEdit }, { icon: MapPin, label: "Mes adresses", action: () => router.push("/profile/addresses") }, { icon: Bell, label: "Notifications", action: () => router.push("/profile/notifications") }, { icon: Moon, label: "Mode sombre", action: toggleDarkMode, value: darkMode }, { icon: Shield, label: "Confidentialité", action: () => router.push("/privacy-policy") }];
  const restaurantMenu = [{ icon: Store, label: "Tableau de bord", action: () => router.push("/partner/orders"), highlight: true }, { icon: ShoppingBag, label: "Commandes restaurant", action: () => router.push("/partner/orders") }, { icon: BarChart3, label: "Statistiques", action: () => router.push("/partner/analytics") }, { icon: Settings, label: "Réglages restaurant", action: () => router.push("/partner/settings") }, { icon: Utensils, label: "Mon menu", action: () => router.push("/partner/menu") }, { icon: User, label: "Profil restaurant", action: () => router.push("/partner/analytics/profile") }, { icon: Shield, label: "Confidentialité", action: () => router.push("/privacy-policy") }];
  const menuItems = isRestaurant ? restaurantMenu : clientMenu;

  return (
    <div className={`min-h-screen pb-20 transition-colors ${darkMode ? "bg-gray-900" : "bg-gray-50"}`}>
      {/* Header */}
      <div className={`px-5 py-4 border-b sticky top-0 z-20 backdrop-blur-md ${darkMode ? "bg-gray-900/90 border-gray-800" : "bg-white/90 border-gray-100"}`}>
        <div className="max-w-2xl mx-auto flex items-center gap-3">
          <Link href="/" className={`w-9 h-9 rounded-xl flex items-center justify-center transition-colors ${darkMode ? "bg-gray-800 hover:bg-gray-700" : "bg-gray-50 hover:bg-gray-100"}`}><ArrowLeft className={`w-4 h-4 ${darkMode ? "text-gray-200" : "text-gray-600"}`} /></Link>
          <h1 className={`font-bold ${darkMode ? "text-white" : "text-gray-900"}`}>Mon compte</h1>
          <span className={`ml-auto px-2.5 py-1 rounded-full text-[10px] font-black text-white ${roleColor}`}>{roleLabel}</span>
        </div>
      </div>

      <div className="max-w-2xl mx-auto">
        {/* Hero card */}
        <div className="px-5 pt-5">
          <div className="rounded-3xl p-6 md:p-8 text-white relative overflow-hidden shadow-xl shadow-violet-500/20" style={{ background: "linear-gradient(135deg, #7c3aed 0%, #6d28d9 40%, #0891b2 100%)" }}>
            <div className="relative z-10 flex items-center gap-5">
              <div className="w-20 h-20 md:w-24 md:h-24 bg-white/15 backdrop-blur-sm border border-white/20 rounded-3xl flex items-center justify-center text-3xl md:text-4xl font-black shadow-lg shrink-0">{user?.name ? user.name[0].toUpperCase() : <User className="w-8 h-8" />}</div>
              <div className="min-w-0">
                <h2 className="text-xl md:text-2xl font-black truncate">{user?.name || "Mon compte"}</h2>
                <p className="text-white/70 text-sm truncate">{user?.email || ""}</p>
                {user?.phone && <p className="text-white/60 text-xs mt-0.5 flex items-center gap-1"><Phone className="w-3 h-3" />{user.phone}</p>}
                <button onClick={openEdit} className="mt-3 inline-flex items-center gap-1.5 text-xs font-bold bg-white/15 hover:bg-white/25 border border-white/20 rounded-full px-3 py-1.5 transition-colors">
                  <Pencil className="w-3 h-3" /> Modifier le profil
                </button>
              </div>
            </div>
            <div className="absolute -right-6 -bottom-10 w-40 h-40 bg-white/10 rounded-full blur-sm" />
            <div className="absolute -right-10 -top-10 w-28 h-28 bg-white/5 rounded-full" />
            <div className="absolute left-1/3 -bottom-14 w-32 h-32 bg-cyan-400/20 rounded-full blur-2xl" />
          </div>
        </div>

        {/* Stats row */}
        <div className="px-5 mt-4 grid grid-cols-2 gap-3">
          <div className={`rounded-2xl p-4 flex items-center gap-3 border transition-shadow hover:shadow-md ${darkMode ? "bg-gray-800 border-gray-700" : "bg-white border-gray-100 shadow-sm"}`}>
            <div className="w-11 h-11 rounded-xl bg-yellow-100 flex items-center justify-center shrink-0"><Star className="w-5 h-5 text-yellow-500 fill-yellow-400" /></div>
            <div className="min-w-0">
              <p className={`font-black text-lg leading-tight ${darkMode ? "text-white" : "text-gray-900"}`}>{user?.points ?? 85}</p>
              <p className="text-[11px] text-gray-400 font-semibold">Points FAST</p>
            </div>
          </div>
          <div className={`rounded-2xl p-4 flex items-center gap-3 border transition-shadow hover:shadow-md ${darkMode ? "bg-gray-800 border-gray-700" : "bg-white border-gray-100 shadow-sm"}`}>
            <div className={`w-11 h-11 rounded-xl flex items-center justify-center shrink-0 ${isRestaurant ? "bg-emerald-100" : "bg-violet-100"}`}>{isRestaurant ? <Store className="w-5 h-5 text-emerald-600" /> : <Zap className="w-5 h-5 text-violet-600 fill-violet-400" />}</div>
            <div className="min-w-0">
              <p className={`font-black text-lg leading-tight ${darkMode ? "text-white" : "text-gray-900"}`}>{roleLabel}</p>
              <p className="text-[11px] text-gray-400 font-semibold">{isRestaurant ? "Compte pro" : "Membre actif"}</p>
            </div>
          </div>
        </div>

        {isRestaurant && (
          <div className="px-5 mt-4">
            <Link href="/partner/orders">
              <m.div whileTap={{ scale: 0.98 }} whileHover={{ y: -2 }} className="w-full rounded-2xl p-4 flex items-center justify-between text-white shadow-lg shadow-teal-500/20" style={{ background: "linear-gradient(135deg, #00c8b3, #7c3aed)" }}>
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-xl bg-white/20 flex items-center justify-center"><Store className="w-5 h-5 text-white" /></div>
                  <div><p className="font-black text-sm">Accéder à l'Espace Pro</p><p className="text-white/80 text-xs">Commandes, menu, statistiques</p></div>
                </div>
                <ChevronRight className="w-5 h-5 text-white" />
              </m.div>
            </Link>
          </div>
        )}

        {/* Menu */}
        <div className="px-5 mt-6 space-y-2">
          <p className="text-xs font-bold text-gray-400 uppercase tracking-wider px-1 mb-3">{isRestaurant ? "Restaurant" : "Paramètres"}</p>
          <div className={`rounded-2xl overflow-hidden border divide-y ${darkMode ? "bg-gray-800 border-gray-700 divide-gray-700/60" : "bg-white border-gray-100 divide-gray-50 shadow-sm"}`}>
            {menuItems.map((item: any) => (
              <button key={item.label} onClick={item.action} className={`w-full p-4 flex items-center gap-3 transition-colors text-left cursor-pointer group ${darkMode ? "hover:bg-gray-700/50" : "hover:bg-gray-50"}`}>
                <div className={`w-10 h-10 rounded-xl flex items-center justify-center transition-transform group-hover:scale-105 ${item.highlight ? "bg-emerald-100" : darkMode ? "bg-gray-700" : "bg-gray-100"}`}><item.icon className={`w-5 h-5 ${item.highlight ? "text-emerald-600" : darkMode ? "text-gray-300" : "text-gray-600"}`} /></div>
                <span className={`font-semibold text-sm flex-1 ${item.highlight ? "text-emerald-600" : darkMode ? "text-gray-100" : "text-gray-900"}`}>{item.label}</span>
                {item.value !== undefined ? (
                  <div className={`w-10 h-6 rounded-full p-1 transition-colors ${item.value ? "bg-emerald-500" : darkMode ? "bg-gray-600" : "bg-gray-300"}`}><div className={`w-4 h-4 rounded-full bg-white shadow transition-transform ${item.value ? "translate-x-4" : "translate-x-0"}`} /></div>
                ) : (
                  <ChevronRight className="w-4 h-4 text-gray-300 group-hover:text-gray-500 group-hover:translate-x-0.5 transition-all" />
                )}
              </button>
            ))}
          </div>
        </div>
        <AnimatePresence>
        {isEditing && (
          <m.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: 20 }} className="px-5 mt-4">
            <div className={`rounded-2xl p-5 shadow-sm border ${darkMode ? "bg-gray-800 border-gray-700" : "bg-white border-gray-100"}`}>
              <div className="flex items-center justify-between mb-4">
                <h3 className={`font-bold ${darkMode ? "text-white" : "text-gray-900"}`}>Modifier le profil</h3>
                <button onClick={() => setIsEditing(false)} className={`w-8 h-8 rounded-lg flex items-center justify-center ${darkMode ? "bg-gray-700" : "bg-gray-100"}`}><X className={`w-4 h-4 ${darkMode ? "text-gray-300" : "text-gray-600"}`} /></button>
              </div>
              <form onSubmit={saveProfile} className="space-y-4">
                <div><label className={`block text-sm font-medium mb-1 ${darkMode ? "text-gray-300" : "text-gray-700"}`}>Nom</label><div className="relative"><User className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" /><input type="text" value={editName} onChange={(e) => setEditName(e.target.value)} className={`w-full pl-10 pr-4 py-3 rounded-xl border outline-none transition-all ${darkMode ? "bg-gray-900 border-gray-600 text-white focus:border-violet-400 focus:ring-2 focus:ring-violet-900" : "border-gray-200 focus:border-violet-500 focus:ring-2 focus:ring-violet-200"}`} placeholder="Votre nom" /></div></div>
                <div><label className={`block text-sm font-medium mb-1 ${darkMode ? "text-gray-300" : "text-gray-700"}`}>Téléphone</label><div className="relative"><Phone className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" /><input type="tel" value={editPhone} onChange={(e) => setEditPhone(e.target.value)} className={`w-full pl-10 pr-4 py-3 rounded-xl border outline-none transition-all ${darkMode ? "bg-gray-900 border-gray-600 text-white focus:border-violet-400 focus:ring-2 focus:ring-violet-900" : "border-gray-200 focus:border-violet-500 focus:ring-2 focus:ring-violet-200"}`} placeholder="Votre numéro" /></div></div>
                <div><label className={`block text-sm font-medium mb-1 ${darkMode ? "text-gray-300" : "text-gray-700"}`}>Email</label><input type="email" value={user?.email || ""} disabled className={`w-full px-4 py-3 rounded-xl border cursor-not-allowed ${darkMode ? "bg-gray-900 border-gray-600 text-gray-500" : "bg-gray-50 border-gray-200 text-gray-500"}`} /><p className="text-xs text-gray-400 mt-1">L'email ne peut pas être modifié.</p></div>
                {editError && <p className="text-sm text-red-500">{editError}</p>}
                {editSuccess && <div className="flex items-center gap-2 text-sm text-emerald-600"><CheckCircle className="w-4 h-4" />Profil mis à jour</div>}
                <m.button whileTap={{ scale: 0.98 }} type="submit" disabled={editLoading} className="w-full bg-violet-600 text-white rounded-xl py-3 font-bold flex items-center justify-center gap-2 disabled:opacity-50">{editLoading ? <span className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" /> : <Save className="w-5 h-5" />}{editLoading ? "Enregistrement..." : "Enregistrer"}</m.button>
              </form>
            </div>
          </m.div>
        )}
        </AnimatePresence>

        {/* Logout */}
        <div className="px-5 mt-6">
          <m.button whileTap={{ scale: 0.98 }} onClick={handleLogout} className={`w-full rounded-2xl p-4 flex items-center justify-center gap-2.5 font-bold text-sm border transition-colors ${darkMode ? "bg-red-500/10 border-red-500/20 text-red-400 hover:bg-red-500/20" : "bg-red-50 border-red-100 text-red-500 hover:bg-red-100"}`}>
            <LogOut className="w-4 h-4" />
            Se déconnecter
          </m.button>
          <p className="text-center text-[11px] text-gray-400 mt-4 font-medium">FAST — Chaque minute compte</p>
        </div>
      </div>
    </div>
  );
}
