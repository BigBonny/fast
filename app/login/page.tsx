"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { motion } from "framer-motion";
import { Eye, EyeOff, Mail, Lock, ArrowLeft, Store } from "lucide-react";
import Link from "next/link";
import { useAuth } from "@/lib/AuthContext";

export default function LoginPage() {
  const router = useRouter();
  const { login, isLoadingAuth } = useAuth();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState("");

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    try {
      const currentUser = await login(email, password);
      const destination = currentUser?.role === "RESTAURANT" ? "/partner/orders" : "/";
      router.replace(destination);
    } catch (err: any) {
      setError(err.message || "Email ou mot de passe incorrect");
    }
  };

  return (
    <div className="min-h-screen flex flex-col" style={{ background: "#020617" }}>
      {/* Header */}
      <div className="px-5 py-4 flex items-center justify-between">
        <Link href="/" className="w-10 h-10 rounded-xl bg-white/5 flex items-center justify-center">
          <ArrowLeft className="w-5 h-5 text-white" />
        </Link>
        <Link
          href="/partner"
          className="flex items-center gap-2 px-4 py-2 rounded-xl bg-gradient-to-r from-emerald-500 to-violet-600 text-white text-sm font-bold"
        >
          <Store className="w-4 h-4" />
          Espace Restaurateur
        </Link>
      </div>

      <div className="flex-1 flex flex-col items-center justify-center px-6 pb-12">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="w-full max-w-sm"
        >
          {/* Logo */}
          <div className="text-center mb-8">
            <div className="text-4xl mb-3">⚡</div>
            <h1 className="font-black text-3xl italic tracking-tight text-white">
              FAST
            </h1>
            <p className="text-gray-400 text-sm mt-2">Connecte-toi pour commander</p>
          </div>

          <form onSubmit={handleSubmit} className="space-y-4">
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
              <Lock className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
              <input
                type={showPassword ? "text" : "password"}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="Mot de passe"
                required
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
              {isLoadingAuth ? "Connexion..." : "Se connecter"}
            </motion.button>
          </form>

          <div className="mt-6 text-center">
            <p className="text-gray-400 text-sm">
              Pas encore de compte ?{" "}
              <Link href="/register" className="text-emerald-400 font-bold">
                S'inscrire
              </Link>
            </p>
          </div>

          <div className="mt-8 p-4 rounded-2xl bg-white/5 border border-white/10">
            <p className="text-gray-400 text-xs text-center mb-3">Comptes de démo — cliquer pour remplir</p>
            <div className="space-y-2">
              <button
                type="button"
                onClick={() => { setEmail("client@fast.demo"); setPassword("Demo1234"); }}
                className="w-full flex items-center justify-between px-3 py-2.5 rounded-xl bg-emerald-500/10 border border-emerald-500/20 hover:bg-emerald-500/20 transition-all"
              >
                <div className="text-left">
                  <p className="text-xs font-bold text-emerald-400">👤 Compte Client</p>
                  <p className="text-[11px] text-gray-400">client@fast.demo</p>
                </div>
                <span className="text-[10px] text-gray-500 font-mono">Demo1234</span>
              </button>
              <button
                type="button"
                onClick={() => { setEmail("resto@fast.demo"); setPassword("Demo1234"); }}
                className="w-full flex items-center justify-between px-3 py-2.5 rounded-xl bg-violet-500/10 border border-violet-500/20 hover:bg-violet-500/20 transition-all"
              >
                <div className="text-left">
                  <p className="text-xs font-bold text-violet-400">🏪 Compte Restaurateur</p>
                  <p className="text-[11px] text-gray-400">resto@fast.demo</p>
                </div>
                <span className="text-[10px] text-gray-500 font-mono">Demo1234</span>
              </button>
            </div>
          </div>
        </motion.div>
      </div>
    </div>
  );
}
