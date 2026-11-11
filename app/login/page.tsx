"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { m } from "framer-motion";
import { Eye, EyeOff, Mail, Lock, ArrowLeft, Zap, Store } from "lucide-react";
import Link from "next/link";
import { useAuth } from "@/lib/AuthContext";
import { useI18n } from "@/lib/i18n";
import GoogleSignInButton from "@/components/GoogleSignInButton";

export default function LoginPage() {
  const router = useRouter();
  const { login, googleLogin, isLoadingAuth } = useAuth();
  const { t } = useI18n();
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
      setError(err.message || t("login_err"));
    }
  };

  const handleGoogle = async (idToken: string) => {
    setError("");
    try {
      const currentUser = await googleLogin(idToken);
      const destination = currentUser?.role === "RESTAURANT" ? "/partner/orders" : "/";
      router.replace(destination);
    } catch (err: any) {
      setError(err.message || t("google_err"));
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
            {t("tagline")}
          </h2>
          <p className="on-night-muted text-base leading-relaxed max-w-sm">
            {t("login_hero_sub")}
          </p>
        </div>
        <p className="relative z-10 on-night-muted text-xs">© {new Date().getFullYear()} <span className="notranslate" translate="no">FAST</span></p>
      </div>

      {/* Form side */}
      <div className="flex-1 flex flex-col">
      {/* Header */}
      <div className="px-4 sm:px-6 py-4 flex items-center justify-between">
        <Link href="/" className="w-11 h-11 rounded-full border border-border bg-card flex items-center justify-center hover:bg-muted transition-colors">
          <ArrowLeft className="w-5 h-5 text-foreground" />
        </Link>
        <Link
          href="/partner"
          className="btn-outline text-sm"
        >
          <Store className="w-4 h-4" />
          {t("resto_space")}
        </Link>
      </div>

      <div className="flex-1 flex flex-col items-center justify-center px-4 sm:px-6 pb-12">
        <m.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="w-full max-w-md bg-card border border-border rounded-2xl p-6 sm:p-8 shadow-sm"
        >
          {/* Logo */}
          <div className="text-center mb-8">
            <div className="w-12 h-12 mx-auto mb-3 rounded-full bg-neon flex items-center justify-center">
              <Zap className="w-6 h-6 text-fast-ink fill-fast-ink" />
            </div>
            <h1 className="font-black text-4xl italic tracking-tight">
              <span className="text-neon notranslate" translate="no">FAST</span>
            </h1>
            <p className="font-display font-bold text-xl text-foreground mt-3">{t("login_welcome")}</p>
          </div>

          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="relative">
              <Mail className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground" />
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder={t("email_lbl")}
                required
                className="w-full h-14 pl-12 pr-4 rounded-xl bg-background border border-border text-foreground placeholder:text-muted-foreground focus:outline-none focus:border-fast-rose focus:ring-2 focus:ring-fast-rose/25"
              />
            </div>

            <div className="relative">
              <Lock className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground" />
              <input
                type={showPassword ? "text" : "password"}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder={t("pwd_lbl")}
                required
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
              {isLoadingAuth ? t("connecting") : t("login_submit")}
            </m.button>
          </form>

          <div className="my-6 flex items-center gap-3">
            <div className="h-px flex-1 bg-border" />
            <span className="text-xs font-bold text-muted-foreground uppercase tracking-wide">{t("or_divider")}</span>
            <div className="h-px flex-1 bg-border" />
          </div>

          <GoogleSignInButton
            disabled={isLoadingAuth}
            onCredential={handleGoogle}
            onError={() => setError(t("google_err"))}
          />

          <div className="mt-6 text-center space-y-2">
            <p className="text-muted-foreground text-sm">
              {t("no_account")}{" "}
              <Link href="/register" className="text-fast-rose font-bold hover:underline">
                {t("signup_btn")}
              </Link>
            </p>
            <p className="text-muted-foreground text-sm">
              {t("are_resto")}{" "}
              <Link href="/register?role=restaurant" className="text-fast-rose font-bold hover:underline">
                {t("create_pro")}
              </Link>
            </p>
          </div>

        </m.div>
      </div>
      </div>
    </div>
  );
}
