import Link from "next/link";
import { Compass } from "lucide-react";

export default function NotFound() {
  return (
    <div className="min-h-screen flex flex-col items-center justify-center px-4 text-center bg-background text-foreground">
      <div className="w-20 h-20 rounded-full bg-muted flex items-center justify-center mb-6">
        <Compass className="w-9 h-9 text-fast-rose" />
      </div>
      <h1 className="font-display text-3xl font-bold text-foreground mb-2">Page introuvable</h1>
      <p className="text-sm text-muted-foreground max-w-xs mb-8">
        Cette page n&apos;existe pas ou a été déplacée.
      </p>
      <Link href="/" className="btn-neon text-sm">
        Retour à l&apos;accueil
      </Link>
    </div>
  );
}
