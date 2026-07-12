"use client";

import { m } from "framer-motion";
import {
  Beef, Pizza, Sandwich, Flame, Globe, Wheat, Fish, Soup, CookingPot,
  Drumstick, Salad, Leaf, CakeSlice, IceCreamCone, Croissant, Cookie,
  Coffee, CupSoda, Utensils, type LucideIcon,
} from "lucide-react";

const cuisineConfig: Record<string, { Icon: LucideIcon; color: string; bg: string }> = {
  burger:        { Icon: Beef, color: "#f97316", bg: "linear-gradient(135deg,#ff6b35,#f97316)" },
  pizza:         { Icon: Pizza, color: "#eab308", bg: "linear-gradient(135deg,#f59e0b,#eab308)" },
  kebab:         { Icon: Sandwich, color: "#84cc16", bg: "linear-gradient(135deg,#65a30d,#84cc16)" },
  tacos:         { Icon: Utensils, color: "#f59e0b", bg: "linear-gradient(135deg,#d97706,#f59e0b)" },
  mexicain:      { Icon: Flame, color: "#ef4444", bg: "linear-gradient(135deg,#dc2626,#ef4444)" },
  africain:      { Icon: Globe, color: "#22c55e", bg: "linear-gradient(135deg,#16a34a,#22c55e)" },
  arabe:         { Icon: Wheat, color: "#d97706", bg: "linear-gradient(135deg,#b45309,#d97706)" },
  sushi:         { Icon: Fish, color: "#ec4899", bg: "linear-gradient(135deg,#db2777,#ec4899)" },
  indien:        { Icon: Soup, color: "#f97316", bg: "linear-gradient(135deg,#ea580c,#f97316)" },
  chinois:       { Icon: CookingPot, color: "#dc2626", bg: "linear-gradient(135deg,#b91c1c,#dc2626)" },
  thai:          { Icon: Soup, color: "#14b8a6", bg: "linear-gradient(135deg,#0d9488,#14b8a6)" },
  poulet:        { Icon: Drumstick, color: "#ca8a04", bg: "linear-gradient(135deg,#a16207,#ca8a04)" },
  sandwich:      { Icon: Sandwich, color: "#65a30d", bg: "linear-gradient(135deg,#4d7c0f,#65a30d)" },
  hotdog:        { Icon: Sandwich, color: "#f43f5e", bg: "linear-gradient(135deg,#e11d48,#f43f5e)" },
  pates:         { Icon: CookingPot, color: "#eab308", bg: "linear-gradient(135deg,#ca8a04,#eab308)" },
  salade:        { Icon: Salad, color: "#4ade80", bg: "linear-gradient(135deg,#22c55e,#4ade80)" },
  fruits_de_mer: { Icon: Fish, color: "#06b6d4", bg: "linear-gradient(135deg,#0891b2,#06b6d4)" },
  vegan:         { Icon: Leaf, color: "#22c55e", bg: "linear-gradient(135deg,#15803d,#22c55e)" },
  dessert:       { Icon: CakeSlice, color: "#a855f7", bg: "linear-gradient(135deg,#9333ea,#a855f7)" },
  glaces:        { Icon: IceCreamCone, color: "#38bdf8", bg: "linear-gradient(135deg,#0ea5e9,#38bdf8)" },
  crepes:        { Icon: Croissant, color: "#fbbf24", bg: "linear-gradient(135deg,#f59e0b,#fbbf24)" },
  waffle:        { Icon: Cookie, color: "#f59e0b", bg: "linear-gradient(135deg,#d97706,#f59e0b)" },
  cafe:          { Icon: Coffee, color: "#92400e", bg: "linear-gradient(135deg,#78350f,#92400e)" },
  smoothie:      { Icon: CupSoda, color: "#8b5cf6", bg: "linear-gradient(135deg,#7c3aed,#8b5cf6)" },
  autre:         { Icon: Utensils, color: "#94a3b8", bg: "linear-gradient(135deg,#64748b,#94a3b8)" },
};

interface CuisineChipProps {
  type: string;
  label: string;
  isActive: boolean;
  onClick: () => void;
}

export default function CuisineChip({ type, label, isActive, onClick }: CuisineChipProps) {
  const config = cuisineConfig[type] || cuisineConfig.autre;

  return (
    <m.button
      whileTap={{ scale: 0.88 }}
      whileHover={{ scale: 1.06 }}
      onClick={onClick}
      className="flex-shrink-0 flex flex-col items-center gap-1.5"
      style={{ width: 64 }}
    >
      <div
        className="relative flex items-center justify-center transition-all duration-200"
        style={{
          width: 54,
          height: 54,
          borderRadius: 18,
          background: isActive ? config.bg : "#f8fafc",
          boxShadow: isActive
            ? `0 6px 22px ${config.color}50, 0 2px 8px ${config.color}30, inset 0 1px 0 rgba(255,255,255,0.25)`
            : "0 2px 6px rgba(0,0,0,0.05), inset 0 1px 0 rgba(255,255,255,0.8)",
          transform: isActive ? "translateY(-4px)" : "none",
          border: isActive ? `2px solid ${config.color}77` : "2px solid transparent",
        }}
      >
        {isActive && (
          <div
            className="absolute top-1.5 left-2.5 w-5 h-1.5 rounded-full blur-sm"
            style={{ background: "rgba(255,255,255,0.5)" }}
          />
        )}
        <config.Icon
          className="relative z-10"
          size={24}
          strokeWidth={2.2}
          style={{
            color: isActive ? "#ffffff" : config.color,
            filter: isActive ? "drop-shadow(0 2px 3px rgba(0,0,0,0.2))" : "none",
          }}
        />
      </div>

      <span
        className="text-[10px] font-black text-center leading-tight transition-all duration-200"
        style={{ color: isActive ? config.color : "#94a3b8" }}
      >
        {label || type}
      </span>

      {isActive && (
        <div
          className="w-1.5 h-1.5 rounded-full"
          style={{ background: config.color, marginTop: -4, boxShadow: `0 0 6px ${config.color}` }}
        />
      )}
    </m.button>
  );
}
