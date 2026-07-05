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
    <div className="min-h-screen flex items-center justify-center" style={{ background: "#020617" }}>
      <div className="font-bebas text-3xl tracking-[8px] animate-pulse flex items-center gap-2" style={{ color: "#00c8b3" }}>
        <Zap className="w-7 h-7 fill-current" /> FAST
      </div>
    </div>
  );
}
