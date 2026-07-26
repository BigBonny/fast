import Link from "next/link";
import { Compass } from "lucide-react";
import { Button } from "@/components/ui/button";

export default function NotFound() {
  return (
    <div className="min-h-screen flex flex-col items-center justify-center px-8 text-center bg-white dark:bg-gray-950">
      <div className="w-20 h-20 rounded-3xl bg-violet-50 dark:bg-violet-500/10 flex items-center justify-center mb-5">
        <Compass className="w-9 h-9 text-violet-500" />
      </div>
      <h1 className="text-xl font-black text-gray-900 dark:text-white mb-2">Page introuvable</h1>
      <p className="text-sm text-gray-400 max-w-xs mb-6">
        Cette page n&apos;existe pas ou a été déplacée.
      </p>
      <Link href="/">
        <Button className="rounded-xl px-6 text-white" style={{ background: "#14b8a6" }}>
          Retour à l&apos;accueil
        </Button>
      </Link>
    </div>
  );
}
