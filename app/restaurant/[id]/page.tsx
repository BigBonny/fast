"use client";

import { useState, useEffect, useMemo, Suspense, useCallback } from "react";
import { useQuery } from "@tanstack/react-query";
import { restaurantApi, menuApi } from "@/api/fastBackend";
import { addToCart, getCart, getCartCount, getCartTotal, keepOnlyRestaurant, CartItem } from "@/lib/localCart";
import type { MenuItem } from "@/lib/types";
import { ArrowLeft, Star, Clock, Zap, ShoppingBag, MapPin, Phone, Flame, Store, ClipboardList, AlertTriangle } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { m, AnimatePresence } from "framer-motion";
import Link from "next/link";

import MenuItemCard from "@/components/fast/MenuItemCard";
import SafeImage from "@/components/SafeImage";

const categoryLabels: Record<string, string> = {
  entree: "Entrées",
  plat: "Plats",
  dessert: "Desserts",
  boisson: "Boissons",
  accompagnement: "Accompagnements",
  menu: "Menus",
};

function RestaurantContent({ restaurantId }: { restaurantId: string }) {
  const [activeCategory, setActiveCategory] = useState("all");

  const { data: restaurant, isLoading: loadingRestaurant } = useQuery({
    queryKey: ["restaurant", restaurantId],
    queryFn: () => restaurantApi.get(restaurantId),
    enabled: !!restaurantId,
    staleTime: 3 * 60 * 1000,
    gcTime: 10 * 60 * 1000,
  });

  const { data: menuItems = [], isLoading: loadingMenu } = useQuery({
    queryKey: ["menuItems", restaurantId],
    queryFn: () => menuApi.byRestaurant(restaurantId),
    enabled: !!restaurantId,
    staleTime: 3 * 60 * 1000,
    gcTime: 10 * 60 * 1000,
  });

  const restaurantMenuItems: MenuItem[] = restaurant?.menuItems?.length ? restaurant.menuItems : menuItems;

  // Read localStorage after mount so server and client render the same markup.
  const [cartItems, setCartItems] = useState<CartItem[]>([]);
  const [pendingItem, setPendingItem] = useState<MenuItem | null>(null);

  useEffect(() => {
    setCartItems(getCart());
  }, []);

  const cartCount = getCartCount(cartItems);
  const cartTotal = getCartTotal(cartItems);

  const otherRestaurantInCart = cartItems.find((c) => c.restaurantId !== restaurantId);

  const commitAdd = useCallback(
    (item: MenuItem) => {
      setCartItems(
        addToCart({
          menuItemId: item.id,
          restaurantId,
          restaurantName: restaurant?.name || "",
          name: item.name,
          price: item.price,
          imageUrl: item.image || "",
        })
      );
    },
    [restaurantId, restaurant?.name]
  );

  // A cart can only ever target one restaurant, so ask before discarding the other one.
  const handleAdd = useCallback(
    (item: MenuItem) => {
      if (otherRestaurantInCart) {
        setPendingItem(item);
        return;
      }
      commitAdd(item);
    },
    [otherRestaurantInCart, commitAdd]
  );

  const confirmReplaceCart = useCallback(() => {
    if (!pendingItem) return;
    keepOnlyRestaurant(restaurantId);
    commitAdd(pendingItem);
    setPendingItem(null);
  }, [pendingItem, restaurantId, commitAdd]);

  const categories = useMemo(() => {
    const cats = new Set(restaurantMenuItems.map((item) => item.category).filter(Boolean));
    return Array.from(cats) as string[];
  }, [restaurantMenuItems]);

  const filteredItems =
    activeCategory === "all"
      ? restaurantMenuItems
      : restaurantMenuItems.filter((item) => item.category === activeCategory);

  if (loadingRestaurant) {
    return (
      <div className="flex items-center justify-center h-screen bg-white dark:bg-gray-950">
        <div className="w-8 h-8 border-2 border-amber-400 border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  if (!restaurant) {
    return (
      <div className="flex flex-col items-center justify-center h-screen gap-4 bg-white dark:bg-gray-950">
        <div className="w-16 h-16 rounded-2xl bg-gray-100 dark:bg-gray-800 flex items-center justify-center">
          <Store className="w-8 h-8 text-gray-400" />
        </div>
        <p className="text-gray-400">Restaurant introuvable</p>
        <Link href="/">
          <Button variant="outline" size="sm">Retour</Button>
        </Link>
      </div>
    );
  }

  return (
    <div className="pb-28 min-h-screen bg-white dark:bg-gray-950">
      {/* Hero */}
      <div className="relative h-48 md:h-72 bg-gradient-to-br from-gray-100 to-gray-50 dark:from-gray-800 dark:to-gray-900">
        {restaurant.image && (
          <SafeImage src={restaurant.image} alt={restaurant.name} fill sizes="100vw" className="object-cover" priority />
        )}
        <div className="absolute inset-0 bg-gradient-to-t from-black/60 via-black/10 to-transparent" />
        <Link href="/" className="absolute top-4 left-4 md:top-6 md:left-8 w-9 h-9 bg-white/90 backdrop-blur-sm rounded-xl flex items-center justify-center shadow-sm hover:bg-white transition-colors">
          <ArrowLeft className="w-4 h-4 text-gray-700" />
        </Link>
      </div>

      {/* Info */}
      <div className="px-5 md:px-8 -mt-6 md:-mt-12 relative z-10 max-w-4xl mx-auto">
        <div className="bg-white dark:bg-gray-900 rounded-2xl p-4 md:p-6 shadow-lg shadow-gray-200/60 dark:shadow-black/40 border border-gray-100 dark:border-gray-800">
          <div className="flex items-start justify-between">
            <div>
              <h1 className="font-black text-xl md:text-3xl text-gray-900 dark:text-white">{restaurant.name}</h1>
              {restaurant.description && (
                <p className="text-xs text-gray-400 mt-1">{restaurant.description}</p>
              )}
            </div>
            {restaurant.rating && (
              <div className="flex items-center gap-1 bg-amber-50 dark:bg-amber-500/10 px-2 py-1 rounded-lg">
                <Star className="w-3.5 h-3.5 text-amber-400 fill-amber-400" />
                <span className="text-sm font-bold text-amber-700 dark:text-amber-400">{restaurant.rating}</span>
              </div>
            )}
          </div>
          <div className="flex items-center gap-4 mt-3">
            <div className="flex items-center gap-1 text-gray-400">
              <Clock className="w-3.5 h-3.5" />
              <span className="text-xs font-medium">
                {restaurant.normalPrepTime || 5} min
              </span>
            </div>
            <div className="flex items-center gap-1 text-cyan-500">
              <Zap className="w-3.5 h-3.5" fill="currentColor" />
              <span className="text-xs font-semibold">Commande rapide</span>
            </div>
            {restaurant.isRushMode && (
              <Badge className="bg-red-50 text-red-500 border-red-100 text-xs inline-flex items-center gap-1">
                <Flame className="w-3 h-3" /> Rush
              </Badge>
            )}
          </div>
        </div>
      </div>

      {/* Infos restaurant */}
      <div className="px-5 md:px-8 mt-3 max-w-4xl mx-auto">
        <div className="bg-gray-50 dark:bg-gray-900 dark:border dark:border-gray-800 rounded-2xl p-4 space-y-2.5">
          {restaurant.address && (
            <div className="flex items-center gap-3">
              <MapPin className="w-4 h-4 text-amber-500 flex-shrink-0" />
              <span className="text-xs text-gray-600 dark:text-gray-300">{restaurant.address}</span>
            </div>
          )}
          {restaurant.phone && (
            <div className="flex items-center gap-3">
              <Phone className="w-4 h-4 text-amber-500 flex-shrink-0" />
              <span className="text-xs text-gray-600 dark:text-gray-300">{restaurant.phone}</span>
            </div>
          )}
        </div>
      </div>

      {/* Category Tabs */}
      {categories.length > 0 && (
        <div className="px-5 md:px-8 mt-5 max-w-4xl mx-auto">
          <Tabs value={activeCategory} onValueChange={setActiveCategory}>
            <TabsList className="bg-gray-50 dark:bg-gray-900 h-9 p-0.5 w-full overflow-x-auto flex justify-start">
              <TabsTrigger value="all" className="text-xs px-3 rounded-lg data-[state=active]:bg-emerald-500 data-[state=active]:text-white">
                Tout
              </TabsTrigger>
              {categories.map((cat) => (
                <TabsTrigger
                  key={cat}
                  value={cat}
                  className="text-xs px-3 rounded-lg capitalize data-[state=active]:bg-emerald-500 data-[state=active]:text-white"
                >
                  {categoryLabels[cat] || cat}
                </TabsTrigger>
              ))}
            </TabsList>
          </Tabs>
        </div>
      )}

      {/* Menu Items */}
      <div className="px-5 md:px-8 mt-4 max-w-4xl mx-auto">
        {loadingMenu ? (
          <div className="space-y-2.5 md:grid md:grid-cols-2 md:gap-3 md:space-y-0">
            {[1, 2, 3, 4].map((i) => (
              <div key={i} className="h-24 rounded-xl skeleton-shimmer" />
            ))}
          </div>
        ) : filteredItems.length === 0 ? (
          <div className="text-center py-12">
            <div className="w-14 h-14 rounded-2xl bg-gray-100 dark:bg-gray-800 flex items-center justify-center mx-auto mb-3">
              <ClipboardList className="w-7 h-7 text-gray-400" />
            </div>
            <p className="text-gray-400 text-sm">Aucun plat dans cette catégorie</p>
          </div>
        ) : (
          <div className="space-y-2.5 md:grid md:grid-cols-2 md:gap-3 md:space-y-0">
            <AnimatePresence>
              {filteredItems.map((item) => (
                <m.div
                  key={item.id}
                  initial={{ opacity: 0, y: 8 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0 }}
                >
                  <MenuItemCard item={item} onAdd={() => handleAdd(item)} />
                </m.div>
              ))}
            </AnimatePresence>
          </div>
        )}
      </div>

      {/* Cart Footer */}
      {cartCount > 0 && (
        <m.div
          initial={{ y: 80 }}
          animate={{ y: 0 }}
          className="fixed left-0 right-0 px-5 z-50 max-w-xl mx-auto bottom-[calc(5rem+env(safe-area-inset-bottom))] md:bottom-6"
        >
          <Link href="/cart">
            <div className="bg-emerald-500 hover:bg-emerald-600 transition-colors rounded-2xl p-4 shadow-xl shadow-emerald-500/25 flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="w-8 h-8 bg-white/25 rounded-xl flex items-center justify-center">
                  <ShoppingBag className="w-4 h-4 text-white" />
                </div>
                <span className="text-white font-bold text-sm">
                  {cartCount} article{cartCount > 1 ? "s" : ""}
                </span>
              </div>
              <span className="text-white font-black text-lg">
                {cartTotal.toFixed(2)} €
              </span>
            </div>
          </Link>
        </m.div>
      )}

      {/* Switch-restaurant confirmation */}
      <AnimatePresence>
        {pendingItem && (
          <m.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            role="dialog"
            aria-modal="true"
            aria-label="Changer de restaurant"
            className="fixed inset-0 z-[60] bg-black/60 backdrop-blur-sm flex items-end sm:items-center justify-center"
            onClick={() => setPendingItem(null)}
          >
            <m.div
              initial={{ y: "100%" }}
              animate={{ y: 0 }}
              exit={{ y: "100%" }}
              onClick={(e) => e.stopPropagation()}
              className="bg-white dark:bg-gray-900 w-full sm:w-[400px] sm:rounded-2xl rounded-t-2xl p-6 pb-[calc(1.5rem+env(safe-area-inset-bottom))] sm:pb-6"
            >
              <div className="flex items-center gap-2.5 mb-3">
                <AlertTriangle className="w-5 h-5 text-amber-500" />
                <h2 className="text-lg font-bold text-gray-900 dark:text-white">Vider votre panier ?</h2>
              </div>
              <p className="text-sm text-gray-500 dark:text-gray-400 mb-6">
                Votre panier contient déjà des plats de {otherRestaurantInCart?.restaurantName}. Une
                commande ne peut concerner qu&apos;un seul restaurant.
              </p>
              <div className="flex gap-3">
                <Button variant="outline" className="flex-1" onClick={() => setPendingItem(null)}>
                  Annuler
                </Button>
                <Button
                  className="flex-1 text-white"
                  style={{ background: "linear-gradient(135deg, #14b8a6, #06b6d4)" }}
                  onClick={confirmReplaceCart}
                >
                  Vider et ajouter
                </Button>
              </div>
            </m.div>
          </m.div>
        )}
      </AnimatePresence>
    </div>
  );
}

export default function RestaurantPage({ params }: { params: { id: string } }) {
  return (
    <Suspense fallback={<div className="flex items-center justify-center h-screen bg-white dark:bg-gray-950">
      <div className="w-8 h-8 border-2 border-amber-400 border-t-transparent rounded-full animate-spin" />
    </div>}>
      <RestaurantContent restaurantId={params.id} />
    </Suspense>
  );
}
