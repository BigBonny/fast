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

// One row, as the app's menu row: name, two-line description and price on
// the left; a square photo with a round "+" in its corner on the right.
function MenuItemCard({ item, onAdd }: MenuItemCardProps) {
  return (
    <m.div
      whileTap={{ scale: 0.98 }}
      className="flex items-start gap-4 bg-card text-card-foreground rounded-2xl p-4 border border-border hover:shadow-md transition-shadow duration-200 h-full"
    >
      <div className="flex-1 min-w-0 self-stretch flex flex-col">
        <div className="flex items-center gap-1.5">
          <h4 className="font-bold text-base leading-snug text-foreground line-clamp-2">
            {item.name}
          </h4>
          {(item.isPopular || (item.rating ?? 0) >= 4.5) && (
            <Flame className="w-4 h-4 text-fast-orange flex-shrink-0" />
          )}
        </div>
        {item.description && (
          <p className="text-sm text-muted-foreground mt-1 line-clamp-2">
            {item.description}
          </p>
        )}
        <span className="mt-auto pt-2 font-bold text-foreground tabular-nums">
          {item.price?.toFixed(2)} €
        </span>
      </div>

      <div className="relative flex-shrink-0 w-24 h-24">
        <div className="w-full h-full rounded-xl bg-muted overflow-hidden">
          {item.image ? (
            <SafeImage
              src={item.image}
              alt={item.name}
              width={96}
              height={96}
              className="w-full h-full object-cover"
            />
          ) : (
            <div className="w-full h-full flex items-center justify-center bg-muted">
              <UtensilsCrossed className="w-7 h-7 text-muted-foreground/60" />
            </div>
          )}
        </div>
        <m.button
          whileTap={{ scale: 0.9 }}
          onClick={(e) => {
            e.stopPropagation();
            onAdd();
          }}
          className="absolute -bottom-2 -right-2 w-11 h-11 rounded-full flex items-center justify-center bg-primary text-primary-foreground border-2 border-background shadow-md transition-transform hover:scale-105"
        >
          <Plus className="w-5 h-5" strokeWidth={3} />
        </m.button>
      </div>
    </m.div>
  );
}

export default memo(MenuItemCard);
