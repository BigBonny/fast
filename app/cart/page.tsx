"use client";

import { useState, useEffect, useMemo } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { orderApi, getErrorMessage } from "@/api/fastBackend";
import {
  getCart,
  updateCartQuantity,
  updateCartItemNotes,
  removeFromCart,
  clearCart,
  getCartTotal,
  getCartRestaurants,
  keepOnlyRestaurant,
  CartItem,
} from "@/lib/localCart";
import { ArrowLeft, Minus, Plus, Trash2, Zap, ShoppingCart, PartyPopper, UtensilsCrossed, AlertTriangle, StickyNote } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { m, AnimatePresence } from "framer-motion";
import Link from "next/link";
import { useRouter } from "next/navigation";
import SafeImage from "@/components/SafeImage";

const WALK_TIME_OPTIONS = [5, 10, 15, 20, 30];

export default function CartPage() {
  const [notes, setNotes] = useState("");
  const [showCheckout, setShowCheckout] = useState(false);
  const [confirmed, setConfirmed] = useState(false);
  const [cartItems, setCartItems] = useState<CartItem[]>([]);
  const [walkTimeMin, setWalkTimeMin] = useState(10);
  const [editingNotesFor, setEditingNotesFor] = useState<string | null>(null);
  const queryClient = useQueryClient();
  const router = useRouter();

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
      if (!restaurantId) throw { status: 0, message: "Votre panier est vide." };
      if (hasMixedCart) {
        throw { status: 0, message: "Votre panier contient plusieurs restaurants." };
      }
      const order = await orderApi.create({
        restaurantId,
        items: cartItems.map((c) => ({
          menuItemId: c.menuItemId,
          quantity: c.quantity || 1,
          selectedOptions: c.options || [],
          allergyNotes: c.notes || "",
        })),
        allergyNotes: notes,
        userWalkTimeMin: walkTimeMin,
      });
      clearCart();
      setCartItems([]);
      return order;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["orders"] });
      setShowCheckout(false);
      setConfirmed(true);
    },
  });

  const cartTotal = getCartTotal(cartItems);

  if (cartItems.length === 0 && !confirmed) {
    return (
      <div className="flex flex-col items-center justify-center h-screen px-5 bg-white dark:bg-gray-950">
        <div className="w-20 h-20 rounded-3xl bg-gray-100 dark:bg-gray-800 flex items-center justify-center mb-4">
          <ShoppingCart className="w-9 h-9 text-gray-300 dark:text-gray-600" />
        </div>
        <h2 className="font-bold text-gray-900 dark:text-white text-lg mb-1">Panier vide</h2>
        <p className="text-sm text-gray-400 text-center mb-6">
          Explorez les restaurants et ajoutez des plats
        </p>
        <Link href="/">
          <Button className="rounded-xl px-6" style={{ background: "#14b8a6" }}>
            Découvrir
          </Button>
        </Link>
      </div>
    );
  }

  if (confirmed) {
    return (
      <div className="min-h-screen bg-gray-50/50 dark:bg-gray-950 flex flex-col items-center justify-center px-5">
        <div className="w-20 h-20 rounded-3xl bg-emerald-50 dark:bg-emerald-500/10 flex items-center justify-center mb-4">
          <PartyPopper className="w-9 h-9 text-emerald-500" />
        </div>
        <h1 className="text-2xl font-black text-gray-900 dark:text-white mb-2">Commande confirmée !</h1>
        <p className="text-gray-400 text-center mb-6">Votre commande a été envoyée au restaurant.</p>
        <Button onClick={() => router.push("/orders")} style={{ background: "#14b8a6" }}>
          Voir mes commandes
        </Button>
      </div>
    );
  }

  return (
    <div className="pb-32 min-h-screen bg-gray-50/50 dark:bg-gray-950">
      {/* Header */}
      <div className="bg-white/90 dark:bg-gray-900/90 backdrop-blur-md px-5 py-4 border-b border-gray-100 dark:border-gray-800 sticky top-0 md:top-16 z-20">
        <div className="max-w-2xl mx-auto flex items-center gap-3">
          <Link href="/" className="w-9 h-9 bg-gray-50 dark:bg-gray-800 rounded-xl flex items-center justify-center hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors">
            <ArrowLeft className="w-4 h-4 text-gray-600 dark:text-gray-300" />
          </Link>
          <div>
            <h1 className="font-bold text-gray-900 dark:text-white">Mon panier</h1>
            <p className="text-xs text-gray-400">
              {cartItems.length} article{cartItems.length > 1 ? "s" : ""}
            </p>
          </div>
        </div>
      </div>

      {cartItems.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-24 px-5">
          <div className="w-20 h-20 rounded-3xl bg-gray-100 dark:bg-gray-800 flex items-center justify-center mb-4">
            <ShoppingCart className="w-9 h-9 text-gray-300 dark:text-gray-600" />
          </div>
          <h2 className="font-bold text-gray-900 dark:text-white text-lg mb-1">Panier vide</h2>
          <p className="text-sm text-gray-400 text-center mb-6">
            Explorez les restaurants et ajoutez des plats
          </p>
          <Link href="/">
            <Button className="rounded-xl px-6" style={{ background: "#14b8a6" }}>
              Découvrir
            </Button>
          </Link>
        </div>
      ) : (
        <>
          {/* Mixed-cart resolver */}
          {hasMixedCart && (
            <div className="px-5 pt-4 max-w-2xl mx-auto">
              <div className="rounded-2xl border border-amber-200 dark:border-amber-500/30 bg-amber-50 dark:bg-amber-500/10 p-4">
                <div className="flex items-start gap-2.5">
                  <AlertTriangle className="w-4 h-4 text-amber-500 mt-0.5 shrink-0" />
                  <div>
                    <p className="text-sm font-bold text-amber-900 dark:text-amber-300">
                      Plusieurs restaurants dans votre panier
                    </p>
                    <p className="text-xs text-amber-700/80 dark:text-amber-400/80 mt-0.5">
                      Une commande ne peut concerner qu&apos;un seul restaurant. Choisissez lequel garder.
                    </p>
                  </div>
                </div>
                <div className="flex flex-wrap gap-2 mt-3">
                  {restaurantsInCart.map((r) => (
                    <button
                      key={r.id}
                      onClick={() => keepRestaurant(r.id)}
                      className="text-xs font-bold px-3 py-1.5 rounded-xl bg-white dark:bg-gray-900 border border-amber-200 dark:border-amber-500/30 text-amber-800 dark:text-amber-300 hover:bg-amber-100 dark:hover:bg-amber-500/20 transition-colors"
                    >
                      Garder {r.name}
                    </button>
                  ))}
                </div>
              </div>
            </div>
          )}

          {/* Restaurant name */}
          <div className="px-5 pt-4 pb-2 max-w-2xl mx-auto">
            <div className="flex items-center gap-2 text-gray-500">
              <Zap className="w-3.5 h-3.5 text-teal-400" fill="currentColor" />
              <span className="text-xs font-semibold">
                {hasMixedCart
                  ? restaurantsInCart.map((r) => r.name).join(" + ")
                  : cartItems[0]?.restaurantName}
              </span>
            </div>
          </div>

          {/* Items */}
          <div className="px-5 space-y-2 max-w-2xl mx-auto">
            <AnimatePresence>
              {cartItems.map((item) => (
                <m.div
                  key={item.id}
                  initial={{ opacity: 0, x: -20 }}
                  animate={{ opacity: 1, x: 0 }}
                  exit={{ opacity: 0, x: 20 }}
                  className="bg-white dark:bg-gray-900 rounded-xl p-3.5 border border-gray-100 dark:border-gray-800"
                >
                  <div className="flex items-center gap-3">
                    <div className="w-14 h-14 rounded-xl bg-gray-50 dark:bg-gray-800 overflow-hidden flex-shrink-0">
                      {item.imageUrl ? (
                        <SafeImage src={item.imageUrl} alt={item.name} width={56} height={56} className="w-full h-full object-cover" />
                      ) : (
                        <div className="w-full h-full flex items-center justify-center bg-gray-100 dark:bg-gray-800"><UtensilsCrossed className="w-6 h-6 text-gray-300 dark:text-gray-600" /></div>
                      )}
                    </div>

                    <div className="flex-1 min-w-0">
                      <h4 className="font-semibold text-sm text-gray-900 dark:text-white truncate">{item.name}</h4>
                      {hasMixedCart && (
                        <p className="text-[11px] text-gray-400 truncate">{item.restaurantName}</p>
                      )}
                      <p className="text-sm font-bold text-gray-900 dark:text-white mt-0.5">
                        {((item.price || 0) * (item.quantity || 1)).toFixed(2)} €
                      </p>
                    </div>

                    <div className="flex items-center gap-2">
                      <button
                        aria-label={(item.quantity || 1) <= 1 ? `Retirer ${item.name} du panier` : `Diminuer la quantité de ${item.name}`}
                        onClick={() => updateQty(item.id, (item.quantity || 1) - 1)}
                        className="w-7 h-7 rounded-lg bg-gray-50 dark:bg-gray-800 flex items-center justify-center hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors"
                      >
                        {(item.quantity || 1) <= 1 ? (
                          <Trash2 className="w-3.5 h-3.5 text-red-400" />
                        ) : (
                          <Minus className="w-3.5 h-3.5 text-gray-500" />
                        )}
                      </button>
                      <span className="text-sm font-bold w-5 text-center text-gray-900 dark:text-white">{item.quantity || 1}</span>
                      <button
                        aria-label={`Augmenter la quantité de ${item.name}`}
                        onClick={() => updateQty(item.id, (item.quantity || 1) + 1)}
                        className="w-7 h-7 rounded-lg flex items-center justify-center hover:opacity-80 transition-colors"
                        style={{ background: "#14b8a6" }}
                      >
                        <Plus className="w-3.5 h-3.5 text-white" />
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
                      placeholder={`Note pour ${item.name}…`}
                      aria-label={`Note pour ${item.name}`}
                      className="mt-2.5 w-full text-xs rounded-lg border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-800 px-3 py-2 text-gray-900 dark:text-white outline-none focus:border-teal-400"
                    />
                  ) : (
                    <button
                      onClick={() => setEditingNotesFor(item.id)}
                      className="mt-2 flex items-center gap-1.5 text-[11px] font-semibold text-gray-400 hover:text-teal-500 transition-colors"
                    >
                      <StickyNote className="w-3 h-3" />
                      {item.notes ? item.notes : "Ajouter une note"}
                    </button>
                  )}
                </m.div>
              ))}
            </AnimatePresence>
          </div>

          {/* Order-level notes */}
          <div className="px-5 mt-4 max-w-2xl mx-auto">
            <label htmlFor="order-notes" className="block text-xs font-bold text-gray-400 uppercase tracking-wider mb-1.5">
              Note pour la commande
            </label>
            <Textarea
              id="order-notes"
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              placeholder="Notes spéciales (allergies, sans sauce...)"
              className="bg-white dark:bg-gray-900 border-gray-100 dark:border-gray-800 dark:text-white rounded-xl text-sm resize-none h-20 placeholder:text-gray-300 dark:placeholder:text-gray-600"
            />
          </div>

          {/* Pickup timing */}
          <div className="px-5 mt-4 max-w-2xl mx-auto">
            <p className="text-xs font-bold text-gray-400 uppercase tracking-wider mb-1.5">
              J&apos;arrive dans
            </p>
            <div className="flex flex-wrap gap-2">
              {WALK_TIME_OPTIONS.map((minutes) => (
                <button
                  key={minutes}
                  onClick={() => setWalkTimeMin(minutes)}
                  aria-pressed={walkTimeMin === minutes}
                  className={`text-xs font-bold px-3.5 py-2 rounded-xl border transition-colors ${
                    walkTimeMin === minutes
                      ? "bg-teal-500 border-teal-500 text-white"
                      : "bg-white dark:bg-gray-900 border-gray-200 dark:border-gray-700 text-gray-600 dark:text-gray-300 hover:border-teal-300"
                  }`}
                >
                  {minutes} min
                </button>
              ))}
            </div>
          </div>

          {/* Summary */}
          <div className="px-5 mt-5 max-w-2xl mx-auto">
            <div className="bg-white dark:bg-gray-900 rounded-2xl p-4 border border-gray-100 dark:border-gray-800">
              <div className="flex items-center justify-between mb-2">
                <span className="text-sm text-gray-400">Sous-total</span>
                <span className="text-sm font-medium text-gray-900 dark:text-gray-200">{cartTotal.toFixed(2)} €</span>
              </div>
              <div className="flex items-center justify-between mb-2">
                <span className="text-sm text-gray-400">Frais de service</span>
                <span className="text-sm font-medium text-green-500">Gratuit</span>
              </div>
              <div className="h-px bg-gray-100 dark:bg-gray-800 my-3" />
              <div className="flex items-center justify-between">
                <span className="font-bold text-gray-900 dark:text-white">Total</span>
                <span className="font-black text-lg text-gray-900 dark:text-white">{cartTotal.toFixed(2)} €</span>
              </div>
            </div>
          </div>

          {/* Order button */}
          <div className="fixed left-0 right-0 px-5 z-50 max-w-2xl mx-auto bottom-[calc(5rem+env(safe-area-inset-bottom))] md:bottom-6">
            <Button
              onClick={() => setShowCheckout(true)}
              disabled={hasMixedCart}
              className="w-full h-14 text-white font-bold text-base rounded-2xl shadow-xl shadow-teal-500/25 flex items-center justify-center gap-2 hover:opacity-95 transition-opacity disabled:opacity-50"
              style={{ background: "linear-gradient(135deg, #14b8a6, #06b6d4)" }}
            >
              <Zap className="w-5 h-5" fill="currentColor" />
              {hasMixedCart ? "Choisissez un seul restaurant" : `Commander — ${cartTotal.toFixed(2)} €`}
            </Button>
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
              className="bg-white dark:bg-gray-900 w-full sm:w-[400px] sm:rounded-2xl rounded-t-2xl p-6 pb-[calc(1.5rem+env(safe-area-inset-bottom))] sm:pb-6"
              onClick={(e) => e.stopPropagation()}
            >
              <h2 className="text-xl font-bold text-gray-900 dark:text-white mb-4">Confirmer la commande</h2>
              <p className="text-gray-500 dark:text-gray-400 mb-1">Total: {cartTotal.toFixed(2)} €</p>
              <p className="text-gray-400 text-sm mb-6">
                {cartItems[0]?.restaurantName} · arrivée dans {walkTimeMin} min
              </p>
              {placeOrderMutation.isError && (
                <p role="alert" className="text-sm text-red-500 mb-4">
                  {getErrorMessage(placeOrderMutation.error, "La commande n'a pas pu être envoyée.")}
                </p>
              )}
              <div className="flex gap-3">
                <Button variant="outline" className="flex-1" onClick={() => setShowCheckout(false)}>
                  Annuler
                </Button>
                <Button
                  className="flex-1 text-white"
                  style={{ background: "linear-gradient(135deg, #14b8a6, #06b6d4)" }}
                  onClick={() => placeOrderMutation.mutate()}
                  disabled={placeOrderMutation.isPending}
                >
                  {placeOrderMutation.isPending ? "..." : "Confirmer"}
                </Button>
              </div>
            </m.div>
          </m.div>
        )}
      </AnimatePresence>
    </div>
  );
}
