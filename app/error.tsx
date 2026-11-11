"use client";

import { useEffect } from "react";
import { AlertTriangle, RotateCcw } from "lucide-react";
import Link from "next/link";

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
    <div className="min-h-screen flex flex-col items-center justify-center px-4 text-center bg-background text-foreground">
      <div className="w-20 h-20 rounded-full bg-destructive/10 flex items-center justify-center mb-6">
        <AlertTriangle className="w-9 h-9 text-destructive" />
      </div>
      <h1 className="font-display text-3xl font-bold text-foreground mb-2">Une erreur est survenue</h1>
      <p className="text-sm text-muted-foreground max-w-xs mb-8">
        Quelque chose s&apos;est mal passé de notre côté. Réessayez dans un instant.
      </p>
      <div className="flex flex-wrap justify-center gap-3">
        <button onClick={reset} className="btn-neon text-sm">
          <RotateCcw className="w-4 h-4" />
          Réessayer
        </button>
        <Link href="/" className="btn-outline !min-h-[3rem] text-sm">
          Accueil
        </Link>
      </div>
      {error.digest && <p className="text-xs text-muted-foreground mt-8 font-mono">ref: {error.digest}</p>}
    </div>
  );
}
