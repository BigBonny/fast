"use client";

import { m } from "framer-motion";
import {
  Beef, Pizza, Sandwich, Flame, Globe, Wheat, Fish, Soup, CookingPot,
  Drumstick, Salad, Leaf, CakeSlice, IceCreamCone, Croissant, Cookie,
  Coffee, CupSoda, Utensils, type LucideIcon,
} from "lucide-react";

const cuisineIcons: Record<string, LucideIcon> = {
  burger: Beef,
  pizza: Pizza,
  kebab: Sandwich,
  tacos: Utensils,
  mexicain: Flame,
  africain: Globe,
  arabe: Wheat,
  sushi: Fish,
  indien: Soup,
  chinois: CookingPot,
  thai: Soup,
  poulet: Drumstick,
  sandwich: Sandwich,
  hotdog: Sandwich,
  pates: CookingPot,
  salade: Salad,
  fruits_de_mer: Fish,
  vegan: Leaf,
  dessert: CakeSlice,
  glaces: IceCreamCone,
  crepes: Croissant,
  waffle: Cookie,
  cafe: Coffee,
  smoothie: CupSoda,
  autre: Utensils,
};

interface CuisineChipProps {
  type: string;
  label: string;
  isActive: boolean;
  onClick: () => void;
}

// Category tile, as in the app: a neutral tile with a line icon and a label
// under it; the selected one turns rose.
export default function CuisineChip({ type, label, isActive, onClick }: CuisineChipProps) {
  const Icon = cuisineIcons[type] || cuisineIcons.autre;

  return (
    <m.button
      whileTap={{ scale: 0.94 }}
      onClick={onClick}
      aria-pressed={isActive}
      className="flex-shrink-0 flex flex-col items-center gap-1.5 w-[72px]"
    >
      <div
        className={`flex items-center justify-center w-14 h-14 rounded-2xl border transition-colors duration-200 ${
          isActive
            ? "chip-on"
            : "bg-card border-border text-foreground hover:bg-muted"
        }`}
      >
        <Icon size={24} strokeWidth={1.8} />
      </div>

      <span
        className={`w-full text-xs text-center leading-tight truncate transition-colors duration-200 ${
          isActive ? "font-bold text-fast-rose" : "font-semibold text-muted-foreground"
        }`}
      >
        {label || type}
      </span>
    </m.button>
  );
}
