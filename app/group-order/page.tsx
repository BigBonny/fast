"use client";

import { useState } from "react";
import { m } from "framer-motion";
import { ArrowLeft, Users, Plus, Link2, Copy, Check, PartyPopper, LogOut } from "lucide-react";
import Link from "next/link";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { groupApi, restaurantApi, getErrorMessage } from "@/api/fastBackend";
import { useAuth } from "@/lib/AuthContext";

export default function GroupOrderPage() {
  const { isAuthenticated } = useAuth();
  const queryClient = useQueryClient();
  const [copied, setCopied] = useState(false);
  const [joinCode, setJoinCode] = useState("");
  const [createRestoId, setCreateRestoId] = useState("");

  const { data: restaurants = [] } = useQuery({
    queryKey: ["restaurants", "group-create"],
    queryFn: () => restaurantApi.list(),
    enabled: isAuthenticated,
  });

  const { data: group, isLoading } = useQuery({
    queryKey: ["group", "mine"],
    queryFn: () => groupApi.mine(),
    enabled: isAuthenticated,
    refetchInterval: 15000,
  });

  const invalidate = () => queryClient.invalidateQueries({ queryKey: ["group", "mine"] });

  const createMutation = useMutation({
    mutationFn: () => groupApi.create({ restaurantId: createRestoId }),
    onSuccess: invalidate,
  });

  const joinMutation = useMutation({
    mutationFn: (code: string) => groupApi.join(code.trim().toUpperCase()),
    onSuccess: () => {
      setJoinCode("");
      invalidate();
    },
  });

  const leaveMutation = useMutation({
    mutationFn: (id: string) => groupApi.leave(id),
    onSuccess: invalidate,
  });

  const copyCode = async () => {
    if (!group?.code) return;
    await navigator.clipboard.writeText(group.code);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className="min-h-screen bg-background pb-24">
      {/* Header */}
      <div className="bg-background/90 backdrop-blur-md px-4 sm:px-6 py-3 border-b border-border sticky top-0 z-20">
        <div className="max-w-2xl mx-auto flex items-center gap-3">
          <Link href="/" className="w-11 h-11 rounded-full border border-border bg-card flex items-center justify-center hover:bg-muted transition-colors shrink-0">
            <ArrowLeft className="w-5 h-5 text-foreground" />
          </Link>
          <div className="flex items-center gap-2 min-w-0">
            <Users className="w-5 h-5 text-fast-rose shrink-0" />
            <h1 className="font-display font-bold text-xl text-foreground truncate">Commande de groupe</h1>
          </div>
        </div>
      </div>

      <div className="px-4 sm:px-6 pt-6 max-w-2xl mx-auto">
        {!isAuthenticated ? (
          <div className="flex flex-col items-center text-center py-16">
            <div className="w-20 h-20 rounded-full bg-muted flex items-center justify-center mb-5">
              <Users className="w-9 h-9 text-muted-foreground" />
            </div>
            <h2 className="font-display font-bold text-2xl text-foreground mb-2">Connectez-vous</h2>
            <p className="text-sm text-muted-foreground mb-7 max-w-xs">
              Les commandes de groupe nécessitent un compte <span className="notranslate" translate="no">FAST</span>.
            </p>
            <Link href="/login" className="btn-neon">
              Se connecter
            </Link>
          </div>
        ) : isLoading ? (
          <div className="space-y-4">
            <div className="h-44 rounded-2xl skeleton-shimmer" />
            <div className="h-32 rounded-2xl skeleton-shimmer" />
          </div>
        ) : group ? (
          /* Active group */
          <div>
            <div className="flex items-center justify-between gap-3 mb-5">
              <div className="flex items-center gap-3 min-w-0">
                <div className="w-11 h-11 bg-fast-rose/10 rounded-full flex items-center justify-center shrink-0">
                  <Users className="w-5 h-5 text-fast-rose" />
                </div>
                <div className="min-w-0">
                  <h3 className="font-display font-bold text-xl text-foreground leading-tight">Groupe actif</h3>
                  <p className="text-xs text-muted-foreground mt-0.5">
                    {restaurants.find((r) => r.id === group.restaurantId)?.name || ""}
                    {restaurants.find((r) => r.id === group.restaurantId) ? " • " : ""}
                    {group.members?.length || 0} personne{(group.members?.length || 0) > 1 ? "s" : ""} • En cours
                  </p>
                </div>
              </div>
              <span className="px-3 py-1.5 bg-emerald-500/10 text-emerald-700 dark:text-emerald-400 text-xs font-bold rounded-full shrink-0">
                Actif
              </span>
            </div>

            {/* Code */}
            <div className="bg-card border border-border rounded-2xl p-5 flex items-center justify-between gap-3">
              <div className="flex items-center gap-3 min-w-0">
                <Link2 className="w-5 h-5 text-muted-foreground shrink-0" />
                <span className="font-extrabold text-3xl tracking-widest tabular-nums text-foreground truncate">{group.code}</span>
              </div>
              <m.button
                whileTap={{ scale: 0.95 }}
                onClick={copyCode}
                aria-label="Copier le code du groupe"
                className="w-11 h-11 rounded-full border border-border bg-background flex items-center justify-center hover:bg-muted transition-colors shrink-0"
              >
                {copied ? <Check className="w-5 h-5 text-emerald-500" /> : <Copy className="w-5 h-5 text-foreground" />}
              </m.button>
            </div>

            {/* Members */}
            <div className="mt-6 border-y border-border divide-y divide-border">
              {(group.members || []).map((member) => (
                <div key={member.id} className="flex items-center gap-3 py-3">
                  <div
                    title={member.name}
                    className="w-10 h-10 rounded-full bg-muted flex items-center justify-center text-sm font-bold text-foreground shrink-0"
                  >
                    {member.name?.[0]?.toUpperCase() || "?"}
                  </div>
                  <span className="text-sm font-semibold text-foreground truncate">{member.name}</span>
                </div>
              ))}
            </div>

            <button
              type="button"
              className="w-full mt-8 min-h-[44px] rounded-full border border-red-500/40 text-red-600 dark:text-red-400 font-bold text-sm inline-flex items-center justify-center gap-2 hover:bg-red-500/10 transition-colors disabled:opacity-50 disabled:pointer-events-none"
              onClick={() => leaveMutation.mutate(group.id)}
              disabled={leaveMutation.isPending}
            >
              <LogOut className="w-4 h-4" />
              Quitter le groupe
            </button>
            {leaveMutation.isError && (
              <p role="alert" className="text-sm text-red-600 dark:text-red-400 mt-2">
                {getErrorMessage(leaveMutation.error)}
              </p>
            )}
          </div>
        ) : (
          <>
            {/* Create Group */}
            <div className="night-surface p-6 mb-10">
              <PartyPopper className="w-10 h-10 text-fast-gold mb-4" />
              <h2 className="font-display text-2xl font-extrabold mb-2">Commandez avec vos amis</h2>
              <p className="on-night-muted text-sm leading-relaxed mb-5">
                Créez un groupe et invitez vos amis à commander ensemble. Chacun choisit ce qu&apos;il veut !
              </p>
              <select
                value={createRestoId}
                onChange={(e) => setCreateRestoId(e.target.value)}
                aria-label="Restaurant du groupe"
                className="w-full mb-3 h-12 px-4 rounded-xl bg-white/10 border border-white/20 text-white font-semibold text-sm outline-none focus:border-fast-pink [&>option]:text-fast-ink"
              >
                <option value="">Choisissez le restaurant…</option>
                {restaurants.map((r) => (
                  <option key={r.id} value={r.id}>{r.name}</option>
                ))}
              </select>
              <button
                type="button"
                className="btn-neon w-full"
                onClick={() => createMutation.mutate()}
                disabled={createMutation.isPending || !createRestoId}
              >
                <Plus className="w-5 h-5" />
                {createMutation.isPending ? "Création…" : "Créer un groupe"}
              </button>
              {createMutation.isError && (
                <p role="alert" className="text-sm text-red-300 mt-3">
                  {getErrorMessage(createMutation.error)}
                </p>
              )}
            </div>

            {/* Join Group */}
            <form
              onSubmit={(e) => {
                e.preventDefault();
                if (joinCode.trim()) joinMutation.mutate(joinCode);
              }}
              className="mb-6"
            >
              <label htmlFor="group-code" className="block font-display font-bold text-xl text-foreground mb-4">
                Rejoindre un groupe
              </label>
              <div className="flex gap-2">
                <input
                  id="group-code"
                  type="text"
                  value={joinCode}
                  onChange={(e) => setJoinCode(e.target.value)}
                  placeholder="Entrez le code du groupe"
                  className="flex-1 min-w-0 bg-card text-foreground placeholder:text-muted-foreground rounded-xl px-4 py-3 text-sm border border-border outline-none focus:border-fast-rose focus:ring-2 focus:ring-fast-rose/25"
                />
                <button
                  type="submit"
                  className="btn-outline shrink-0 text-sm disabled:opacity-50 disabled:pointer-events-none"
                  disabled={!joinCode.trim() || joinMutation.isPending}
                >
                  {joinMutation.isPending ? "…" : "Rejoindre"}
                </button>
              </div>
              {joinMutation.isError && (
                <p role="alert" className="text-sm text-red-600 dark:text-red-400 mt-2">
                  {getErrorMessage(joinMutation.error, "Code de groupe invalide.")}
                </p>
              )}
            </form>
          </>
        )}
      </div>
    </div>
  );
}
