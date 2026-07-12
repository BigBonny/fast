"use client";

import { useState, useEffect, Suspense } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { motion } from "framer-motion";
import { Eye, EyeOff, Mail, Lock, User, ArrowLeft, Phone, Zap, Store, ShoppingBag } from "lucide-react";
import Link from "next/link";
import { useAuth } from "@/lib/AuthContext";

function RoleInitializer({ onRole }: { onRole: (role: "RESTAURANT") => void }) {
  const searchParams = useSearchParams();
  useEffect(() => {
    if (searchParams.get("role") === "restaurant") {
      onRole("RESTAURANT");
    }
  }, [searchParams, onRole]);
  return null;
}

export default function RegisterPage() {
  const router = useRouter();
  const { register, isLoadingAuth } = useAuth();
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [phone, setPhone] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [role, setRole] = useState<"CLIENT" | "RESTAURANT">("CLIENT");
  const [error, setError] = useState("");

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    try {
      const currentUser = await register({ name, email, password, phone, role });
      const destination = currentUser?.role === "RESTAURANT" ? "/partner/onboarding" : "/";
      router.replace(destination);
    } catch (err: any) {
      setError(err.message || "Erreur lors de l'inscription");
    }
  };

  return (
    <div className="min-h-screen flex" style={{ background: "#020617" }}>
      {/* Desktop branding panel */}
      <div className="hidden lg:flex flex-col justify-between w-[45%] relative overflow-hidden p-12"
        style={{ background: "linear-gradient(160deg, #1a0533 0%, #0a1628 60%, #020617 100%)" }}>
        <div className="absolute inset-0 pointer-events-none">
          <div className="absolute w-[420px] h-[420px] -top-24 -left-24 rounded-full blur-3xl opacity-25" style={{ background: "radial-gradient(circle, #7c3aed, transparent)" }} />
          <div className="absolute w-[360px] h-[360px] -bottom-20 -right-20 rounded-full blur-3xl opacity-20" style={{ background: "radial-gradient(circle, #06b6d4, transparent)" }} />
        </div>
        <div className="relative z-10 flex items-center gap-1.5">
          <Zap className="w-7 h-7 text-amber-400 fill-amber-400" />
          <span className="font-black text-3xl italic tracking-tight" style={{
            background: "linear-gradient(90deg, #f59e0b, #fbbf24, #f97316)",
            WebkitBackgroundClip: "text",
            WebkitTextFillColor: "transparent",
          }}>FAST</span>
        </div>
        <div className="relative z-10">
          <h2 className="text-4xl font-black text-white leading-tight mb-4">
            Rejoins la<br />communauté.
          </h2>
          <p className="text-gray-400 text-base max-w-sm">
            Client ou restaurateur, crée ton compte en quelques secondes et gagne du temps à chaque commande.
          </p>
        </div>
        <p className="relative z-10 text-gray-600 text-xs">© {new Date().getFullYear()} FAST</p>
      </div>

      {/* Form side */}
      <div className="flex-1 flex flex-col">
      <div className="px-5 py-4">
        <Link href="/" className="w-10 h-10 rounded-xl bg-white/5 flex items-center justify-center hover:bg-white/10 transition-colors">
          <ArrowLeft className="w-5 h-5 text-white" />
        </Link>
      </div>

      <div className="flex-1 flex flex-col items-center justify-center px-6 pb-12">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="w-full max-w-sm"
        >
          <div className="text-center mb-8">
            <div className="w-14 h-14 mx-auto mb-3 rounded-2xl bg-gradient-to-br from-amber-400 to-orange-500 flex items-center justify-center">
              <Zap className="w-7 h-7 text-white fill-white" />
            </div>
            <h1 className="font-black text-3xl italic tracking-tight text-white">FAST</h1>
            <p className="text-gray-400 text-sm mt-2">Crée ton compte</p>
          </div>

          <Suspense fallback={null}>
            <RoleInitializer onRole={setRole} />
          </Suspense>

          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="grid grid-cols-2 gap-3 p-1 rounded-2xl bg-white/5 border border-white/10">
              <button
                type="button"
                onClick={() => setRole("CLIENT")}
                className={`flex items-center justify-center gap-2 py-2.5 rounded-xl text-sm font-bold transition-all ${role === "CLIENT" ? "bg-emerald-500 text-white shadow-lg shadow-emerald-500/25" : "text-gray-400 hover:text-white"}`}
              >
                <ShoppingBag className="w-4 h-4" /> Client
              </button>
              <button
                type="button"
                onClick={() => setRole("RESTAURANT")}
                className={`flex items-center justify-center gap-2 py-2.5 rounded-xl text-sm font-bold transition-all ${role === "RESTAURANT" ? "bg-violet-500 text-white shadow-lg shadow-violet-500/25" : "text-gray-400 hover:text-white"}`}
              >
                <Store className="w-4 h-4" /> Restaurateur
              </button>
            </div>

            {role === "RESTAURANT" && (
              <div className="p-3 rounded-xl bg-violet-500/10 border border-violet-500/20 text-violet-300 text-xs text-center">
                Après l'inscription, vous pourrez créer la fiche de votre restaurant.
              </div>
            )}

            <div className="relative">
              <User className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
              <input
                type="text"
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="Nom complet"
                required
                className="w-full h-14 pl-12 pr-4 rounded-2xl bg-white/5 border border-white/10 text-white placeholder-gray-500 focus:outline-none focus:border-emerald-500"
              />
            </div>

            <div className="relative">
              <Mail className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="Email"
                required
                className="w-full h-14 pl-12 pr-4 rounded-2xl bg-white/5 border border-white/10 text-white placeholder-gray-500 focus:outline-none focus:border-emerald-500"
              />
            </div>

            <div className="relative">
              <Phone className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
              <input
                type="tel"
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
                placeholder="Téléphone (optionnel)"
                className="w-full h-14 pl-12 pr-4 rounded-2xl bg-white/5 border border-white/10 text-white placeholder-gray-500 focus:outline-none focus:border-emerald-500"
              />
            </div>

            <div className="relative">
              <Lock className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
              <input
                type={showPassword ? "text" : "password"}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="Mot de passe"
                required
                minLength={8}
                pattern="(?=.*[A-Z])(?=.*[0-9]).{8,}"
                title="8 caractères minimum, 1 majuscule et 1 chiffre"
                className="w-full h-14 pl-12 pr-12 rounded-2xl bg-white/5 border border-white/10 text-white placeholder-gray-500 focus:outline-none focus:border-emerald-500"
              />
              <button
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                className="absolute right-4 top-1/2 -translate-y-1/2 text-gray-400"
              >
                {showPassword ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
              </button>
            </div>
            <p className="text-[11px] text-slate-500">8 caractères minimum, 1 majuscule et 1 chiffre.</p>

            {error && (
              <div className="p-3 rounded-xl bg-red-500/10 text-red-400 text-sm text-center">
                {error}
              </div>
            )}

            <motion.button
              whileTap={{ scale: 0.98 }}
              type="submit"
              disabled={isLoadingAuth}
              className="w-full h-14 rounded-2xl bg-gradient-to-r from-emerald-500 to-cyan-500 text-white font-black text-lg disabled:opacity-50"
            >
              {isLoadingAuth ? "Inscription..." : role === "RESTAURANT" ? "S'inscrire comme restaurateur" : "S'inscrire"}
            </motion.button>
          </form>

          <div className="mt-6 text-center space-y-2">
            <p className="text-gray-400 text-sm">
              Déjà un compte ?{" "}
              <Link href="/login" className="text-emerald-400 font-bold">
                Se connecter
              </Link>
            </p>
          </div>
        </motion.div>
      </div>
      </div>
    </div>
  );
}
