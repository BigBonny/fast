"use client";

import React, { useState, useEffect, useRef, useMemo, useCallback } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { restaurantApi, orderApi } from "@/api/fastBackend";
import { getFavorites, toggleFavorite } from "@/lib/localCart";
import { Search, Menu, X, Store, ShoppingCart, User, Zap, Users, Sparkles, AlertTriangle, SearchX, UtensilsCrossed, type LucideIcon } from "lucide-react";
import { Input } from "@/components/ui/input";
import { m, AnimatePresence } from "framer-motion";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/AuthContext";
import { useI18n } from "@/lib/i18n";
import CuisineChip from "@/components/fast/CuisineChip";
import RestaurantCard from "@/components/fast/RestaurantCard";
import FavoritesSection from "@/components/fast/FavoritesSection";
import SideMenu from "@/components/fast/SideMenu";

function useDebounce<T>(value: T, delay = 200) {
  const [debounced, setDebounced] = useState(value);
  useEffect(() => {
    const t = setTimeout(() => setDebounced(value), delay);
    return () => clearTimeout(t);
  }, [value, delay]);
  return debounced;
}

const cuisineTypes = [
  { type: "burger", key: "cat_burger" },
  { type: "pizza", key: "cat_pizza" },
  { type: "kebab", key: "cat_kebab" },
  { type: "tacos", key: "cat_tacos" },
  { type: "mexicain", key: "cat_mexicain" },
  { type: "africain", key: "cat_africain" },
  { type: "arabe", key: "cat_arabe" },
  { type: "sushi", key: "cat_sushi" },
  { type: "indien", key: "cat_indien" },
  { type: "chinois", key: "cat_chinois" },
  { type: "thai", key: "cat_thai" },
  { type: "poulet", key: "cat_poulet" },
  { type: "sandwich", key: "cat_sandwich" },
  { type: "hotdog", key: "cat_hotdog" },
  { type: "pates", key: "cat_pates" },
  { type: "salade", key: "cat_salade" },
  { type: "vegan", key: "cat_vegan" },
  { type: "dessert", key: "cat_dessert" },
  { type: "crepes", key: "cat_crepes" },
  { type: "waffle", key: "cat_waffle" },
  { type: "cafe", key: "cat_cafe" },
  { type: "smoothie", key: "cat_smoothie" },
];

const quickCategories: { labelKey: string; subtitleKey: string; Icon: LucideIcon; id: string; action: string }[] = [
  { labelKey: "promo_drop_t", subtitleKey: "promo_drop_s", Icon: Zap, id: "drop", action: "orders" },
  { labelKey: "promo_friends_t", subtitleKey: "promo_friends_s", Icon: Users, id: "amis", action: "group" },
  { labelKey: "promo_surprise_t", subtitleKey: "promo_surprise_s", Icon: Sparkles, id: "surprise", action: "surprise" },
];

export default function Home() {
  const { user, isAuthenticated } = useAuth();
  const { t } = useI18n();
  const [activeCuisine, setActiveCuisine] = useState<string | null>(null);
  const [search, setSearch] = useState("");
  const [showSuggestions, setShowSuggestions] = useState(false);
  const [activeBanner, setActiveBanner] = useState(0);
  const [showMenu, setShowMenu] = useState(false);
  const [mounted, setMounted] = useState(false);
  const queryClient = useQueryClient();
  const router = useRouter();
  const searchRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    setMounted(true);
  }, []);

  useEffect(() => {
    const timer = setInterval(() => {
      setActiveBanner((prev) => (prev + 1) % quickCategories.length);
    }, 2500);
    return () => clearInterval(timer);
  }, []);

  useEffect(() => {
    const handler = (e: MouseEvent) => {
      if (searchRef.current && !searchRef.current.contains(e.target as Node)) {
        setShowSuggestions(false);
      }
    };
    document.addEventListener("mousedown", handler);
    return () => document.removeEventListener("mousedown", handler);
  }, []);

  const { data: restaurants = [], isLoading, error } = useQuery({
    queryKey: ["restaurants"],
    queryFn: () => restaurantApi.list(),
    enabled: mounted,
    staleTime: 5 * 60 * 1000,
    gcTime: 10 * 60 * 1000,
  });

  const [favorites, setFavorites] = useState<string[]>([]);
  useEffect(() => {
    if (mounted) setFavorites(getFavorites());
  }, [mounted]);

  const { data: orders = [] } = useQuery({
    queryKey: ["orders"],
    queryFn: () => orderApi.mine(),
    refetchInterval: 15000,
    enabled: mounted && isAuthenticated,
    staleTime: 30 * 1000,
    gcTime: 5 * 60 * 1000,
  });

  const activeOrder = orders.find(
    (o: any) => o.status !== "COMPLETED" && o.status !== "CANCELLED"
  );

  const toggleFavoriteMutation = useMutation({
    mutationFn: useCallback(async (restaurant: any) => {
      const next = toggleFavorite(restaurant.id);
      setFavorites(next);
      return next;
    }, []),
  });

  const handleToggleFavorite = useCallback((restaurant: any) => {
    toggleFavoriteMutation.mutate(restaurant);
  }, [toggleFavoriteMutation]);

  const debouncedSearch = useDebounce(search, 200);

  const suggestions = useMemo(() => {
    if (!debouncedSearch.trim()) return [];
    const q = debouncedSearch.toLowerCase();
    const restSuggestions = restaurants
      .filter((r: any) => r.name?.toLowerCase().includes(q))
      .slice(0, 4)
      .map((r: any) => ({ type: "restaurant", label: r.name, id: r.id }));
    const cuisineSuggestions = cuisineTypes
      .filter((c) => t(c.key).toLowerCase().includes(q) || c.type.includes(q))
      .slice(0, 3)
      .map((c) => ({ type: "cuisine", label: t(c.key), cuisine: c.type }));
    return [...cuisineSuggestions, ...restSuggestions];
  }, [debouncedSearch, restaurants, t]);

  const handleSearchChange = useCallback((value: string) => {
    setSearch(value);
    setShowSuggestions(value.trim().length > 0);
  }, []);

  const handleSuggestionClick = useCallback((suggestion: any) => {
    setShowSuggestions(false);
    setSearch("");
    if (suggestion.type === "restaurant" && suggestion.id) {
      router.push(`/restaurant/${suggestion.id}`);
    } else if (suggestion.type === "cuisine" && suggestion.cuisine) {
      setActiveCuisine(suggestion.cuisine);
    }
  }, [router]);

  const handleBannerClick = useCallback((action: string) => {
    if (action === "orders") {
      router.push("/orders");
    } else if (action === "group") {
      router.push("/group-order");
    } else if (action === "surprise") {
      const open = restaurants.filter((r: any) => r.isActive !== false);
      if (open.length > 0) {
        const rand = open[Math.floor(Math.random() * open.length)];
        router.push(`/restaurant/${rand.id}`);
      }
    }
  }, [router, restaurants]);

  const filtered = useMemo(() => {
    const term = debouncedSearch.toLowerCase();
    return restaurants.filter((r: any) => {
      const matchCuisine = !activeCuisine || r.cuisineType === activeCuisine;
      const matchSearch =
        !term ||
        r.name?.toLowerCase().includes(term) ||
        r.description?.toLowerCase().includes(term) ||
        r.cuisineType?.toLowerCase().includes(term);
      return matchCuisine && matchSearch;
    });
  }, [activeCuisine, debouncedSearch, restaurants]);

  if (!mounted) {
    return <div className="pb-6 min-h-screen bg-background" />;
  }

  return (
    <div className="pb-6 min-h-screen bg-background text-foreground">
      <SideMenu isOpen={showMenu} onClose={() => setShowMenu(false)} />


      {/* ── HERO HEADER ── */}
      <div className="night-band relative z-30 rounded-b-[28px] md:rounded-none">
        {/* Mobile top bar — hidden on desktop */}
        <div className="md:hidden flex items-center justify-between px-4 pt-4">
          <button
            onClick={() => setShowMenu(true)}
            className="w-11 h-11 rounded-full flex items-center justify-center bg-white/10 hover:bg-white/15 transition-colors"
          >
            <Menu className="w-5 h-5 text-white" />
          </button>
          <div className="flex items-center gap-2">
            {user?.role === "RESTAURANT" && (
              <Link href="/partner/orders">
                <div className="px-4 h-11 rounded-full flex items-center gap-1.5 text-xs font-bold text-white border border-white/25 hover:bg-white/10 transition-colors">
                  <Store className="w-4 h-4" />
                  {t("pro_space")}
                </div>
              </Link>
            )}
            <Link href="/cart">
              <button className="w-11 h-11 rounded-full flex items-center justify-center bg-white/10 hover:bg-white/15 transition-colors">
                <ShoppingCart className="w-5 h-5 text-white" />
              </button>
            </Link>
            <Link href="/profile">
              <div className="w-11 h-11 rounded-full flex items-center justify-center text-sm font-extrabold bg-primary text-primary-foreground">
                {user?.name ? user.name[0].toUpperCase() : <User className="w-5 h-5" />}
              </div>
            </Link>
          </div>
        </div>

        <div className="max-w-2xl mx-auto px-4 md:px-8 pt-6 pb-7 md:pt-16 md:pb-14 md:text-center">
          {/* Wordmark — mobile only (the desktop navbar carries it) */}
          <div className="md:hidden mb-1">
            <span className="text-neon inline-block font-black text-4xl italic tracking-tight pr-1.5">
              <span className="notranslate" translate="no">FAST</span>
            </span>
          </div>

          <p className="on-night-muted text-xs font-bold tracking-[0.2em] uppercase">{t("tagline")}</p>

          <h1 className="font-display font-extrabold text-white text-4xl md:text-6xl leading-[1.08] mt-4 md:mt-5">
            {t("hero_1")}{" "}
            <span className="text-neon italic pr-1.5">{t("hero_2")}</span>{" "}
            {t("hero_3")}
          </h1>
          <p className="on-night-muted text-sm md:text-base mt-3">{t("hero_sub")}</p>

          {/* Search avec autocomplétion */}
          <div className="relative mt-6 md:mt-8 text-left" ref={searchRef}>
            <div className="relative">
              <Search className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-zinc-500 z-10 pointer-events-none" />
              <Input
                value={search}
                onChange={(e) => handleSearchChange(e.target.value)}
                onFocus={() => search && setShowSuggestions(suggestions.length > 0)}
                placeholder={t("search_ph")}
                className="pl-12 pr-12 h-12 md:h-14 rounded-full border-0 bg-white text-fast-ink placeholder:text-zinc-500 text-base md:text-base shadow-lg focus-visible:ring-2 focus-visible:ring-fast-rose"
              />
              {search && (
                <button onClick={() => { setSearch(""); setShowSuggestions(false); }}
                  className="absolute right-1 top-1/2 -translate-y-1/2 w-11 h-11 rounded-full flex items-center justify-center text-zinc-500 hover:text-fast-ink transition-colors">
                  <X className="w-4 h-4" />
                </button>
              )}
            </div>

            {/* Suggestions dropdown */}
            <AnimatePresence>
              {showSuggestions && suggestions.length > 0 && (
                <m.div
                  initial={{ opacity: 0, y: -8 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, y: -8 }}
                  className="absolute left-0 right-0 top-full mt-2 rounded-2xl overflow-hidden shadow-2xl z-50 bg-popover text-popover-foreground border border-border"
                >
                  {suggestions.map((s, i) => (
                    <button key={i} onClick={() => handleSuggestionClick(s)}
                      className="w-full flex items-center gap-3 px-4 py-3 text-left hover:bg-muted transition-colors border-b border-border last:border-0">
                      <span className="w-10 h-10 rounded-full bg-muted flex items-center justify-center shrink-0">
                        {s.type === "cuisine" ? <UtensilsCrossed className="w-4 h-4 text-muted-foreground" /> : <Store className="w-4 h-4 text-muted-foreground" />}
                      </span>
                      <div className="min-w-0">
                        <p className="text-foreground text-sm font-semibold truncate">{s.label}</p>
                        <p className="text-muted-foreground text-xs">{s.type === "cuisine" ? t("sugg_category") : t("sugg_restaurant")}</p>
                      </div>
                    </button>
                  ))}
                </m.div>
              )}
            </AnimatePresence>
          </div>
        </div>
      </div>

      {/* ── BODY ── */}
      <div className="max-w-screen-xl mx-auto px-4 md:px-8 pt-8 md:pt-10 pb-8 md:flex md:gap-10">

        {/* ── DESKTOP SIDEBAR ── */}
        <aside className="hidden md:flex flex-col gap-10 w-60 shrink-0">
          {/* Promo cards (stacked on desktop): the lead one on the night surface */}
          <div className="space-y-3">
            {quickCategories.map((cat, i) => (
              <m.button
                key={cat.id}
                whileHover={{ y: -2 }}
                whileTap={{ scale: 0.97 }}
                onClick={() => handleBannerClick(cat.action)}
                className={`w-full flex items-center justify-between gap-3 p-4 text-left ${
                  i === 0
                    ? "night-surface"
                    : "rounded-2xl border border-border bg-card text-foreground hover:bg-muted transition-colors"
                }`}
              >
                <div className="min-w-0">
                  <p className={`font-display font-bold leading-tight ${i === 0 ? "text-lg text-white" : "text-base"}`}>{t(cat.labelKey)}</p>
                  <p className={`text-xs mt-1 ${i === 0 ? "on-night-muted" : "text-muted-foreground"}`}>{t(cat.subtitleKey)}</p>
                </div>
                <cat.Icon className={`w-6 h-6 shrink-0 ${i === 0 ? "text-fast-gold" : "text-fast-rose"}`} strokeWidth={1.8} />
              </m.button>
            ))}
          </div>

          {/* Cuisine filter sidebar */}
          <div>
            <p className="text-xs font-bold uppercase tracking-wide text-muted-foreground mb-3">{t("cat_title")}</p>
            <div className="space-y-1">
              <button
                onClick={() => { setSearch(""); setActiveCuisine(null); }}
                className={`w-full text-left px-4 min-h-[40px] rounded-full text-sm font-semibold transition-colors ${
                  !activeCuisine ? "chip-on" : "text-foreground hover:bg-muted"
                }`}
              >
                {t("all_restos")}
              </button>
              {cuisineTypes.map((c) => (
                <button
                  key={c.type}
                  onClick={() => { setSearch(""); setActiveCuisine(activeCuisine === c.type ? null : c.type); }}
                  className={`w-full text-left px-4 min-h-[40px] rounded-full text-sm font-semibold transition-colors ${
                    activeCuisine === c.type ? "chip-on" : "text-foreground hover:bg-muted"
                  }`}
                >
                  {t(c.key)}
                </button>
              ))}
            </div>
          </div>
        </aside>

        {/* ── MAIN CONTENT ── */}
        <div className="flex-1 min-w-0 flex flex-col gap-10">

          {/* Active order card */}
          <AnimatePresence>
            {activeOrder && (
              <m.div
                initial={{ opacity: 0, y: -10 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -10 }}
              >
                <Link href={`/order-tracking/${activeOrder.id}`} className="block">
                  <div className="rounded-2xl border border-border bg-card p-4 flex items-center gap-3 card-lift cursor-pointer active:scale-[0.98]">
                    <div className="w-11 h-11 rounded-full bg-primary/10 flex items-center justify-center shrink-0">
                      <Zap className="w-5 h-5 text-fast-rose fill-fast-rose" />
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2">
                        <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
                        <span className="text-xs font-bold uppercase tracking-wide text-muted-foreground">{t("active_order")}</span>
                      </div>
                      <p className="text-foreground text-sm mt-0.5 font-bold truncate">
                        {activeOrder.restaurant?.name || "Restaurant"}
                        <span className="text-muted-foreground font-semibold text-xs ml-2 tabular-nums">#{activeOrder.id?.slice(-6).toUpperCase()}</span>
                      </p>
                    </div>
                    <span className="text-sm font-bold text-fast-rose shrink-0">{t("track")}</span>
                  </div>
                </Link>
              </m.div>
            )}
          </AnimatePresence>

          {/* Mobile: rotating promo — the lead one on the night surface */}
          <div className="md:hidden">
            <div className="relative h-28">
              <AnimatePresence mode="wait">
                {quickCategories.map((cat, i) =>
                  i === activeBanner ? (
                    <m.button
                      key={cat.id}
                      initial={{ opacity: 0, x: 40 }}
                      animate={{ opacity: 1, x: 0 }}
                      exit={{ opacity: 0, x: -40 }}
                      transition={{ duration: 0.35, ease: "easeInOut" }}
                      whileTap={{ scale: 0.97 }}
                      onClick={() => handleBannerClick(cat.action)}
                      className="absolute inset-0 w-full text-left"
                    >
                      {/* .night-surface sets its own positioning, so it lives on an inner box */}
                      <span
                        className={`w-full h-full flex items-center justify-between gap-4 px-5 ${
                          i === 0
                            ? "night-surface"
                            : "rounded-2xl border border-border bg-card text-foreground"
                        }`}
                      >
                        <span className="flex flex-col items-start gap-1 min-w-0">
                          <span className={`font-display text-xl font-bold leading-tight ${i === 0 ? "text-white" : ""}`}>{t(cat.labelKey)}</span>
                          <span className={`text-sm ${i === 0 ? "on-night-muted" : "text-muted-foreground"}`}>{t(cat.subtitleKey)}</span>
                        </span>
                        <cat.Icon className={`w-9 h-9 shrink-0 ${i === 0 ? "text-fast-gold" : "text-fast-rose"}`} strokeWidth={1.6} />
                      </span>
                    </m.button>
                  ) : null
                )}
              </AnimatePresence>
            </div>
            <div className="flex justify-center gap-1.5 mt-3">
              {quickCategories.map((_, i) => (
                <button
                  key={i}
                  onClick={() => setActiveBanner(i)}
                  className={`h-1.5 rounded-full transition-all duration-300 ${
                    i === activeBanner ? "w-5 bg-primary" : "w-1.5 bg-border"
                  }`}
                />
              ))}
            </div>
          </div>

          {/* Mobile: horizontal cuisine tiles */}
          <div className="md:hidden">
            <div className="flex gap-2 overflow-x-auto pb-1 scrollbar-hide -mx-4 px-4">
              {cuisineTypes.map((c) => (
                <CuisineChip
                  key={c.type}
                  type={c.type}
                  label={t(c.key)}
                  isActive={activeCuisine === c.type}
                  onClick={() => {
                    setSearch("");
                    setActiveCuisine(activeCuisine === c.type ? null : c.type);
                  }}
                />
              ))}
            </div>
          </div>

          {/* Favoris */}
          {favorites.length > 0 && (
            <div>
              <div className="flex items-baseline justify-between gap-3 mb-4">
                <h3 className="font-display font-bold text-2xl text-foreground">{t("my_favorites")}</h3>
                <Link href="/favorites" className="text-sm font-bold text-fast-rose shrink-0">{t("view_all")}</Link>
              </div>
              <FavoritesSection favoriteIds={favorites} restaurants={restaurants} />
            </div>
          )}

          {/* Restaurants */}
          <div>
            <div className="flex items-center justify-between gap-3 mb-4">
              <h3 className="font-display font-bold text-2xl text-foreground">
                {activeCuisine
                  ? t(cuisineTypes.find((c) => c.type === activeCuisine)?.key ?? "cat_burger")
                  : t("near_you")}
              </h3>
              <span className="text-xs font-bold text-muted-foreground bg-muted px-3 py-1.5 rounded-full shrink-0 tabular-nums">
                {t("results_n", { n: filtered.length })}
              </span>
            </div>

            {error ? (
              <div className="text-center py-16 px-5 rounded-2xl bg-card border border-border">
                <AlertTriangle className="w-12 h-12 text-destructive mx-auto mb-4" />
                <p className="font-display text-foreground text-xl font-bold mb-1">{t("load_error_title")}</p>
                <p className="text-muted-foreground text-sm mb-6">{t("load_error_body")}</p>
                <button
                  onClick={() => queryClient.invalidateQueries({ queryKey: ["restaurants"] })}
                  className="btn-neon text-sm"
                >
                  {t("retry_btn")}
                </button>
              </div>
            ) : isLoading ? (
              <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-5">
                {[1, 2, 3, 4, 5, 6].map((i) => (
                  <div key={i} className="bg-card border border-border rounded-2xl overflow-hidden">
                    <div className="aspect-video skeleton-shimmer" />
                    <div className="p-4 space-y-2.5">
                      <div className="h-4 w-2/3 rounded-full skeleton-shimmer" />
                      <div className="h-3 w-1/3 rounded-full skeleton-shimmer" />
                      <div className="h-3 w-full rounded-full skeleton-shimmer" />
                    </div>
                  </div>
                ))}
              </div>
            ) : filtered.length === 0 ? (
              <div className="text-center py-16 px-5 rounded-2xl bg-card border border-dashed border-border">
                <SearchX className="w-12 h-12 text-muted-foreground/60 mx-auto mb-4" />
                <p className="font-display text-foreground text-xl font-bold">{t("no_restos")}</p>
                <p className="text-muted-foreground text-sm mt-1">{t("no_restos_hint")}</p>
              </div>
            ) : (
              <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-5">
                {filtered.map((restaurant: any) => (
                  <Link key={restaurant.id} href={`/restaurant/${restaurant.id}`} className="block h-full">
                    <RestaurantCard
                      restaurant={restaurant}
                      isFavorite={favorites.includes(restaurant.id)}
                      onToggleFavorite={handleToggleFavorite}
                    />
                  </Link>
                ))}
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
