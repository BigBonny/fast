"use client";

import { useEffect } from "react";
import { AlertTriangle, RotateCcw } from "lucide-react";
import Link from "next/link";
import { Button } from "@/components/ui/button";

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    // Surface the failure so it can be picked up by the browser console / monitoring.
    console.error(error);
  }, [error]);

  return (
    <div className="min-h-screen flex flex-col items-center justify-center px-8 text-center bg-white dark:bg-gray-950">
      <div className="w-20 h-20 rounded-3xl bg-red-50 dark:bg-red-500/10 flex items-center justify-center mb-5">
        <AlertTriangle className="w-9 h-9 text-red-500" />
      </div>
      <h1 className="text-xl font-black text-gray-900 dark:text-white mb-2">Une erreur est survenue</h1>
      <p className="text-sm text-gray-400 max-w-xs mb-6">
        Quelque chose s&apos;est mal passé de notre côté. Réessayez dans un instant.
      </p>
      <div className="flex gap-3">
        <Button onClick={reset} className="rounded-xl px-5 text-white" style={{ background: "#14b8a6" }}>
          <RotateCcw className="w-4 h-4 mr-2" />
          Réessayer
        </Button>
        <Link href="/">
          <Button variant="outline" className="rounded-xl px-5">
            Accueil
          </Button>
        </Link>
      </div>
      {error.digest && <p className="text-[11px] text-gray-300 mt-6 font-mono">ref: {error.digest}</p>}
    </div>
  );
}
