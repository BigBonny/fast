"use client";

import { memo } from "react";
import { motion } from "framer-motion";
import { Star, Clock, Heart, Flame, Beef, Pizza, Fish, Utensils, Leaf, Sandwich, type LucideIcon } from "lucide-react";
import { Badge } from "@/components/ui/badge";
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

const cuisineVisuals: Record<string, { Icon: LucideIcon; bg: string }> = {
  burger: { Icon: Beef, bg: "linear-gradient(135deg,#fbbf24,#f97316)" },
  pizza: { Icon: Pizza, bg: "linear-gradient(135deg,#f87171,#dc2626)" },
  sushi: { Icon: Fish, bg: "linear-gradient(135deg,#38bdf8,#0284c7)" },
  tacos: { Icon: Utensils, bg: "linear-gradient(135deg,#fb923c,#ea580c)" },
  vegan: { Icon: Leaf, bg: "linear-gradient(135deg,#4ade80,#16a34a)" },
  kebab: { Icon: Sandwich, bg: "linear-gradient(135deg,#fbbf24,#d97706)" },
  français: { Icon: Utensils, bg: "linear-gradient(135deg,#a78bfa,#7c3aed)" },
};

function getCuisineVisual(type?: string) {
  return (type && cuisineVisuals[type.toLowerCase()]) || { Icon: Utensils, bg: "linear-gradient(135deg,#94a3b8,#64748b)" };
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
  return (
    <motion.div
      whileTap={{ scale: 0.97 }}
      whileHover={{ y: -4, scale: 1.01 }}
      transition={{ type: "spring", stiffness: 400, damping: 25 }}
      onClick={onClick}
      className="bg-white dark:bg-slate-900 rounded-2xl overflow-hidden shadow-sm border border-gray-100 dark:border-slate-800 hover:shadow-xl cursor-pointer group"
    >
      <div className="relative h-40 bg-gradient-to-br from-gray-100 to-gray-50 dark:from-slate-800 dark:to-slate-900 overflow-hidden">
        {restaurant.image ? (
          <SafeImage
            src={restaurant.image}
            alt={restaurant.name}
            fill
            sizes="(max-width: 640px) 50vw, (max-width: 1024px) 33vw, 25vw"
            className="object-cover transition-transform duration-500 group-hover:scale-110"
          />
        ) : (
          <div className="w-full h-full flex items-center justify-center" style={{ background: getCuisineVisual(restaurant.cuisineType).bg }}>
            {(() => { const V = getCuisineVisual(restaurant.cuisineType).Icon; return <V className="w-14 h-14 text-white/90 drop-shadow-lg" strokeWidth={1.6} />; })()}
          </div>
        )}
        <div className="absolute inset-0 bg-gradient-to-t from-black/50 via-transparent to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300" />

        {restaurant.cuisineType && (
          <span className="absolute bottom-3 left-3 text-[10px] font-black uppercase tracking-wide text-white bg-slate-900/70 backdrop-blur-sm px-2 py-0.5 rounded-lg border border-white/10">
            {restaurant.cuisineType}
          </span>
        )}
        {restaurant.isRushMode && (
          <Badge className="absolute bottom-3 right-3 bg-slate-900/80 backdrop-blur-sm text-orange-400 font-black text-[10px] px-2 py-0.5 rounded-lg shadow-lg border border-orange-500/30">
            <Flame className="w-3 h-3 mr-0.5" /> Rush
          </Badge>
        )}
        {restaurant.isActive === false && (
          <div className="absolute inset-0 bg-slate-900/70 backdrop-blur-[2px] flex items-center justify-center">
            <span className="text-white font-bold text-sm px-4 py-1.5 rounded-full bg-slate-900/80 border border-white/20">
              Fermé
            </span>
          </div>
        )}
        {onToggleFavorite && (
          <motion.button
            whileTap={{ scale: 0.75 }}
            onClick={(e) => { e.stopPropagation(); e.preventDefault(); onToggleFavorite?.(restaurant); }}
            className="absolute top-2.5 right-2.5 w-8 h-8 bg-white/95 dark:bg-slate-900/95 backdrop-blur-sm rounded-full flex items-center justify-center shadow-md hover:shadow-lg transition-all hover:scale-110 border border-gray-100 dark:border-slate-700"
          >
            <Heart
              className={`w-4 h-4 transition-all duration-300 ${isFavorite ? "text-red-500 fill-red-500 scale-110" : "text-gray-400 hover:text-red-400"}`}
            />
          </motion.button>
        )}
      </div>

      <div className="p-3.5">
        <div className="flex items-start justify-between gap-2">
          <h3 className="font-extrabold text-gray-900 dark:text-white text-[15px] leading-tight">
            {restaurant.name}
          </h3>
          {restaurant.rating ? (
            <div className="flex items-center gap-0.5 bg-amber-50 dark:bg-amber-500/10 px-1.5 py-0.5 rounded-md shrink-0">
              <Star className="w-3 h-3 text-amber-400 fill-amber-400" />
              <span className="text-xs font-black text-amber-700 dark:text-amber-400">
                {restaurant.rating}
              </span>
              {restaurant.reviewsCount ? (
                <span className="text-[10px] text-amber-500/70 font-semibold">({restaurant.reviewsCount})</span>
              ) : null}
            </div>
          ) : null}
        </div>

        {restaurant.description && (
          <p className="text-xs text-gray-500 dark:text-slate-400 mt-1 line-clamp-1">
            {restaurant.description}
          </p>
        )}

        <div className="flex items-center justify-between mt-2.5">
          <div className="flex items-center gap-1 text-gray-500 dark:text-slate-400 bg-gray-100 dark:bg-slate-800 px-2 py-1 rounded-lg">
            <Clock className="w-3.5 h-3.5" />
            <span className="text-[11px] font-bold">
              {restaurant.normalPrepTime || 5} min
            </span>
          </div>
          <div className="flex items-center gap-1 text-[#00c8b3]">
            <span className="text-[11px] font-black uppercase tracking-wide">Fast</span>
            <div className="w-2 h-2 rounded-full bg-[#00c8b3] shadow-[0_0_8px_#00c8b3]" />
          </div>
        </div>
      </div>
    </motion.div>
  );
}

export default memo(RestaurantCard);
