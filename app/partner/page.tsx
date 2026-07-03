"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";

export default function PartnerIndex() {
  const router = useRouter();

  useEffect(() => {
    router.replace("/partner/orders");
  }, [router]);

  return (
    <div className="min-h-screen flex items-center justify-center" style={{ background: "#020617" }}>
      <div className="font-bebas text-3xl tracking-[8px] animate-pulse" style={{ color: "#00c8b3" }}>
        ⚡ FAST
      </div>
    </div>
  );
}
