"use client";

import { useState, useEffect, useMemo } from "react";
import { useMutation } from "@tanstack/react-query";
import { paymentsApi, getErrorMessage } from "@/api/fastBackend";
import {
  getCart,
  updateCartQuantity,
  updateCartItemNotes,
  removeFromCart,
  getCartTotal,
  getCartRestaurants,
  keepOnlyRestaurant,
  CartItem,
} from "@/lib/localCart";
import { ArrowLeft, Minus, Plus, Trash2, Zap, ShoppingCart, UtensilsCrossed, AlertTriangle, StickyNote } from "lucide-react";
import { Textarea } from "@/components/ui/textarea";
import { m, AnimatePresence } from "framer-motion";
import Link from "next/link";
import { useRouter } from "next/navigation";
import SafeImage from "@/components/SafeImage";
import { useI18n } from "@/lib/i18n";
import { useAuth } from "@/lib/AuthContext";

const WALK_TIME_OPTIONS = [5, 10, 15, 20, 30];

export default function CartPage() {
  const { t } = useI18n();
  const { isAuthenticated } = useAuth();
  const router = useRouter();
  const [notes, setNotes] = useState("");
  const [showCheckout, setShowCheckout] = useState(false);
  const [cartItems, setCartItems] = useState<CartItem[]>([]);
  const [walkTimeMin, setWalkTimeMin] = useState(10);
  const [editingNotesFor, setEditingNotesFor] = useState<string | null>(null);

  useEffect(() => {
    setCartItems(getCart());
  }, []);

  const updateQty = (id: string, quantity: number) => {
    const next = quantity <= 0 ? removeFromCart(id) : updateCartQuantity(id, quantity);
    setCartItems(next);
  };

  const setItemNotes = (id: string, value: string) => {
    setCartItems(updateCartItemNotes(id, value));
  };

  // An order belongs to exactly one restaurant, so a mixed cart must be resolved
  // before checkout instead of silently dropping the other restaurants' items.
  const restaurantsInCart = useMemo(() => getCartRestaurants(cartItems), [cartItems]);
  const hasMixedCart = restaurantsInCart.length > 1;

  const keepRestaurant = (restaurantId: string) => {
    setCartItems(keepOnlyRestaurant(restaurantId));
  };

  const placeOrderMutation = useMutation({
    mutationFn: async () => {
      const restaurantId = cartItems[0]?.restaurantId;
      if (!restaurantId) throw { status: 0, message: t("cart_empty_err") };
      if (hasMixedCart) {
        throw { status: 0, message: t("cart_mixed_err") };
      }
      // Stripe Checkout handles the payment off-site; the order is
      // materialized by the webhook / confirm endpoint after payment.
      // The cart is only cleared on the success page — cancelling
      // payment brings the customer back with their cart intact.
      const orderNote = notes.trim();
      const session = await paymentsApi.checkoutSession({
        restaurantId,
        items: cartItems.map((c, i) => ({
          menuItemId: c.menuItemId,
          quantity: c.quantity || 1,
          selectedOptions: c.options || [],
          allergyNotes:
            [c.notes, i === 0 ? orderNote : ""].filter(Boolean).join(" · ") ||
            undefined,
        })),
        userWalkTimeMin: walkTimeMin,
        returnBase: `${window.location.origin}/order-complete`,
      });
      window.location.href = session.url;
    },
  });

  const cartTotal = getCartTotal(cartItems);

  if (cartItems.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center h-screen px-4 bg-background">
        <div className="w-20 h-20 rounded-full bg-muted flex items-center justify-center mb-5">
          <ShoppingCart className="w-9 h-9 text-muted-foreground" />
        </div>
        <h2 className="font-display font-bold text-foreground text-2xl mb-2">{t("cart_empty")}</h2>
        <p className="text-sm text-muted-foreground text-center mb-7 max-w-xs">
          {t("cart_empty_sub")}
        </p>
        <Link href="/" className="btn-neon">
          {t("discover")}
        </Link>
      </div>
    );
  }

  return (
    <div className="pb-36 min-h-screen bg-background">
      {/* Header */}
      <div className="bg-background/90 backdrop-blur-md px-4 sm:px-6 py-3 border-b border-border sticky top-0 md:top-16 z-20">
        <div className="max-w-2xl mx-auto flex items-center gap-3">
          <Link
            href="/"
            className="w-11 h-11 rounded-full border border-border bg-card flex items-center justify-center hover:bg-muted transition-colors shrink-0"
          >
            <ArrowLeft className="w-5 h-5 text-foreground" />
          </Link>
          <div className="min-w-0">
            <h1 className="font-display font-bold text-xl text-foreground leading-tight">{t("cart_title")}</h1>
            <p className="text-xs text-muted-foreground">
              {t("items_n", { n: cartItems.length })}
            </p>
          </div>
        </div>
      </div>

      {cartItems.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-24 px-4">
          <div className="w-20 h-20 rounded-full bg-muted flex items-center justify-center mb-5">
            <ShoppingCart className="w-9 h-9 text-muted-foreground" />
          </div>
          <h2 className="font-display font-bold text-foreground text-2xl mb-2">{t("cart_empty")}</h2>
          <p className="text-sm text-muted-foreground text-center mb-7 max-w-xs">
            {t("cart_empty_sub")}
          </p>
          <Link href="/" className="btn-neon">
            {t("discover")}
          </Link>
        </div>
      ) : (
        <>
          {/* Mixed-cart resolver */}
          {hasMixedCart && (
            <div className="px-4 sm:px-6 pt-5 max-w-2xl mx-auto">
              <div className="rounded-2xl border border-fast-orange/40 bg-fast-orange/10 p-4">
                <div className="flex items-start gap-2.5">
                  <AlertTriangle className="w-4 h-4 text-fast-orange mt-0.5 shrink-0" />
                  <div>
                    <p className="text-sm font-bold text-foreground">
                      {t("mixed_title")}
                    </p>
                    <p className="text-xs text-muted-foreground mt-0.5">
                      {t("mixed_sub")}
                    </p>
                  </div>
                </div>
                <div className="flex flex-wrap gap-2 mt-3">
                  {restaurantsInCart.map((r) => (
                    <button
                      key={r.id}
                      onClick={() => keepRestaurant(r.id)}
                      className="btn-outline !bg-card hover:!bg-muted text-xs"
                    >
                      {t("keep_rest", { n: r.name })}
                    </button>
                  ))}
                </div>
              </div>
            </div>
          )}

          {/* Restaurant name */}
          <div className="px-4 sm:px-6 pt-6 pb-1 max-w-2xl mx-auto">
            <div className="flex items-center gap-2">
              <Zap className="w-4 h-4 text-fast-rose shrink-0" fill="currentColor" />
              <span className="font-display font-bold text-lg text-foreground">
                {hasMixedCart
                  ? restaurantsInCart.map((r) => r.name).join(" + ")
                  : cartItems[0]?.restaurantName}
              </span>
            </div>
          </div>

          {/* Items */}
          <div className="px-4 sm:px-6 max-w-2xl mx-auto divide-y divide-border">
            <AnimatePresence>
              {cartItems.map((item) => (
                <m.div
                  key={item.id}
                  initial={{ opacity: 0, x: -20 }}
                  animate={{ opacity: 1, x: 0 }}
                  exit={{ opacity: 0, x: 20 }}
                  className="py-4"
                >
                  <div className="flex items-center gap-3">
                    <div className="w-16 h-16 rounded-xl bg-muted overflow-hidden flex-shrink-0">
                      {item.imageUrl ? (
                        <SafeImage src={item.imageUrl} alt={item.name} width={64} height={64} className="w-full h-full object-cover" />
                      ) : (
                        <div className="w-full h-full flex items-center justify-center bg-muted"><UtensilsCrossed className="w-6 h-6 text-muted-foreground" /></div>
                      )}
                    </div>

                    <div className="flex-1 min-w-0">
                      <h4 className="font-bold text-sm text-foreground truncate">{item.name}</h4>
                      {hasMixedCart && (
                        <p className="text-xs text-muted-foreground truncate">{item.restaurantName}</p>
                      )}
                      <p className="text-sm font-bold text-foreground tabular-nums mt-0.5">
                        {((item.price || 0) * (item.quantity || 1)).toFixed(2)} €
                      </p>
                    </div>

                    <div className="flex items-center gap-1">
                      <button
                        aria-label={(item.quantity || 1) <= 1 ? t("rm_item", { n: item.name }) : t("dec_qty", { n: item.name })}
                        onClick={() => updateQty(item.id, (item.quantity || 1) - 1)}
                        className="w-11 h-11 flex items-center justify-center group"
                      >
                        <span className="w-9 h-9 rounded-full border border-border bg-card flex items-center justify-center group-hover:bg-muted transition-colors">
                          {(item.quantity || 1) <= 1 ? (
                            <Trash2 className="w-4 h-4 text-red-500" />
                          ) : (
                            <Minus className="w-4 h-4 text-foreground" />
                          )}
                        </span>
                      </button>
                      <span className="text-sm font-bold w-5 text-center text-foreground tabular-nums">{item.quantity || 1}</span>
                      <button
                        aria-label={t("inc_qty", { n: item.name })}
                        onClick={() => updateQty(item.id, (item.quantity || 1) + 1)}
                        className="w-11 h-11 flex items-center justify-center group"
                      >
                        <span className="w-9 h-9 rounded-full bg-primary flex items-center justify-center group-hover:opacity-90 transition-opacity">
                          <Plus className="w-4 h-4 text-primary-foreground" />
                        </span>
                      </button>
                    </div>
                  </div>

                  {/* Per-item note — goes to the kitchen with this line only */}
                  {editingNotesFor === item.id ? (
                    <input
                      autoFocus
                      value={item.notes || ""}
                      onChange={(e) => setItemNotes(item.id, e.target.value)}
                      onBlur={() => setEditingNotesFor(null)}
                      onKeyDown={(e) => e.key === "Enter" && setEditingNotesFor(null)}
                      placeholder={t("note_for", { n: item.name })}
                      aria-label={t("note_for", { n: item.name })}
                      className="mt-3 w-full text-sm rounded-xl border border-border bg-card px-3 py-2.5 text-foreground placeholder:text-muted-foreground outline-none focus:border-fast-rose focus:ring-2 focus:ring-fast-rose/25"
                    />
                  ) : (
                    <button
                      onClick={() => setEditingNotesFor(item.id)}
                      className="mt-1 min-h-[44px] flex items-center gap-1.5 text-xs font-semibold text-muted-foreground hover:text-fast-rose transition-colors text-left"
                    >
                      <StickyNote className="w-3.5 h-3.5 shrink-0" />
                      {item.notes ? item.notes : t("add_note")}
                    </button>
                  )}
                </m.div>
              ))}
            </AnimatePresence>
          </div>

          {/* Order-level notes */}
          <div className="px-4 sm:px-6 mt-8 max-w-2xl mx-auto">
            <label htmlFor="order-notes" className="block text-xs font-bold text-muted-foreground uppercase tracking-wide mb-2">
              {t("order_note_lbl")}
            </label>
            <Textarea
              id="order-notes"
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              placeholder={t("notes_ph")}
              className="bg-card border-border text-foreground rounded-xl text-sm resize-none h-20 placeholder:text-muted-foreground focus-visible:ring-fast-rose/40"
            />
          </div>

          {/* Pickup timing */}
          <div className="px-4 sm:px-6 mt-8 max-w-2xl mx-auto">
            <p className="text-xs font-bold text-muted-foreground uppercase tracking-wide mb-2">
              {t("arrive_lbl")}
            </p>
            <div className="flex flex-wrap gap-2">
              {WALK_TIME_OPTIONS.map((minutes) => (
                <button
                  key={minutes}
                  onClick={() => setWalkTimeMin(minutes)}
                  aria-pressed={walkTimeMin === minutes}
                  className={`text-sm font-bold px-4 min-h-[44px] rounded-full border tabular-nums transition-colors ${
                    walkTimeMin === minutes
                      ? "chip-on"
                      : "bg-card border-border text-foreground hover:bg-muted"
                  }`}
                >
                  {minutes} min
                </button>
              ))}
            </div>
          </div>

          {/* Summary */}
          <div className="px-4 sm:px-6 mt-8 max-w-2xl mx-auto">
            <div className="border-t border-border pt-5">
              <div className="flex items-center justify-between mb-2.5">
                <span className="text-sm text-muted-foreground">{t("subtotal")}</span>
                <span className="text-sm font-medium text-foreground tabular-nums">{cartTotal.toFixed(2)} €</span>
              </div>
              <div className="flex items-center justify-between mb-2.5">
                <span className="text-sm text-muted-foreground">{t("service_fee")}</span>
                <span className="text-sm font-medium text-green-600 dark:text-green-400">{t("free")}</span>
              </div>
              <div className="h-px bg-border my-4" />
              <div className="flex items-center justify-between">
                <span className="font-bold text-foreground">{t("total")}</span>
                <span className="font-extrabold text-xl text-foreground tabular-nums">{cartTotal.toFixed(2)} €</span>
              </div>
            </div>
          </div>

          {/* Order button */}
          <div className="fixed left-0 right-0 px-4 z-50 max-w-2xl mx-auto bottom-[calc(5rem+env(safe-area-inset-bottom))] md:bottom-6">
            <button
              type="button"
              onClick={() => setShowCheckout(true)}
              disabled={hasMixedCart}
              className="btn-neon w-full !min-h-[3.5rem] text-base"
            >
              <Zap className="w-5 h-5" fill="currentColor" />
              {hasMixedCart ? t("mixed_btn") : t("order_btn", { n: cartTotal.toFixed(2) })}
            </button>
          </div>
        </>
      )}

      {/* Simple Checkout Modal */}
      <AnimatePresence>
        {showCheckout && (
          <m.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-end sm:items-center justify-center"
            onClick={() => setShowCheckout(false)}
          >
            <m.div
              initial={{ y: "100%" }}
              animate={{ y: 0 }}
              exit={{ y: "100%" }}
              className="bg-card border border-border w-full sm:w-[420px] sm:rounded-2xl rounded-t-3xl p-6 pb-[calc(1.5rem+env(safe-area-inset-bottom))] sm:pb-6"
              onClick={(e) => e.stopPropagation()}
            >
              <h2 className="font-display text-2xl font-bold text-foreground mb-4">{t("confirm_order")}</h2>
              <p className="text-foreground font-bold tabular-nums mb-1">{t("total")}: {cartTotal.toFixed(2)} €</p>
              <p className="text-muted-foreground text-sm mb-6">
                {cartItems[0]?.restaurantName} · {t("arrive_in", { n: walkTimeMin })}
              </p>
              {placeOrderMutation.isError && (
                <p role="alert" className="text-sm text-red-600 dark:text-red-400 mb-4">
                  {getErrorMessage(placeOrderMutation.error, t("order_fail"))}
                </p>
              )}
              <div className="flex gap-3">
                <button type="button" className="btn-outline flex-1 text-sm" onClick={() => setShowCheckout(false)}>
                  {t("cancel")}
                </button>
                <button
                  type="button"
                  className="btn-neon flex-1 text-sm"
                  onClick={() => {
                    if (!isAuthenticated) {
                      router.push("/login");
                      return;
                    }
                    placeOrderMutation.mutate();
                  }}
                  disabled={placeOrderMutation.isPending}
                >
                  {placeOrderMutation.isPending ? "..." : t("confirm")}
                </button>
              </div>
            </m.div>
          </m.div>
        )}
      </AnimatePresence>
    </div>
  );
}
