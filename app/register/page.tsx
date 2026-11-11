"use client";

import { useState, useEffect, Suspense } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { m } from "framer-motion";
import { Eye, EyeOff, Mail, Lock, User, ArrowLeft, Phone, Zap, Store, ShoppingBag } from "lucide-react";
import Link from "next/link";
import { useAuth } from "@/lib/AuthContext";
import GoogleSignInButton from "@/components/GoogleSignInButton";

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
  const { register, googleLogin, isLoadingAuth } = useAuth();
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

  const handleGoogle = async (idToken: string) => {
    setError("");
    try {
      const currentUser = await googleLogin(idToken, role);
      const destination = currentUser?.role === "RESTAURANT" ? "/partner/onboarding" : "/";
      router.replace(destination);
    } catch (err: any) {
      setError(err.message || "Connexion Google impossible. Réessayez.");
    }
  };

  return (
    <div className="min-h-screen flex bg-background">
      {/* Desktop branding panel */}
      <div className="night-band hidden lg:flex flex-col justify-between w-[45%] relative overflow-hidden p-12">
        <div className="relative z-10 flex items-center gap-1.5">
          <Zap className="w-7 h-7 text-fast-gold fill-fast-gold" />
          <span className="text-neon font-black text-3xl italic tracking-tight"><span className="notranslate" translate="no">FAST</span></span>
        </div>
        <div className="relative z-10">
          <h2 className="font-display text-4xl xl:text-5xl font-extrabold leading-tight mb-4">
            Rejoins la<br />communauté.
          </h2>
          <p className="on-night-muted text-base leading-relaxed max-w-sm">
            Client ou restaurateur, crée ton compte en quelques secondes et gagne du temps à chaque commande.
          </p>
        </div>
        <p className="relative z-10 on-night-muted text-xs">© {new Date().getFullYear()} <span className="notranslate" translate="no">FAST</span></p>
      </div>

      {/* Form side */}
      <div className="flex-1 flex flex-col">
      <div className="px-4 sm:px-6 py-4">
        <Link href="/" className="w-11 h-11 rounded-full border border-border bg-card flex items-center justify-center hover:bg-muted transition-colors">
          <ArrowLeft className="w-5 h-5 text-foreground" />
        </Link>
      </div>

      <div className="flex-1 flex flex-col items-center justify-center px-4 sm:px-6 pb-12">
        <m.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="w-full max-w-md bg-card border border-border rounded-2xl p-6 sm:p-8 shadow-sm"
        >
          <div className="text-center mb-8">
            <div className="w-12 h-12 mx-auto mb-3 rounded-full bg-neon flex items-center justify-center">
              <Zap className="w-6 h-6 text-fast-ink fill-fast-ink" />
            </div>
            <h1 className="font-black text-4xl italic tracking-tight"><span className="text-neon notranslate" translate="no">FAST</span></h1>
            <p className="font-display font-bold text-xl text-foreground mt-3">Crée ton compte</p>
          </div>

          <Suspense fallback={null}>
            <RoleInitializer onRole={setRole} />
          </Suspense>

          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="grid grid-cols-2 gap-1 p-1 rounded-full bg-muted border border-border">
              <button
                type="button"
                onClick={() => setRole("CLIENT")}
                className={`flex items-center justify-center gap-2 min-h-[44px] rounded-full text-sm font-bold transition-colors ${role === "CLIENT" ? "chip-on" : "text-muted-foreground hover:text-foreground"}`}
              >
                <ShoppingBag className="w-4 h-4" /> Client
              </button>
              <button
                type="button"
                onClick={() => setRole("RESTAURANT")}
                className={`flex items-center justify-center gap-2 min-h-[44px] rounded-full text-sm font-bold transition-colors ${role === "RESTAURANT" ? "chip-on" : "text-muted-foreground hover:text-foreground"}`}
              >
                <Store className="w-4 h-4" /> Restaurateur
              </button>
            </div>

            {role === "RESTAURANT" && (
              <div className="p-3 rounded-xl bg-muted border border-border text-muted-foreground text-xs text-center">
                Après l'inscription, vous pourrez créer la fiche de votre restaurant.
              </div>
            )}

            <div className="relative">
              <User className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground" />
              <input
                type="text"
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="Nom complet"
                required
                className="w-full h-14 pl-12 pr-4 rounded-xl bg-background border border-border text-foreground placeholder:text-muted-foreground focus:outline-none focus:border-fast-rose focus:ring-2 focus:ring-fast-rose/25"
              />
            </div>

            <div className="relative">
              <Mail className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground" />
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="Email"
                required
                className="w-full h-14 pl-12 pr-4 rounded-xl bg-background border border-border text-foreground placeholder:text-muted-foreground focus:outline-none focus:border-fast-rose focus:ring-2 focus:ring-fast-rose/25"
              />
            </div>

            <div className="relative">
              <Phone className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground" />
              <input
                type="tel"
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
                placeholder="Téléphone (optionnel)"
                className="w-full h-14 pl-12 pr-4 rounded-xl bg-background border border-border text-foreground placeholder:text-muted-foreground focus:outline-none focus:border-fast-rose focus:ring-2 focus:ring-fast-rose/25"
              />
            </div>

            <div className="relative">
              <Lock className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground" />
              <input
                type={showPassword ? "text" : "password"}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="Mot de passe"
                required
                minLength={8}
                pattern="(?=.*[A-Z])(?=.*[0-9]).{8,}"
                title="8 caractères minimum, 1 majuscule et 1 chiffre"
                className="w-full h-14 pl-12 pr-12 rounded-xl bg-background border border-border text-foreground placeholder:text-muted-foreground focus:outline-none focus:border-fast-rose focus:ring-2 focus:ring-fast-rose/25"
              />
              <button
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                className="absolute right-1.5 top-1/2 -translate-y-1/2 w-11 h-11 flex items-center justify-center rounded-full text-muted-foreground hover:text-foreground transition-colors"
              >
                {showPassword ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
              </button>
            </div>
            <p className="text-xs text-muted-foreground">8 caractères minimum, 1 majuscule et 1 chiffre.</p>

            {error && (
              <div className="p-3 rounded-xl bg-red-500/10 text-red-600 dark:text-red-400 text-sm text-center">
                {error}
              </div>
            )}

            <m.button
              whileTap={{ scale: 0.98 }}
              type="submit"
              disabled={isLoadingAuth}
              className="btn-neon w-full !min-h-[3.5rem] text-base"
            >
              {isLoadingAuth ? "Inscription..." : role === "RESTAURANT" ? "S'inscrire comme restaurateur" : "S'inscrire"}
            </m.button>
          </form>

          <div className="my-6 flex items-center gap-3">
            <div className="h-px flex-1 bg-border" />
            <span className="text-xs font-bold text-muted-foreground uppercase tracking-wide">ou</span>
            <div className="h-px flex-1 bg-border" />
          </div>

          <GoogleSignInButton
            disabled={isLoadingAuth}
            onCredential={handleGoogle}
            onError={() => setError("Connexion Google impossible. Réessayez.")}
          />

          <div className="mt-6 text-center space-y-2">
            <p className="text-muted-foreground text-sm">
              Déjà un compte ?{" "}
              <Link href="/login" className="text-fast-rose font-bold hover:underline">
                Se connecter
              </Link>
            </p>
          </div>
        </m.div>
      </div>
      </div>
    </div>
  );
}
