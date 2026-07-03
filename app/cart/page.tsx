"use client";

import { useState, useEffect } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { orderApi } from "@/api/fastBackend";
import { getCart, updateCartQuantity, removeFromCart, clearCart, getCartTotal, CartItem } from "@/lib/localCart";
import { ArrowLeft, Minus, Plus, Trash2, Zap, ShoppingCart, PartyPopper, UtensilsCrossed } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { motion, AnimatePresence } from "framer-motion";
import Link from "next/link";
import { useRouter } from "next/navigation";

export default function CartPage() {
  const [notes, setNotes] = useState("");
  const [showCheckout, setShowCheckout] = useState(false);
  const [confirmed, setConfirmed] = useState(false);
  const [cartItems, setCartItems] = useState<CartItem[]>([]);
  const queryClient = useQueryClient();
  const router = useRouter();

  useEffect(() => {
    setCartItems(getCart());
  }, []);

  const updateQty = (id: string, quantity: number) => {
    const next = quantity <= 0 ? removeFromCart(id) : updateCartQuantity(id, quantity);
    setCartItems(next);
  };

  const placeOrderMutation = useMutation({
    mutationFn: async () => {
      const restaurantId = cartItems[0]?.restaurantId || "";
      const order = await orderApi.create({
        restaurantId,
        items: cartItems.map((c) => ({
          menuItemId: c.menuItemId,
          quantity: c.quantity || 1,
          selectedOptions: c.options || [],
          allergyNotes: c.notes || notes || "",
        })),
        userWalkTimeMin: 10,
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
      <div className="flex flex-col items-center justify-center h-screen px-5">
        <div className="w-20 h-20 rounded-3xl bg-gray-100 flex items-center justify-center mb-4">
          <ShoppingCart className="w-9 h-9 text-gray-300" />
        </div>
        <h2 className="font-bold text-gray-900 text-lg mb-1">Panier vide</h2>
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
      <div className="min-h-screen bg-gray-50/50 flex flex-col items-center justify-center px-5">
        <div className="w-20 h-20 rounded-3xl bg-emerald-50 flex items-center justify-center mb-4">
          <PartyPopper className="w-9 h-9 text-emerald-500" />
        </div>
        <h1 className="text-2xl font-black text-gray-900 mb-2">Commande confirmée !</h1>
        <p className="text-gray-400 text-center mb-6">Votre commande a été envoyée au restaurant.</p>
        <Button onClick={() => router.push("/orders")} style={{ background: "#14b8a6" }}>
          Voir mes commandes
        </Button>
      </div>
    );
  }

  return (
    <div className="pb-32 min-h-screen bg-gray-50/50">
      {/* Header */}
      <div className="bg-white px-5 py-4 flex items-center gap-3 border-b border-gray-100 sticky top-0 z-20">
        <Link href="/" className="w-9 h-9 bg-gray-50 rounded-xl flex items-center justify-center">
          <ArrowLeft className="w-4 h-4 text-gray-600" />
        </Link>
        <div>
          <h1 className="font-bold text-gray-900">Mon panier</h1>
          <p className="text-xs text-gray-400">
            {cartItems.length} article{cartItems.length > 1 ? "s" : ""}
          </p>
        </div>
      </div>

      {cartItems.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-24 px-5">
          <div className="w-20 h-20 rounded-3xl bg-gray-100 flex items-center justify-center mb-4">
            <ShoppingCart className="w-9 h-9 text-gray-300" />
          </div>
          <h2 className="font-bold text-gray-900 text-lg mb-1">Panier vide</h2>
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
          {/* Restaurant name */}
          <div className="px-5 pt-4 pb-2">
            <div className="flex items-center gap-2 text-gray-500">
              <Zap className="w-3.5 h-3.5 text-teal-400" fill="currentColor" />
              <span className="text-xs font-semibold">{cartItems[0]?.restaurantName}</span>
            </div>
          </div>

          {/* Items */}
          <div className="px-5 space-y-2">
            <AnimatePresence>
              {cartItems.map((item: any) => (
                <motion.div
                  key={item.id}
                  layout
                  initial={{ opacity: 0, x: -20 }}
                  animate={{ opacity: 1, x: 0 }}
                  exit={{ opacity: 0, x: 20 }}
                  className="bg-white rounded-xl p-3.5 flex items-center gap-3 border border-gray-100"
                >
                  <div className="w-14 h-14 rounded-xl bg-gray-50 overflow-hidden flex-shrink-0">
                    {item.imageUrl ? (
                      <img src={item.imageUrl} alt={item.name} className="w-full h-full object-cover" />
                    ) : (
                      <div className="w-full h-full flex items-center justify-center bg-gray-100"><UtensilsCrossed className="w-6 h-6 text-gray-300" /></div>
                    )}
                  </div>

                  <div className="flex-1 min-w-0">
                    <h4 className="font-semibold text-sm text-gray-900 truncate">{item.name}</h4>
                    <p className="text-sm font-bold text-gray-900 mt-0.5">
                      {((item.price || 0) * (item.quantity || 1)).toFixed(2)} €
                    </p>
                  </div>

                  <div className="flex items-center gap-2">
                    <button
                      onClick={() => updateQty(item.id, (item.quantity || 1) - 1)}
                      className="w-7 h-7 rounded-lg bg-gray-50 flex items-center justify-center hover:bg-gray-100 transition-colors"
                    >
                      {(item.quantity || 1) <= 1 ? (
                        <Trash2 className="w-3.5 h-3.5 text-red-400" />
                      ) : (
                        <Minus className="w-3.5 h-3.5 text-gray-500" />
                      )}
                    </button>
                    <span className="text-sm font-bold w-5 text-center">{item.quantity || 1}</span>
                    <button
                      onClick={() => updateQty(item.id, (item.quantity || 1) + 1)}
                      className="w-7 h-7 rounded-lg flex items-center justify-center hover:opacity-80 transition-colors"
                      style={{ background: "#14b8a6" }}
                    >
                      <Plus className="w-3.5 h-3.5 text-white" />
                    </button>
                  </div>
                </motion.div>
              ))}
            </AnimatePresence>
          </div>

          {/* Notes */}
          <div className="px-5 mt-4">
            <Textarea
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              placeholder="Notes spéciales (allergies, sans sauce...)"
              className="bg-white border-gray-100 rounded-xl text-sm resize-none h-20 placeholder:text-gray-300"
            />
          </div>

          {/* Summary */}
          <div className="px-5 mt-5">
            <div className="bg-white rounded-2xl p-4 border border-gray-100">
              <div className="flex items-center justify-between mb-2">
                <span className="text-sm text-gray-400">Sous-total</span>
                <span className="text-sm font-medium">{cartTotal.toFixed(2)} €</span>
              </div>
              <div className="flex items-center justify-between mb-2">
                <span className="text-sm text-gray-400">Frais de service</span>
                <span className="text-sm font-medium text-green-500">Gratuit</span>
              </div>
              <div className="h-px bg-gray-100 my-3" />
              <div className="flex items-center justify-between">
                <span className="font-bold text-gray-900">Total</span>
                <span className="font-black text-lg text-gray-900">{cartTotal.toFixed(2)} €</span>
              </div>
            </div>
          </div>

          {/* Order button */}
          <div className="fixed bottom-20 left-0 right-0 px-5 z-50">
            <Button
              onClick={() => setShowCheckout(true)}
              className="w-full h-14 text-white font-bold text-base rounded-2xl shadow-xl flex items-center justify-center gap-2"
              style={{ background: "linear-gradient(135deg, #14b8a6, #06b6d4)" }}
            >
              <Zap className="w-5 h-5" fill="currentColor" />
              Commander — {cartTotal.toFixed(2)} €
            </Button>
          </div>
        </>
      )}

      {/* Simple Checkout Modal */}
      <AnimatePresence>
        {showCheckout && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-end sm:items-center justify-center"
            onClick={() => setShowCheckout(false)}
          >
            <motion.div
              initial={{ y: "100%" }}
              animate={{ y: 0 }}
              exit={{ y: "100%" }}
              className="bg-white w-full sm:w-[400px] sm:rounded-2xl rounded-t-2xl p-6"
              onClick={(e) => e.stopPropagation()}
            >
              <h2 className="text-xl font-bold text-gray-900 mb-4">Confirmer la commande</h2>
              <p className="text-gray-500 mb-6">Total: {cartTotal.toFixed(2)} €</p>
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
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
