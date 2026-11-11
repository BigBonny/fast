"use client";

import { useState, useEffect, useMemo, Suspense, useCallback } from "react";
import { useQuery } from "@tanstack/react-query";
import { restaurantApi, menuApi } from "@/api/fastBackend";
import { addToCart, getCart, getCartCount, getCartTotal, keepOnlyRestaurant, CartItem } from "@/lib/localCart";
import type { MenuItem } from "@/lib/types";
import { ArrowLeft, Star, Clock, Zap, ShoppingBag, MapPin, Phone, Flame, Store, ClipboardList, AlertTriangle } from "lucide-react";
import { Badge } from "@/components/ui/badge";
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
      <div className="flex items-center justify-center h-screen bg-background">
        <div className="w-8 h-8 border-2 border-fast-rose border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  if (!restaurant) {
    return (
      <div className="flex flex-col items-center justify-center h-screen gap-4 px-4 bg-background">
        <div className="w-20 h-20 rounded-full bg-muted flex items-center justify-center">
          <Store className="w-9 h-9 text-muted-foreground" />
        </div>
        <p className="font-display text-xl font-bold text-foreground">Restaurant introuvable</p>
        <Link href="/" className="btn-outline text-sm">
          Retour
        </Link>
      </div>
    );
  }

  return (
    <div className="pb-32 min-h-screen bg-background">
      {/* Hero */}
      <div className="relative h-56 md:h-80 bg-muted">
        {restaurant.image && (
          <SafeImage src={restaurant.image} alt={restaurant.name} fill sizes="100vw" className="object-cover" priority />
        )}
        <div className="absolute inset-x-0 top-0 h-24 bg-gradient-to-b from-black/35 to-transparent" />
        <Link
          href="/"
          aria-label="Retour"
          className="absolute top-4 left-4 md:top-6 md:left-8 w-11 h-11 bg-white/95 backdrop-blur-sm rounded-full flex items-center justify-center shadow-sm hover:bg-white transition-colors"
        >
          <ArrowLeft className="w-5 h-5 text-fast-ink" />
        </Link>
      </div>

      {/* Info */}
      <div className="px-4 sm:px-6 md:px-8 pt-6 max-w-3xl mx-auto">
        <span className="inline-flex items-center gap-1.5 rounded-full bg-fast-gold px-3 py-1 text-xs font-bold text-fast-ink">
          <Zap className="w-3.5 h-3.5" fill="currentColor" />
          Commande rapide
        </span>
        <h1 className="font-display font-extrabold text-3xl md:text-5xl text-foreground mt-3 leading-tight">
          {restaurant.name}
        </h1>
        {restaurant.description && (
          <p className="text-sm text-muted-foreground mt-2 leading-relaxed">{restaurant.description}</p>
        )}

        {/* Facts line */}
        <div className="flex flex-wrap items-center gap-x-2 gap-y-2 mt-4 text-sm text-foreground">
          {!!restaurant.rating && (
            <>
              <span className="inline-flex items-center gap-1 font-bold tabular-nums">
                <Star className="w-4 h-4 text-fast-gold fill-fast-gold" />
                {restaurant.rating}
              </span>
              <span className="text-muted-foreground" aria-hidden="true">·</span>
            </>
          )}
          <span className="inline-flex items-center gap-1 text-muted-foreground">
            <Clock className="w-4 h-4" />
            <span className="font-medium tabular-nums">{restaurant.normalPrepTime || 5} min</span>
          </span>
          {restaurant.isRushMode && (
            <Badge className="bg-red-500/10 text-red-600 dark:text-red-400 border-red-500/20 hover:bg-red-500/10 text-xs rounded-full inline-flex items-center gap-1">
              <Flame className="w-3 h-3" /> Rush
            </Badge>
          )}
        </div>

        {/* Infos restaurant */}
        {(restaurant.address || restaurant.phone) && (
          <div className="mt-5 border-y border-border divide-y divide-border">
            {restaurant.address && (
              <div className="flex items-center gap-3 py-3.5">
                <MapPin className="w-4 h-4 text-fast-rose flex-shrink-0" />
                <span className="text-sm text-muted-foreground">{restaurant.address}</span>
              </div>
            )}
            {restaurant.phone && (
              <div className="flex items-center gap-3 py-3.5">
                <Phone className="w-4 h-4 text-fast-rose flex-shrink-0" />
                <span className="text-sm text-muted-foreground tabular-nums">{restaurant.phone}</span>
              </div>
            )}
          </div>
        )}
      </div>

      {/* Category Tabs */}
      {categories.length > 0 && (
        <div className="sticky top-0 md:top-16 z-20 mt-6 bg-background/95 backdrop-blur-md border-b border-border">
          <div className="px-4 sm:px-6 md:px-8 py-3 max-w-3xl mx-auto">
            <Tabs value={activeCategory} onValueChange={setActiveCategory}>
              <TabsList className="bg-transparent h-auto p-0 w-full overflow-x-auto scrollbar-hide flex justify-start gap-2 rounded-none">
                <TabsTrigger
                  value="all"
                  className="text-sm font-bold px-4 min-h-[44px] rounded-full border border-border bg-card text-foreground shadow-none data-[state=active]:bg-primary data-[state=active]:text-primary-foreground data-[state=active]:border-primary data-[state=active]:shadow-none"
                >
                  Tout
                </TabsTrigger>
                {categories.map((cat) => (
                  <TabsTrigger
                    key={cat}
                    value={cat}
                    className="text-sm font-bold px-4 min-h-[44px] rounded-full border border-border bg-card text-foreground shadow-none capitalize data-[state=active]:bg-primary data-[state=active]:text-primary-foreground data-[state=active]:border-primary data-[state=active]:shadow-none"
                  >
                    {categoryLabels[cat] || cat}
                  </TabsTrigger>
                ))}
              </TabsList>
            </Tabs>
          </div>
        </div>
      )}

      {/* Menu Items */}
      <div className="px-4 sm:px-6 md:px-8 mt-6 max-w-3xl mx-auto">
        {!loadingMenu && filteredItems.length > 0 && (
          <div className="flex items-baseline justify-between mb-4">
            <h2 className="font-display font-bold text-2xl text-foreground">
              {activeCategory === "all" ? "Tout" : categoryLabels[activeCategory] || activeCategory}
            </h2>
            <span className="text-sm text-muted-foreground tabular-nums">{filteredItems.length}</span>
          </div>
        )}
        {loadingMenu ? (
          <div className="space-y-3">
            {[1, 2, 3, 4].map((i) => (
              <div key={i} className="h-24 rounded-2xl skeleton-shimmer" />
            ))}
          </div>
        ) : filteredItems.length === 0 ? (
          <div className="text-center py-16">
            <div className="w-20 h-20 rounded-full bg-muted flex items-center justify-center mx-auto mb-4">
              <ClipboardList className="w-9 h-9 text-muted-foreground" />
            </div>
            <p className="text-muted-foreground text-sm">Aucun plat dans cette catégorie</p>
          </div>
        ) : (
          <div className="space-y-3">
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
          className="fixed left-0 right-0 px-4 z-50 max-w-xl mx-auto bottom-[calc(5rem+env(safe-area-inset-bottom))] md:bottom-6"
        >
          <Link href="/cart" className="btn-neon w-full !justify-between !min-h-[3.5rem] !px-5">
            <span className="flex items-center gap-2.5 text-sm font-extrabold">
              <ShoppingBag className="w-5 h-5" />
              {cartCount} article{cartCount > 1 ? "s" : ""}
            </span>
            <span className="font-extrabold text-lg tabular-nums">
              {cartTotal.toFixed(2)} €
            </span>
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
              className="bg-card border border-border w-full sm:w-[420px] sm:rounded-2xl rounded-t-3xl p-6 pb-[calc(1.5rem+env(safe-area-inset-bottom))] sm:pb-6"
            >
              <div className="flex items-center gap-2.5 mb-3">
                <AlertTriangle className="w-5 h-5 text-fast-orange shrink-0" />
                <h2 className="font-display text-xl font-bold text-foreground">Vider votre panier ?</h2>
              </div>
              <p className="text-sm text-muted-foreground leading-relaxed mb-6">
                Votre panier contient déjà des plats de {otherRestaurantInCart?.restaurantName}. Une
                commande ne peut concerner qu&apos;un seul restaurant.
              </p>
              <div className="flex gap-3">
                <button type="button" className="btn-outline flex-1 text-sm" onClick={() => setPendingItem(null)}>
                  Annuler
                </button>
                <button type="button" className="btn-neon flex-1 text-sm" onClick={confirmReplaceCart}>
                  Vider et ajouter
                </button>
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
    <Suspense fallback={<div className="flex items-center justify-center h-screen bg-background">
      <div className="w-8 h-8 border-2 border-fast-rose border-t-transparent rounded-full animate-spin" />
    </div>}>
      <RestaurantContent restaurantId={params.id} />
    </Suspense>
  );
}
