"use client";

import { Suspense, useEffect, useState } from "react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { paymentsApi, getErrorMessage, getToken } from "@/api/fastBackend";
import { clearCart } from "@/lib/localCart";
import { useI18n } from "@/lib/i18n";
import { PartyPopper, XCircle, Loader2 } from "lucide-react";

function OrderCompleteInner() {
  const { t } = useI18n();
  const params = useSearchParams();
  const outcome = params.get("checkout");
  const sessionId = params.get("session_id");
  const [state, setState] = useState<"loading" | "paid" | "failed">("loading");
  const [error, setError] = useState("");

  useEffect(() => {
    if (outcome === "cancel") {
      setState("failed");
      return;
    }
    if (outcome !== "success" || !sessionId) {
      setState("failed");
      return;
    }
    if (!getToken()) {
      // The session exists but the user isn't logged in here — the
      // webhook still creates the order, so show success rather than
      // an error.
      clearCart();
      setState("paid");
      return;
    }
    // Confirm against Stripe — idempotent with the webhook.
    paymentsApi
      .confirmCheckoutSession(sessionId)
      .then(() => {
        clearCart();
        setState("paid");
      })
      .catch((err) => {
        // The webhook may still land; keep a calm message.
        setError(getErrorMessage(err, t("order_fail")));
        setState("failed");
      });
  }, [outcome, sessionId, t]);

  if (state === "loading") {
    return (
      <div className="min-h-screen flex flex-col items-center justify-center px-4 bg-background">
        <Loader2 className="w-8 h-8 text-fast-rose animate-spin mb-4" />
        <p className="text-muted-foreground text-sm">{t("payment_confirming")}</p>
      </div>
    );
  }

  if (state === "paid") {
    return (
      <div className="min-h-screen bg-background flex flex-col items-center justify-center px-4">
        <div className="night-surface w-full max-w-md p-8 flex flex-col items-center text-center">
          <div className="w-16 h-16 rounded-full bg-emerald-500/15 flex items-center justify-center mb-5">
            <PartyPopper className="w-8 h-8 text-emerald-400" />
          </div>
          <h1 className="font-display text-3xl font-extrabold leading-tight mb-2">
            {t("order_confirmed")}
          </h1>
          <p className="on-night-muted text-sm leading-relaxed">{t("order_sent")}</p>
        </div>
        <Link href="/orders" className="btn-neon mt-8">
          {t("view_orders")}
        </Link>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background flex flex-col items-center justify-center px-4">
      <div className="w-20 h-20 rounded-full bg-red-500/10 flex items-center justify-center mb-5">
        <XCircle className="w-9 h-9 text-red-500" />
      </div>
      <h1 className="font-display text-3xl font-extrabold text-foreground text-center mb-2">
        {outcome === "cancel" ? t("payment_cancelled") : t("order_fail")}
      </h1>
      <p className="text-muted-foreground text-center mb-7 max-w-sm">
        {outcome === "cancel"
          ? t("cart_kept")
          : error || t("payment_failed_sub")}
      </p>
      <Link href="/cart" className="btn-outline">
        {t("cart_title")}
      </Link>
    </div>
  );
}

export default function OrderCompletePage() {
  return (
    <Suspense
      fallback={
        <div className="min-h-screen flex items-center justify-center bg-background">
          <Loader2 className="w-8 h-8 text-fast-rose animate-spin" />
        </div>
      }
    >
      <OrderCompleteInner />
    </Suspense>
  );
}
