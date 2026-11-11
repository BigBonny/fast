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

  // The section title and "view all" link are rendered by the page.
  return (
    <div className="flex gap-3 overflow-x-auto pb-2 scrollbar-hide -mx-4 px-4 md:mx-0 md:px-0">
      {favRestaurants.map((restaurant, idx) => (
        <m.div
          key={restaurant.id}
          className="flex-shrink-0"
          initial={{ opacity: 0, scale: 0.95 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ delay: idx * 0.05 }}
        >
          <Link href={`/restaurant/${restaurant.id}`} className="block w-36 group">
            <div className="relative w-36 h-24 rounded-xl overflow-hidden bg-muted border border-border">
              {restaurant.image ? (
                <SafeImage
                  src={restaurant.image}
                  alt={restaurant.name}
                  width={144}
                  height={96}
                  className="w-full h-full object-cover transition-transform duration-500 group-hover:scale-105"
                />
              ) : (
                <div className="w-full h-full flex items-center justify-center bg-muted">
                  <UtensilsCrossed className="w-7 h-7 text-muted-foreground/60" />
                </div>
              )}
              <div className="absolute top-1.5 right-1.5 w-6 h-6 bg-white/95 rounded-full flex items-center justify-center shadow-sm">
                <Heart className="w-3 h-3 text-fast-rose fill-fast-rose" />
              </div>
            </div>
            <p className="text-sm font-bold text-foreground mt-2 truncate">{restaurant.name}</p>
            <p className="text-xs font-medium text-muted-foreground tabular-nums">{restaurant.normalPrepTime || 5} min</p>
          </Link>
        </m.div>
      ))}
    </div>
  );
}

export default memo(FavoritesSection);
