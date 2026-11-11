"use client";

import { useState, useEffect, useMemo } from "react";
import { useQuery } from "@tanstack/react-query";
import { restaurantApi } from "@/api/fastBackend";
import { getFavorites } from "@/lib/localCart";
import { ArrowLeft, Heart, HeartOff, UtensilsCrossed, Star } from "lucide-react";
import { m } from "framer-motion";
import Link from "next/link";
import SafeImage from "@/components/SafeImage";

export default function FavoritesPage() {
  const [favoriteIds, setFavoriteIds] = useState<string[]>([]);
  useEffect(() => {
    setFavoriteIds(getFavorites());
  }, []);

  const { data: restaurants = [] } = useQuery({
    queryKey: ["restaurants"],
    queryFn: () => restaurantApi.list(),
    staleTime: 5 * 60 * 1000,
    gcTime: 10 * 60 * 1000,
  });

  const favRestaurants = useMemo(() => {
    const map = new Map(restaurants.map((r: any) => [r.id, r]));
    return favoriteIds.map((id) => map.get(id)).filter((r): r is any => r !== undefined);
  }, [favoriteIds, restaurants]);

  return (
    <div className="min-h-screen bg-background pb-24">
      {/* Header */}
      <div className="bg-background/90 backdrop-blur-md px-4 sm:px-6 py-3 border-b border-border sticky top-0 z-20">
        <div className="max-w-2xl mx-auto flex items-center gap-3">
          <Link href="/" className="w-11 h-11 rounded-full border border-border bg-card flex items-center justify-center hover:bg-muted transition-colors shrink-0">
            <ArrowLeft className="w-5 h-5 text-foreground" />
          </Link>
          <div className="flex items-center gap-2">
            <Heart className="w-5 h-5 text-fast-rose fill-fast-rose" />
            <h1 className="font-display font-bold text-xl text-foreground">Mes favoris</h1>
          </div>
        </div>
      </div>

      {favRestaurants.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-24 px-4">
          <div className="w-24 h-24 rounded-full bg-muted flex items-center justify-center mb-6">
            <HeartOff className="w-10 h-10 text-muted-foreground" />
          </div>
          <h2 className="font-display font-bold text-foreground text-2xl mb-2">Aucun favori</h2>
          <p className="text-sm text-muted-foreground text-center mb-7 max-w-xs">
            Ajoutez des restaurants à vos favoris pour les retrouver ici
          </p>
          <Link href="/">
            <m.button whileTap={{ scale: 0.98 }} className="btn-neon">
              Découvrir des restaurants
            </m.button>
          </Link>
        </div>
      ) : (
        <div className="px-4 sm:px-6 pt-6 space-y-3 max-w-2xl mx-auto">
          {favRestaurants.map((restaurant: any, index: number) => (
            <m.div
              key={restaurant.id}
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: index * 0.05 }}
            >
              <Link href={`/restaurant/${restaurant.id}`} className="block">
                <div className="bg-card rounded-2xl p-3 border border-border flex items-center gap-4 card-lift">
                  <div className="w-24 h-24 rounded-xl overflow-hidden bg-muted flex-shrink-0">
                    {restaurant.image ? (
                      <SafeImage src={restaurant.image} alt={restaurant.name} width={112} height={112} className="w-full h-full object-cover" />
                    ) : (
                      <div className="w-full h-full flex items-center justify-center bg-muted"><UtensilsCrossed className="w-7 h-7 text-muted-foreground" /></div>
                    )}
                  </div>
                  <div className="flex-1 min-w-0">
                    <h3 className="font-display font-bold text-lg text-foreground truncate">{restaurant.name}</h3>
                    <p className="flex items-center gap-1 text-sm text-muted-foreground mt-1 tabular-nums">
                      {restaurant.normalPrepTime || 5} min • {restaurant.rating || "4.5"} <Star className="w-3.5 h-3.5 text-fast-gold fill-fast-gold" />
                    </p>
                  </div>
                </div>
              </Link>
            </m.div>
          ))}
        </div>
      )}
    </div>
  );
}
