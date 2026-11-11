"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/AuthContext";
import { useTheme } from "@/lib/useTheme";
import { authApi, getErrorMessage } from "@/api/fastBackend";
import { ArrowLeft, User, MapPin, Moon, Bell, Shield, LogOut, Store, ShoppingBag, BarChart3, Settings, ChevronRight, Utensils, Phone, Save, X, CheckCircle, Star, Pencil, Zap } from "lucide-react";
import { m, AnimatePresence } from "framer-motion";
import Link from "next/link";

export default function ProfilePage() {
  const router = useRouter();
  const { user, isAuthenticated, logout, refreshUser } = useAuth();
  const { isDark: darkMode, toggleTheme } = useTheme();
  const [isEditing, setIsEditing] = useState(false);
  const [editName, setEditName] = useState("");
  const [editPhone, setEditPhone] = useState("");
  const [editLoading, setEditLoading] = useState(false);
  const [editError, setEditError] = useState("");
  const [editSuccess, setEditSuccess] = useState(false);

  useEffect(() => {
    if (!isAuthenticated) router.replace("/login");
  }, [isAuthenticated, router]);

  if (!isAuthenticated) return null;

  const handleLogout = () => { void logout(true); };
  const openEdit = () => { setEditName(user?.name || ""); setEditPhone(user?.phone || ""); setEditError(""); setEditSuccess(false); setIsEditing(true); };
  const saveProfile = async (e: React.FormEvent) => { e.preventDefault(); setEditLoading(true); setEditError(""); setEditSuccess(false); try { await authApi.updateProfile({ name: editName, phone: editPhone }); await refreshUser(); setEditSuccess(true); setTimeout(() => { setEditSuccess(false); setIsEditing(false); }, 1200); } catch (err) { setEditError(getErrorMessage(err, "Erreur lors de la mise à jour")); } finally { setEditLoading(false); } };

  const isRestaurant = user?.role === "RESTAURANT";
  const roleLabel = isRestaurant ? "Restaurateur" : "Client";

  const clientMenu = [{ icon: User, label: "Informations personnelles", action: openEdit }, { icon: MapPin, label: "Mes adresses", action: () => router.push("/profile/addresses") }, { icon: Bell, label: "Notifications", action: () => router.push("/profile/notifications") }, { icon: Moon, label: "Mode sombre", action: toggleTheme, value: darkMode }, { icon: Shield, label: "Confidentialité", action: () => router.push("/privacy-policy") }];
  const restaurantMenu = [{ icon: Store, label: "Tableau de bord", action: () => router.push("/partner/orders"), highlight: true }, { icon: ShoppingBag, label: "Commandes restaurant", action: () => router.push("/partner/orders") }, { icon: BarChart3, label: "Statistiques", action: () => router.push("/partner/analytics") }, { icon: Settings, label: "Réglages restaurant", action: () => router.push("/partner/settings") }, { icon: Utensils, label: "Mon menu", action: () => router.push("/partner/menu") }, { icon: User, label: "Profil restaurant", action: () => router.push("/partner/analytics/profile") }, { icon: Shield, label: "Confidentialité", action: () => router.push("/privacy-policy") }];
  const menuItems = isRestaurant ? restaurantMenu : clientMenu;

  return (
    <div className="min-h-screen pb-24 bg-background">
      {/* Header */}
      <div className="px-4 sm:px-6 py-3 border-b border-border sticky top-0 z-20 backdrop-blur-md bg-background/90">
        <div className="max-w-2xl mx-auto flex items-center gap-3">
          <Link href="/" className="w-11 h-11 rounded-full border border-border bg-card flex items-center justify-center hover:bg-muted transition-colors shrink-0"><ArrowLeft className="w-5 h-5 text-foreground" /></Link>
          <h1 className="font-display font-bold text-xl text-foreground">Mon compte</h1>
        </div>
      </div>

      <div className="max-w-2xl mx-auto">
        {/* Membership card */}
        <div className="px-4 sm:px-6 pt-6">
          <div className="night-surface p-6 md:p-8">
            <div className="flex items-start justify-between gap-3">
              <span className="text-xs font-bold tracking-wide uppercase on-night-muted">{roleLabel}</span>
              <span className="inline-flex items-center gap-1.5 rounded-full bg-fast-gold px-3 py-1 text-xs font-bold text-fast-ink tabular-nums shrink-0">
                <Star className="w-3.5 h-3.5 fill-current" />
                {user?.points ?? 0}
              </span>
            </div>
            <div className="flex items-center gap-4 mt-4">
              <div className="w-16 h-16 bg-white/10 border border-white/15 rounded-full flex items-center justify-center text-2xl font-display font-bold shrink-0">{user?.name ? user.name[0].toUpperCase() : <User className="w-7 h-7" />}</div>
              <div className="min-w-0">
                <h2 className="font-display text-2xl md:text-3xl font-extrabold truncate leading-tight">{user?.name || "Mon compte"}</h2>
                <p className="on-night-muted text-sm truncate">{user?.email || ""}</p>
                {user?.phone && <p className="on-night-muted text-xs mt-0.5 flex items-center gap-1 tabular-nums"><Phone className="w-3 h-3" />{user.phone}</p>}
              </div>
            </div>

            {/* Stats row */}
            <div className="grid grid-cols-2 gap-3 mt-6 pt-5 border-t border-white/10">
              <div className="min-w-0">
                <p className="font-extrabold text-xl leading-tight tabular-nums">{user?.points ?? 0}</p>
                <p className="text-xs on-night-muted font-semibold mt-0.5">Points <span className="notranslate" translate="no">FAST</span></p>
              </div>
              <div className="min-w-0 flex items-start gap-2">
                {isRestaurant ? <Store className="w-4 h-4 mt-1 text-fast-gold shrink-0" /> : <Zap className="w-4 h-4 mt-1 text-fast-gold fill-fast-gold shrink-0" />}
                <div className="min-w-0">
                  <p className="font-extrabold text-xl leading-tight truncate">{roleLabel}</p>
                  <p className="text-xs on-night-muted font-semibold mt-0.5">{isRestaurant ? "Compte pro" : "Membre actif"}</p>
                </div>
              </div>
            </div>

            <button onClick={openEdit} className="mt-5 min-h-[44px] inline-flex items-center gap-2 text-sm font-bold bg-white/10 hover:bg-white/20 border border-white/20 rounded-full px-4 transition-colors">
              <Pencil className="w-3.5 h-3.5" /> Modifier le profil
            </button>
          </div>
        </div>

        {isRestaurant && (
          <div className="px-4 sm:px-6 mt-4">
            <Link href="/partner/orders" className="block">
              <m.div whileTap={{ scale: 0.98 }} whileHover={{ y: -2 }} className="w-full rounded-2xl p-4 flex items-center justify-between gap-3 bg-card border border-border text-foreground">
                <div className="flex items-center gap-3 min-w-0">
                  <div className="w-11 h-11 rounded-full bg-fast-rose/10 flex items-center justify-center shrink-0"><Store className="w-5 h-5 text-fast-rose" /></div>
                  <div className="min-w-0"><p className="font-bold text-sm">Accéder à l'Espace Pro</p><p className="text-muted-foreground text-xs">Commandes, menu, statistiques</p></div>
                </div>
                <ChevronRight className="w-5 h-5 text-muted-foreground shrink-0" />
              </m.div>
            </Link>
          </div>
        )}

        {/* Menu */}
        <div className="px-4 sm:px-6 mt-10">
          <p className="text-xs font-bold text-muted-foreground uppercase tracking-wide mb-2">{isRestaurant ? "Restaurant" : "Paramètres"}</p>
          <div className="border-y border-border divide-y divide-border">
            {menuItems.map((item: any) => (
              <button key={item.label} onClick={item.action} className="w-full py-3.5 min-h-[56px] flex items-center gap-3 transition-colors text-left cursor-pointer group hover:bg-muted/60">
                <item.icon className={`w-5 h-5 shrink-0 ${item.highlight ? "text-fast-rose" : "text-muted-foreground"}`} />
                <span className={`text-sm flex-1 ${item.highlight ? "font-bold text-fast-rose" : "font-semibold text-foreground"}`}>{item.label}</span>
                {item.value !== undefined ? (
                  <div className={`w-11 h-6 rounded-full p-1 transition-colors shrink-0 ${item.value ? "bg-primary" : "bg-muted-foreground/30"}`}><div className={`w-4 h-4 rounded-full bg-white shadow transition-transform ${item.value ? "translate-x-5" : "translate-x-0"}`} /></div>
                ) : (
                  <ChevronRight className="w-4 h-4 text-muted-foreground group-hover:translate-x-0.5 transition-transform shrink-0" />
                )}
              </button>
            ))}
          </div>
        </div>
        <AnimatePresence>
        {isEditing && (
          <m.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: 20 }} className="px-4 sm:px-6 mt-6">
            <div className="rounded-2xl p-5 border border-border bg-card">
              <div className="flex items-center justify-between mb-4">
                <h3 className="font-display font-bold text-xl text-foreground">Modifier le profil</h3>
                <button onClick={() => setIsEditing(false)} className="w-11 h-11 rounded-full border border-border flex items-center justify-center hover:bg-muted transition-colors"><X className="w-4 h-4 text-foreground" /></button>
              </div>
              <form onSubmit={saveProfile} className="space-y-4">
                <div><label className="block text-sm font-semibold mb-1.5 text-foreground">Nom</label><div className="relative"><User className="absolute left-3.5 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground" /><input type="text" value={editName} onChange={(e) => setEditName(e.target.value)} className="w-full pl-11 pr-4 py-3 rounded-xl border border-border bg-background text-foreground placeholder:text-muted-foreground outline-none transition-all focus:border-fast-rose focus:ring-2 focus:ring-fast-rose/25" placeholder="Votre nom" /></div></div>
                <div><label className="block text-sm font-semibold mb-1.5 text-foreground">Téléphone</label><div className="relative"><Phone className="absolute left-3.5 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground" /><input type="tel" value={editPhone} onChange={(e) => setEditPhone(e.target.value)} className="w-full pl-11 pr-4 py-3 rounded-xl border border-border bg-background text-foreground placeholder:text-muted-foreground outline-none transition-all focus:border-fast-rose focus:ring-2 focus:ring-fast-rose/25" placeholder="Votre numéro" /></div></div>
                <div><label className="block text-sm font-semibold mb-1.5 text-foreground">Email</label><input type="email" value={user?.email || ""} disabled className="w-full px-4 py-3 rounded-xl border border-border bg-muted text-muted-foreground cursor-not-allowed" /><p className="text-xs text-muted-foreground mt-1.5">L'email ne peut pas être modifié.</p></div>
                {editError && <p className="text-sm text-red-600 dark:text-red-400">{editError}</p>}
                {editSuccess && <div className="flex items-center gap-2 text-sm text-emerald-700 dark:text-emerald-400"><CheckCircle className="w-4 h-4" />Profil mis à jour</div>}
                <m.button whileTap={{ scale: 0.98 }} type="submit" disabled={editLoading} className="btn-neon w-full">{editLoading ? <span className="w-5 h-5 border-2 border-fast-ink/30 border-t-fast-ink rounded-full animate-spin" /> : <Save className="w-5 h-5" />}{editLoading ? "Enregistrement..." : "Enregistrer"}</m.button>
              </form>
            </div>
          </m.div>
        )}
        </AnimatePresence>

        {/* Logout */}
        <div className="px-4 sm:px-6 mt-10">
          <m.button whileTap={{ scale: 0.98 }} onClick={handleLogout} className="w-full min-h-[48px] rounded-full px-5 flex items-center justify-center gap-2.5 font-bold text-sm border border-red-500/40 text-red-600 dark:text-red-400 hover:bg-red-500/10 transition-colors">
            <LogOut className="w-4 h-4" />
            Se déconnecter
          </m.button>
          <p className="text-center text-xs text-muted-foreground mt-5 font-medium"><span className="notranslate" translate="no">FAST</span> — Chaque minute compte</p>
        </div>
      </div>
    </div>
  );
}
