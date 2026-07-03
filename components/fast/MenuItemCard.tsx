"use client";

import { motion } from "framer-motion";
import { Plus, Flame } from "lucide-react";

interface MenuItem {
  id: string;
  name: string;
  image?: string;
  image_url?: string;
  description?: string;
  price: number;
  isPopular?: boolean;
  is_popular?: boolean;
  rating?: number;
}

interface MenuItemCardProps {
  item: MenuItem;
  onAdd: () => void;
}

export default function MenuItemCard({ item, onAdd }: MenuItemCardProps) {
  return (
    <motion.div
      whileTap={{ scale: 0.98 }}
      className="flex items-center gap-3 bg-white rounded-xl p-3 border border-gray-50 hover:border-amber-100 transition-colors"
    >
      <div className="w-20 h-20 rounded-xl bg-gray-50 overflow-hidden flex-shrink-0">
        {(item.image || item.image_url) ? (
          <img
            src={item.image || item.image_url}
            alt={item.name}
            className="w-full h-full object-cover"
          />
        ) : (
          <div className="w-full h-full flex items-center justify-center text-3xl opacity-30">
            🍽️
          </div>
        )}
      </div>

      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-1.5">
          <h4 className="font-semibold text-sm text-gray-900 truncate">
            {item.name}
          </h4>
          {(item.isPopular || item.is_popular || (item.rating && item.rating >= 4.5)) && (
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
          <motion.button
            whileTap={{ scale: 0.9 }}
            onClick={(e) => {
              e.stopPropagation();
              onAdd();
            }}
            className="w-8 h-8 rounded-xl flex items-center justify-center text-white shadow-sm transition-colors"
            style={{ background: "linear-gradient(135deg, #14b8a6, #06b6d4)" }}
          >
            <Plus className="w-4 h-4" strokeWidth={3} />
          </motion.button>
        </div>
      </div>
    </motion.div>
  );
}
