"use client";

import { useState, useMemo, Suspense } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { restaurantApi, menuApi } from "@/api/fastBackend";
import { addToCart, getCart, getCartCount, getCartTotal } from "@/lib/localCart";
import { ArrowLeft, Star, Clock, Zap, ShoppingBag, MapPin, Phone, Flame, Store, ClipboardList } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { motion, AnimatePresence } from "framer-motion";
import Link from "next/link";
import { useParams } from "next/navigation";

import MenuItemCard from "@/components/fast/MenuItemCard";

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
  const queryClient = useQueryClient();

  const { data: restaurant, isLoading: loadingRestaurant } = useQuery({
    queryKey: ["restaurant", restaurantId],
    queryFn: () => restaurantApi.get(restaurantId),
    enabled: !!restaurantId,
  });

  const { data: menuItems = [], isLoading: loadingMenu } = useQuery({
    queryKey: ["menuItems", restaurantId],
    queryFn: () => menuApi.byRestaurant(restaurantId),
    enabled: !!restaurantId,
  });

  const restaurantMenuItems = restaurant?.menuItems || menuItems;

  const [cartItems, setCartItems] = useState(getCart());
  const cartCount = getCartCount(cartItems);
  const cartTotal = getCartTotal(cartItems);

  const addToCartMutation = useMutation({
    mutationFn: async (item: any) => {
      const next = addToCart({
        menuItemId: item.id,
        restaurantId,
        restaurantName: restaurant?.name || "",
        name: item.name,
        price: item.price,
        imageUrl: item.imageUrl || item.image_url || "",
      });
      setCartItems(next);
      return next;
    },
  });

  const categories = useMemo(() => {
    const cats = new Set(restaurantMenuItems.map((item: any) => item.category).filter(Boolean));
    return Array.from(cats) as string[];
  }, [restaurantMenuItems]);

  const filteredItems =
    activeCategory === "all"
      ? restaurantMenuItems
      : restaurantMenuItems.filter((item: any) => item.category === activeCategory);

  // cartTotal and cartCount already computed above

  if (loadingRestaurant) {
    return (
      <div className="flex items-center justify-center h-screen">
        <div className="w-8 h-8 border-2 border-amber-400 border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  if (!restaurant) {
    return (
      <div className="flex flex-col items-center justify-center h-screen gap-4">
        <div className="w-16 h-16 rounded-2xl bg-gray-100 flex items-center justify-center">
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
    <div className="pb-28">
      {/* Hero */}
      <div className="relative h-48 bg-gradient-to-br from-gray-100 to-gray-50">
        {restaurant.image && (
          <img src={restaurant.image} alt={restaurant.name} className="w-full h-full object-cover" />
        )}
        <div className="absolute inset-0 bg-gradient-to-t from-black/50 to-transparent" />
        <Link href="/" className="absolute top-4 left-4 w-9 h-9 bg-white/90 backdrop-blur-sm rounded-xl flex items-center justify-center shadow-sm">
          <ArrowLeft className="w-4 h-4 text-gray-700" />
        </Link>
      </div>

      {/* Info */}
      <div className="px-5 -mt-6 relative z-10">
        <div className="bg-white rounded-2xl p-4 shadow-sm border border-gray-100">
          <div className="flex items-start justify-between">
            <div>
              <h1 className="font-black text-xl text-gray-900">{restaurant.name}</h1>
              {restaurant.description && (
                <p className="text-xs text-gray-400 mt-1">{restaurant.description}</p>
              )}
            </div>
            {restaurant.rating && (
              <div className="flex items-center gap-1 bg-amber-50 px-2 py-1 rounded-lg">
                <Star className="w-3.5 h-3.5 text-amber-400 fill-amber-400" />
                <span className="text-sm font-bold text-amber-700">{restaurant.rating}</span>
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
      <div className="px-5 mt-3">
        <div className="bg-gray-50 rounded-2xl p-4 space-y-2.5">
          {restaurant.address && (
            <div className="flex items-center gap-3">
              <MapPin className="w-4 h-4 text-amber-500 flex-shrink-0" />
              <span className="text-xs text-gray-600">{restaurant.address}</span>
            </div>
          )}
          {restaurant.phone && (
            <div className="flex items-center gap-3">
              <Phone className="w-4 h-4 text-amber-500 flex-shrink-0" />
              <span className="text-xs text-gray-600">{restaurant.phone}</span>
            </div>
          )}
        </div>
      </div>

      {/* Category Tabs */}
      {categories.length > 0 && (
        <div className="px-5 mt-5">
          <Tabs value={activeCategory} onValueChange={setActiveCategory}>
            <TabsList className="bg-gray-50 h-9 p-0.5 w-full overflow-x-auto flex justify-start">
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
      <div className="px-5 mt-4 space-y-2.5">
        {loadingMenu ? (
          [1, 2, 3].map((i) => (
            <div key={i} className="h-24 bg-gray-50 rounded-xl animate-pulse" />
          ))
        ) : filteredItems.length === 0 ? (
          <div className="text-center py-12">
            <div className="w-14 h-14 rounded-2xl bg-gray-100 flex items-center justify-center mx-auto mb-3">
              <ClipboardList className="w-7 h-7 text-gray-400" />
            </div>
            <p className="text-gray-400 text-sm">Aucun plat dans cette catégorie</p>
          </div>
        ) : (
          <AnimatePresence>
            {filteredItems.map((item: any) => (
              <motion.div
                key={item.id}
                initial={{ opacity: 0, y: 8 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0 }}
              >
                <MenuItemCard item={item} onAdd={() => addToCartMutation.mutate(item)} />
              </motion.div>
            ))}
          </AnimatePresence>
        )}
      </div>

      {/* Cart Footer */}
      {cartCount > 0 && (
        <motion.div
          initial={{ y: 80 }}
          animate={{ y: 0 }}
          className="fixed bottom-20 left-0 right-0 px-5 z-50"
        >
          <Link href="/cart">
            <div className="bg-emerald-500 hover:bg-emerald-600 transition-colors rounded-2xl p-4 shadow-xl shadow-emerald-200/40 flex items-center justify-between">
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
        </motion.div>
      )}
    </div>
  );
}

export default function RestaurantPage({ params }: { params: { id: string } }) {
  return (
    <Suspense fallback={<div className="flex items-center justify-center h-screen">
      <div className="w-8 h-8 border-2 border-amber-400 border-t-transparent rounded-full animate-spin" />
    </div>}>
      <RestaurantContent restaurantId={params.id} />
    </Suspense>
  );
}
