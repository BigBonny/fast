"use client";

import { memo } from "react";
import { Heart, UtensilsCrossed } from "lucide-react";
import Link from "next/link";
import { m } from "framer-motion";
import SafeImage from "@/components/SafeImage";

interface FavoritesSectionProps {
  favoriteIds?: string[];
  favorites?: any[];
  restaurants: any[];
}

function FavoritesSection({ favoriteIds, favorites, restaurants }: FavoritesSectionProps) {
  const ids = favoriteIds || favorites?.filter((f) => f.type === "restaurant").map((f) => f.reference_id) || [];
  if (!ids.length) return null;

  const favRestaurants = ids
    .map((id) => restaurants.find((r) => r.id === id))
    .filter((r): r is any => r !== undefined);

  if (favRestaurants.length === 0) return null;

  return (
    <div className="px-5 mb-6">
      <div className="flex items-center justify-between mb-3">
        <div className="flex items-center gap-1.5">
          <Heart className="w-4 h-4 text-red-400 fill-red-400" />
          <h3 className="font-bold text-gray-900">Mes Favoris</h3>
        </div>
      </div>

      <div className="flex gap-3 overflow-x-auto pb-2 scrollbar-hide -mx-1 px-1">
        {favRestaurants.map((restaurant, idx) => (
          <m.div
            key={restaurant.id}
            initial={{ opacity: 0, scale: 0.9 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ delay: idx * 0.05 }}
            whileHover={{ y: -3, scale: 1.03 }}
          >
            <Link href={`/restaurant/${restaurant.id}`}>
              <div className="flex-shrink-0 w-28 group">
                <div className="relative w-28 h-20 rounded-2xl overflow-hidden bg-gray-100 shadow-sm group-hover:shadow-md transition-all">
                  {restaurant.image ? (
                    <SafeImage
                      src={restaurant.image}
                      alt={restaurant.name}
                      width={112}
                      height={80}
                      className="w-full h-full object-cover transition-transform duration-500 group-hover:scale-110"
                    />
                  ) : (
                    <div className="w-full h-full flex items-center justify-center bg-gray-100"><UtensilsCrossed className="w-7 h-7 text-gray-300" /></div>
                  )}
                  <div className="absolute inset-0 bg-gradient-to-t from-black/30 to-transparent opacity-0 group-hover:opacity-100 transition-opacity" />
                  <div className="absolute bottom-1.5 right-1.5 w-5 h-5 bg-white rounded-full flex items-center justify-center shadow-md">
                    <Heart className="w-2.5 h-2.5 text-red-500 fill-red-500" />
                  </div>
                </div>
                <p className="text-xs font-extrabold text-gray-900 mt-1.5 truncate px-0.5">{restaurant.name}</p>
                <p className="text-[10px] font-semibold text-gray-500 px-0.5">{restaurant.normalPrepTime || 5} min</p>
              </div>
            </Link>
          </m.div>
        ))}
      </div>
    </div>
  );
}

export default memo(FavoritesSection);
