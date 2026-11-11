"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { Zap } from "lucide-react";

export default function PartnerIndex() {
  const router = useRouter();

  useEffect(() => {
    router.replace("/partner/orders");
  }, [router]);

  return (
    <div className="min-h-screen flex flex-col items-center justify-center gap-5 bg-background">
      <div className="font-bebas text-3xl tracking-[8px] flex items-center gap-2">
        <Zap className="w-7 h-7 text-fast-orange fill-current" aria-hidden="true" />
        <span className="notranslate text-neon" translate="no">FAST</span>
      </div>
      <span className="w-5 h-5 rounded-full border-2 border-fast-teal/30 border-t-fast-teal animate-spin" aria-hidden="true" />
    </div>
  );
}
