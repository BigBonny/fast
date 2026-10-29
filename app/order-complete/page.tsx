"use client";

import { Suspense, useEffect, useState } from "react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { paymentsApi, getErrorMessage, getToken } from "@/api/fastBackend";
import { clearCart } from "@/lib/localCart";
import { useI18n } from "@/lib/i18n";
import { Button } from "@/components/ui/button";
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
      <div className="min-h-screen flex flex-col items-center justify-center px-5 bg-white dark:bg-gray-950">
        <Loader2 className="w-8 h-8 text-teal-500 animate-spin mb-4" />
        <p className="text-gray-400 text-sm">{t("payment_confirming")}</p>
      </div>
    );
  }

  if (state === "paid") {
    return (
      <div className="min-h-screen bg-gray-50/50 dark:bg-gray-950 flex flex-col items-center justify-center px-5">
        <div className="w-20 h-20 rounded-3xl bg-emerald-50 dark:bg-emerald-500/10 flex items-center justify-center mb-4">
          <PartyPopper className="w-9 h-9 text-emerald-500" />
        </div>
        <h1 className="text-2xl font-black text-gray-900 dark:text-white mb-2">
          {t("order_confirmed")}
        </h1>
        <p className="text-gray-400 text-center mb-6">{t("order_sent")}</p>
        <Link href="/orders">
          <Button style={{ background: "#14b8a6" }}>{t("view_orders")}</Button>
        </Link>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50/50 dark:bg-gray-950 flex flex-col items-center justify-center px-5">
      <div className="w-20 h-20 rounded-3xl bg-red-50 dark:bg-red-500/10 flex items-center justify-center mb-4">
        <XCircle className="w-9 h-9 text-red-400" />
      </div>
      <h1 className="text-2xl font-black text-gray-900 dark:text-white mb-2">
        {outcome === "cancel" ? t("payment_cancelled") : t("order_fail")}
      </h1>
      <p className="text-gray-400 text-center mb-6">
        {outcome === "cancel"
          ? t("cart_kept")
          : error || t("payment_failed_sub")}
      </p>
      <Link href="/cart">
        <Button variant="outline">{t("cart_title")}</Button>
      </Link>
    </div>
  );
}

export default function OrderCompletePage() {
  return (
    <Suspense
      fallback={
        <div className="min-h-screen flex items-center justify-center bg-white dark:bg-gray-950">
          <Loader2 className="w-8 h-8 text-teal-500 animate-spin" />
        </div>
      }
    >
      <OrderCompleteInner />
    </Suspense>
  );
}
