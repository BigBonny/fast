"use client";

import { useState, useEffect } from "react";
import { useQuery } from "@tanstack/react-query";
import { restaurantApi } from "@/api/fastBackend";
import { getFavorites } from "@/lib/localCart";
import { ArrowLeft, Heart, HeartOff, UtensilsCrossed } from "lucide-react";
import { motion } from "framer-motion";
import Link from "next/link";

export default function FavoritesPage() {
  const [favoriteIds, setFavoriteIds] = useState<string[]>([]);
  useEffect(() => {
    setFavoriteIds(getFavorites());
  }, []);

  const { data: restaurants = [] } = useQuery({
    queryKey: ["restaurants"],
    queryFn: () => restaurantApi.list(),
  });

  const favRestaurants = favoriteIds
    .map((id) => restaurants.find((r: any) => r.id === id))
    .filter((r): r is any => r !== undefined);

  return (
    <div className="min-h-screen bg-gray-50 pb-20">
      {/* Header */}
      <div className="bg-white px-5 py-4 flex items-center gap-3 border-b border-gray-100 sticky top-0 z-20">
        <Link href="/" className="w-9 h-9 bg-gray-50 rounded-xl flex items-center justify-center">
          <ArrowLeft className="w-4 h-4 text-gray-600" />
        </Link>
        <div className="flex items-center gap-2">
          <Heart className="w-5 h-5 text-red-400 fill-red-400" />
          <h1 className="font-bold text-gray-900">Mes favoris</h1>
        </div>
      </div>

      {favRestaurants.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-24 px-5">
          <div className="w-20 h-20 rounded-3xl bg-red-50 flex items-center justify-center mb-4">
            <HeartOff className="w-9 h-9 text-red-300" />
          </div>
          <h2 className="font-bold text-gray-900 text-lg mb-1">Aucun favori</h2>
          <p className="text-sm text-gray-400 text-center mb-6">
            Ajoutez des restaurants à vos favoris pour les retrouver ici
          </p>
          <Link href="/">
            <motion.button
              whileTap={{ scale: 0.98 }}
              className="px-6 py-3 rounded-xl font-bold text-white"
              style={{ background: "linear-gradient(135deg, #7c3aed, #06b6d4)" }}
            >
              Découvrir des restaurants
            </motion.button>
          </Link>
        </div>
      ) : (
        <div className="px-5 pt-4 space-y-3">
          {favRestaurants.map((restaurant: any, index: number) => (
            <motion.div
              key={restaurant.id}
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: index * 0.05 }}
            >
              <Link href={`/restaurant/${restaurant.id}`}>
                <div className="bg-white rounded-2xl overflow-hidden shadow-sm border border-gray-100 flex">
                  <div className="w-28 h-28 bg-gray-50 flex-shrink-0">
                    {restaurant.image_url ? (
                      <img src={restaurant.image_url} alt={restaurant.name} className="w-full h-full object-cover" />
                    ) : (
                      <div className="w-full h-full flex items-center justify-center bg-gray-100"><UtensilsCrossed className="w-7 h-7 text-gray-300" /></div>
                    )}
                  </div>
                  <div className="p-4 flex-1">
                    <h3 className="font-bold text-gray-900">{restaurant.name}</h3>
                    <p className="text-xs text-gray-400 mt-1">
                      {restaurant.delivery_time_min || 5}-{restaurant.delivery_time_max || 15} min • {restaurant.rating || "4.5"} ⭐
                    </p>
                  </div>
                </div>
              </Link>
            </motion.div>
          ))}
        </div>
      )}
    </div>
  );
}
