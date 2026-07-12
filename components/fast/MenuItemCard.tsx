"use client";

import { memo } from "react";
import { m } from "framer-motion";
import { Plus, Flame, UtensilsCrossed } from "lucide-react";
import SafeImage from "@/components/SafeImage";

interface MenuItem {
  id: string;
  name: string;
  image?: string;
  description?: string;
  price: number;
  isPopular?: boolean;
  rating?: number;
}

interface MenuItemCardProps {
  item: MenuItem;
  onAdd: () => void;
}

function MenuItemCard({ item, onAdd }: MenuItemCardProps) {
  return (
    <m.div
      whileTap={{ scale: 0.98 }}
      className="flex items-center gap-3 bg-white rounded-xl p-3 border border-gray-100 hover:border-amber-200 hover:shadow-md hover:shadow-amber-100/40 transition-all duration-200 h-full"
    >
      <div className="w-20 h-20 rounded-xl bg-gray-50 overflow-hidden flex-shrink-0">
        {item.image ? (
          <SafeImage
            src={item.image}
            alt={item.name}
            width={80}
            height={80}
            className="w-full h-full object-cover"
          />
        ) : (
          <div className="w-full h-full flex items-center justify-center bg-gray-100">
            <UtensilsCrossed className="w-7 h-7 text-gray-300" />
          </div>
        )}
      </div>

      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-1.5">
          <h4 className="font-semibold text-sm text-gray-900 truncate">
            {item.name}
          </h4>
          {(item.isPopular || (item.rating && item.rating >= 4.5)) && (
            <Flame className="w-3.5 h-3.5 text-orange-400 flex-shrink-0" />
          )}
        </div>
        {item.description && (
          <p className="text-xs text-gray-400 mt-0.5 line-clamp-2">
            {item.description}
          </p>
        )}
        <div className="flex items-center justify-between mt-2">
          <span className="font-bold text-gray-900">
            {item.price?.toFixed(2)} €
          </span>
          <m.button
            whileTap={{ scale: 0.9 }}
            onClick={(e) => {
              e.stopPropagation();
              onAdd();
            }}
            className="w-8 h-8 rounded-xl flex items-center justify-center text-white shadow-sm transition-colors"
            style={{ background: "linear-gradient(135deg, #14b8a6, #06b6d4)" }}
          >
            <Plus className="w-4 h-4" strokeWidth={3} />
          </m.button>
        </div>
      </div>
    </m.div>
  );
}

export default memo(MenuItemCard);
