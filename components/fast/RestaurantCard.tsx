"use client";

import { memo } from "react";
import { m } from "framer-motion";
import { Star, Heart, Flame, Beef, Pizza, Fish, Utensils, Leaf, Sandwich, type LucideIcon } from "lucide-react";
import SafeImage from "@/components/SafeImage";

interface Restaurant {
  id: string;
  name: string;
  image?: string;
  description?: string;
  rating?: number;
  reviewsCount?: number;
  cuisineType?: string;
  normalPrepTime?: number;
  rushPrepTime?: number;
  isActive?: boolean;
  isRushMode?: boolean;
}

// Placeholder pictogram when a restaurant has no photo.
const cuisineIcons: Record<string, LucideIcon> = {
  burger: Beef,
  pizza: Pizza,
  sushi: Fish,
  tacos: Utensils,
  vegan: Leaf,
  kebab: Sandwich,
  français: Utensils,
};

function getCuisineIcon(type?: string): LucideIcon {
  return (type && cuisineIcons[type.toLowerCase()]) || Utensils;
}

interface RestaurantCardProps {
  restaurant: Restaurant;
  onClick?: () => void;
  isFavorite?: boolean;
  onToggleFavorite?: (restaurant: Restaurant) => void;
}

function RestaurantCard({
  restaurant,
  onClick,
  isFavorite,
  onToggleFavorite
}: RestaurantCardProps) {
  const PlaceholderIcon = getCuisineIcon(restaurant.cuisineType);

  return (
    <m.div
      whileTap={{ scale: 0.98 }}
      whileHover={{ y: -3 }}
      transition={{ type: "spring", stiffness: 400, damping: 25 }}
      onClick={onClick}
      className="h-full bg-card text-card-foreground rounded-2xl overflow-hidden border border-border shadow-sm hover:shadow-lg transition-shadow cursor-pointer group"
    >
      {/* Photo: 16:9, only the heart sits on it. */}
      <div className="relative aspect-video bg-muted overflow-hidden">
        {restaurant.image ? (
          <SafeImage
            src={restaurant.image}
            alt={restaurant.name}
            fill
            sizes="(max-width: 640px) 100vw, (max-width: 1280px) 50vw, 33vw"
            className="object-cover transition-transform duration-500 group-hover:scale-105"
          />
        ) : (
          <div className="w-full h-full flex items-center justify-center bg-muted">
            <PlaceholderIcon className="w-12 h-12 text-muted-foreground/60" strokeWidth={1.5} />
          </div>
        )}

        {restaurant.isActive === false && (
          <div className="absolute inset-0 bg-black/60 flex items-center justify-center">
            <span className="text-white font-bold text-sm px-4 py-1.5 rounded-full bg-black/70 border border-white/20">
              Fermé
            </span>
          </div>
        )}
        {onToggleFavorite && (
          <m.button
            whileTap={{ scale: 0.8 }}
            onClick={(e) => { e.stopPropagation(); e.preventDefault(); onToggleFavorite?.(restaurant); }}
            className="absolute top-2 right-2 w-11 h-11 bg-white/95 rounded-full flex items-center justify-center shadow-md transition-transform hover:scale-105"
          >
            <Heart
              className={`w-5 h-5 transition-colors duration-200 ${isFavorite ? "text-fast-rose fill-fast-rose" : "text-zinc-500"}`}
            />
          </m.button>
        )}
      </div>

      <div className="p-4">
        <h3 className="font-extrabold text-foreground text-base leading-tight">
          {restaurant.name}
        </h3>

        {/* Facts line: ★ 4.7 (120) · 12 min */}
        <div className="flex flex-wrap items-center gap-x-1.5 gap-y-0.5 mt-1.5 text-sm font-semibold text-foreground tabular-nums">
          {restaurant.rating ? (
            <>
              <span className="inline-flex items-center gap-1">
                <Star className="w-3.5 h-3.5 text-fast-gold fill-fast-gold" />
                {restaurant.rating}
                {restaurant.reviewsCount ? (
                  <span className="text-muted-foreground font-medium">({restaurant.reviewsCount})</span>
                ) : null}
              </span>
              <span className="text-muted-foreground" aria-hidden="true">·</span>
            </>
          ) : null}
          <span>{restaurant.normalPrepTime || 5} min</span>
        </div>

        {restaurant.description && (
          <p className="text-sm text-muted-foreground mt-1.5 line-clamp-2">
            {restaurant.description}
          </p>
        )}

        {(restaurant.cuisineType || restaurant.isRushMode) && (
          <div className="flex flex-wrap items-center gap-1.5 mt-3">
            {restaurant.cuisineType && (
              <span className="text-xs font-semibold capitalize text-muted-foreground bg-muted px-2.5 py-1 rounded-full">
                {restaurant.cuisineType}
              </span>
            )}
            {restaurant.isRushMode && (
              <span className="inline-flex items-center gap-1 text-xs font-bold text-fast-ink bg-fast-gold px-2.5 py-1 rounded-full">
                <Flame className="w-3 h-3" /> Rush
              </span>
            )}
          </div>
        )}
      </div>
    </m.div>
  );
}

export default memo(RestaurantCard);
