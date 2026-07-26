"use client";

import { useState } from "react";
import { m } from "framer-motion";
import { ArrowLeft, Users, Plus, Link2, Copy, Check, PartyPopper, LogOut } from "lucide-react";
import Link from "next/link";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { Button } from "@/components/ui/button";
import { groupApi, getErrorMessage } from "@/api/fastBackend";
import { useAuth } from "@/lib/AuthContext";

export default function GroupOrderPage() {
  const { isAuthenticated } = useAuth();
  const queryClient = useQueryClient();
  const [copied, setCopied] = useState(false);
  const [joinCode, setJoinCode] = useState("");

  const { data: group, isLoading } = useQuery({
    queryKey: ["group", "mine"],
    queryFn: () => groupApi.mine(),
    enabled: isAuthenticated,
    refetchInterval: 15000,
  });

  const invalidate = () => queryClient.invalidateQueries({ queryKey: ["group", "mine"] });

  const createMutation = useMutation({
    mutationFn: () => groupApi.create(),
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
    <div className="min-h-screen bg-gray-50 dark:bg-gray-950 pb-20">
      {/* Header */}
      <div className="bg-white dark:bg-gray-900 px-5 py-4 flex items-center gap-3 border-b border-gray-100 dark:border-gray-800 sticky top-0 z-20">
        <Link href="/" className="w-9 h-9 bg-gray-50 dark:bg-gray-800 rounded-xl flex items-center justify-center">
          <ArrowLeft className="w-4 h-4 text-gray-600 dark:text-gray-300" />
        </Link>
        <div className="flex items-center gap-2">
          <Users className="w-5 h-5 text-violet-500" />
          <h1 className="font-bold text-gray-900 dark:text-white">Commande de groupe</h1>
        </div>
      </div>

      <div className="px-5 pt-6">
        {!isAuthenticated ? (
          <div className="bg-white dark:bg-gray-900 rounded-2xl p-6 text-center border border-gray-100 dark:border-gray-800">
            <Users className="w-10 h-10 text-violet-400 mx-auto mb-3" />
            <h2 className="font-bold text-gray-900 dark:text-white mb-1">Connectez-vous</h2>
            <p className="text-sm text-gray-400 mb-5">
              Les commandes de groupe nécessitent un compte FAST.
            </p>
            <Link href="/login">
              <Button className="rounded-xl px-6" style={{ background: "#7c3aed" }}>
                Se connecter
              </Button>
            </Link>
          </div>
        ) : isLoading ? (
          <div className="space-y-4">
            <div className="h-44 rounded-2xl skeleton-shimmer" />
            <div className="h-32 rounded-2xl skeleton-shimmer" />
          </div>
        ) : group ? (
          /* Active group */
          <div className="bg-white dark:bg-gray-900 rounded-2xl p-6 shadow-sm border border-gray-100 dark:border-gray-800">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 bg-violet-100 dark:bg-violet-500/15 rounded-xl flex items-center justify-center">
                  <Users className="w-5 h-5 text-violet-600 dark:text-violet-400" />
                </div>
                <div>
                  <h3 className="font-bold text-gray-900 dark:text-white">Groupe actif</h3>
                  <p className="text-xs text-gray-400">
                    {group.members?.length || 0} personne{(group.members?.length || 0) > 1 ? "s" : ""} • En cours
                  </p>
                </div>
              </div>
              <span className="px-3 py-1 bg-emerald-100 dark:bg-emerald-500/15 text-emerald-600 dark:text-emerald-400 text-xs font-bold rounded-full">
                Actif
              </span>
            </div>

            {/* Code */}
            <div className="bg-gray-50 dark:bg-gray-800 rounded-xl p-4 flex items-center justify-between">
              <div className="flex items-center gap-3">
                <Link2 className="w-5 h-5 text-gray-400" />
                <span className="font-mono font-bold text-gray-900 dark:text-white">{group.code}</span>
              </div>
              <m.button
                whileTap={{ scale: 0.95 }}
                onClick={copyCode}
                aria-label="Copier le code du groupe"
                className="w-10 h-10 rounded-xl bg-white dark:bg-gray-700 flex items-center justify-center shadow-sm"
              >
                {copied ? <Check className="w-5 h-5 text-emerald-500" /> : <Copy className="w-5 h-5 text-gray-500" />}
              </m.button>
            </div>

            {/* Members */}
            <div className="mt-4 flex -space-x-2">
              {(group.members || []).map((member) => (
                <div
                  key={member.id}
                  title={member.name}
                  className="w-10 h-10 rounded-full border-2 border-white dark:border-gray-900 flex items-center justify-center text-xs font-bold text-white"
                  style={{ background: "linear-gradient(135deg, #7c3aed, #06b6d4)" }}
                >
                  {member.name?.[0]?.toUpperCase() || "?"}
                </div>
              ))}
            </div>

            <Button
              variant="outline"
              className="w-full mt-5 rounded-xl h-11 text-red-500 border-red-200 hover:bg-red-50"
              onClick={() => leaveMutation.mutate(group.id)}
              disabled={leaveMutation.isPending}
            >
              <LogOut className="w-4 h-4 mr-2" />
              Quitter le groupe
            </Button>
            {leaveMutation.isError && (
              <p role="alert" className="text-sm text-red-500 mt-2">
                {getErrorMessage(leaveMutation.error)}
              </p>
            )}
          </div>
        ) : (
          <>
            {/* Create Group */}
            <div className="bg-gradient-to-br from-violet-500 to-pink-500 rounded-2xl p-6 text-white mb-6">
              <PartyPopper className="w-12 h-12 text-white/90 mb-4" />
              <h2 className="text-xl font-black mb-2">Commandez avec vos amis</h2>
              <p className="text-white/80 text-sm mb-4">
                Créez un groupe et invitez vos amis à commander ensemble. Chacun choisit ce qu&apos;il veut !
              </p>
              <Button
                className="w-full bg-white text-violet-600 font-bold hover:bg-white/90 rounded-xl h-12"
                onClick={() => createMutation.mutate()}
                disabled={createMutation.isPending}
              >
                <Plus className="w-5 h-5 mr-2" />
                {createMutation.isPending ? "Création…" : "Créer un groupe"}
              </Button>
              {createMutation.isError && (
                <p role="alert" className="text-sm text-white/90 mt-2">
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
              className="bg-white dark:bg-gray-900 rounded-2xl p-6 shadow-sm border border-gray-100 dark:border-gray-800 mb-6"
            >
              <label htmlFor="group-code" className="block font-bold text-gray-900 dark:text-white mb-4">
                Rejoindre un groupe
              </label>
              <div className="flex gap-2">
                <input
                  id="group-code"
                  type="text"
                  value={joinCode}
                  onChange={(e) => setJoinCode(e.target.value)}
                  placeholder="Entrez le code du groupe"
                  className="flex-1 bg-gray-50 dark:bg-gray-800 dark:text-white dark:placeholder:text-gray-500 rounded-xl px-4 py-3 text-sm border-0 focus:ring-2 focus:ring-violet-500"
                />
                <Button
                  type="submit"
                  className="rounded-xl px-6"
                  style={{ background: "#7c3aed" }}
                  disabled={!joinCode.trim() || joinMutation.isPending}
                >
                  {joinMutation.isPending ? "…" : "Rejoindre"}
                </Button>
              </div>
              {joinMutation.isError && (
                <p role="alert" className="text-sm text-red-500 mt-2">
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
