"use client";

import React, { useState, useEffect, useRef, useMemo, useCallback } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { restaurantApi, orderApi } from "@/api/fastBackend";
import { getFavorites, toggleFavorite } from "@/lib/localCart";
import { Search, Menu, X, Store, ShoppingCart, User, Zap, Users, Sparkles, AlertTriangle, SearchX, UtensilsCrossed, type LucideIcon } from "lucide-react";
import { Input } from "@/components/ui/input";
import { motion, AnimatePresence } from "framer-motion";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/AuthContext";
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
  { type: "burger", label: "Burger" },
  { type: "pizza", label: "Pizza" },
  { type: "kebab", label: "Kebab" },
  { type: "tacos", label: "Tacos" },
  { type: "mexicain", label: "Mexicain" },
  { type: "africain", label: "Africain" },
  { type: "arabe", label: "Arabe" },
  { type: "sushi", label: "Sushi" },
  { type: "indien", label: "Indien" },
  { type: "chinois", label: "Chinois" },
  { type: "thai", label: "Thaï" },
  { type: "poulet", label: "Poulet" },
  { type: "sandwich", label: "Sandwich" },
  { type: "hotdog", label: "Hot-dog" },
  { type: "pates", label: "Pâtes" },
  { type: "salade", label: "Salade" },
  { type: "vegan", label: "Vegan" },
  { type: "dessert", label: "Dessert" },
  { type: "crepes", label: "Crêpes" },
  { type: "waffle", label: "Waffle" },
  { type: "cafe", label: "Café" },
  { type: "smoothie", label: "Smoothie" },
];

const quickCategories: { label: string; subtitle: string; Icon: LucideIcon; bg: string; id: string; action: string }[] = [
  { label: "FOOD DROP", subtitle: "Commande express", Icon: Zap, bg: "linear-gradient(135deg,#dc2626,#b91c1c)", id: "drop", action: "orders" },
  { label: "AVEC MES AMIS", subtitle: "Commande de groupe", Icon: Users, bg: "linear-gradient(135deg,#7c3aed,#4f46e5)", id: "amis", action: "group" },
  { label: "SURPRISE ME", subtitle: "Laisse-toi surprendre", Icon: Sparkles, bg: "linear-gradient(135deg,#374151,#1a1f2e)", id: "surprise", action: "surprise" },
];

export default function Home() {
  const { user, isAuthenticated } = useAuth();
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
      .filter((c) => c.label.toLowerCase().includes(q))
      .slice(0, 3)
      .map((c) => ({ type: "cuisine", label: c.label, cuisine: c.type }));
    return [...cuisineSuggestions, ...restSuggestions];
  }, [debouncedSearch, restaurants]);

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
    return <div className="pb-6 min-h-screen" style={{ background: "#f8f9fa" }} />;
  }

  return (
    <div className="pb-6 min-h-screen" style={{ background: "#f8f9fa" }}>
      <SideMenu isOpen={showMenu} onClose={() => setShowMenu(false)} />


      {/* ── HERO HEADER ── */}
      <div className="relative overflow-hidden" style={{ background: "#08090f" }}>
        {/* Anneaux décoratifs */}
        <div className="absolute inset-0 flex items-center justify-center pointer-events-none overflow-hidden">
          <div className="absolute w-[520px] h-[520px] rounded-full border border-violet-600/15" style={{ transform: "rotate(-20deg) scaleY(0.28)" }} />
          <div className="absolute w-[420px] h-[420px] rounded-full border border-cyan-500/20" style={{ transform: "rotate(-20deg) scaleY(0.28)" }} />
          <div className="absolute w-[320px] h-[320px] rounded-full border-2 border-pink-500/25" style={{ transform: "rotate(-20deg) scaleY(0.28)" }} />
          <div className="absolute w-[220px] h-[220px] rounded-full border border-yellow-400/20" style={{ transform: "rotate(-20deg) scaleY(0.28)" }} />
          <div className="absolute w-48 h-48 rounded-full blur-3xl opacity-20" style={{ background: "radial-gradient(circle, #7c3aed, transparent)" }} />
        </div>

        {/* Mobile top bar — hidden on desktop */}
        <div className="md:hidden relative z-10 flex items-center justify-between px-5 pt-5 pb-3 max-w-5xl mx-auto">
          <button
            onClick={() => setShowMenu(true)}
            className="w-9 h-9 rounded-xl flex items-center justify-center"
            style={{ background: "rgba(255,255,255,0.08)" }}
          >
            <Menu className="w-5 h-5 text-white" />
          </button>
          <div className="flex items-center gap-2">
            {user?.role === "RESTAURANT" && (
              <Link href="/partner/orders">
                <div className="px-3 h-9 rounded-xl flex items-center gap-1.5 text-xs font-black text-white"
                  style={{ background: "linear-gradient(135deg, #00c8b3, #7c3aed)" }}>
                  <Store className="w-4 h-4" />
                  Espace Pro
                </div>
              </Link>
            )}
            <Link href="/cart">
              <button className="w-9 h-9 rounded-xl flex items-center justify-center"
                style={{ background: "rgba(255,255,255,0.08)" }}>
                <ShoppingCart className="w-4 h-4 text-white" />
              </button>
            </Link>
            <Link href="/profile">
              <div className="w-9 h-9 rounded-xl flex items-center justify-center text-sm font-black text-white"
                style={{ background: "linear-gradient(135deg, #14b8a6, #8b5cf6)" }}>
                {user?.name ? user.name[0].toUpperCase() : <User className="w-4 h-4" />}
              </div>
            </Link>
          </div>
        </div>

        {/* Logo centré — mobile only */}
        <div className="md:hidden relative z-10 flex flex-col items-center pb-6 pt-2">
          <motion.div
            animate={{ filter: ["drop-shadow(0 0 8px #f59e0b80)", "drop-shadow(0 0 18px #f59e0bcc)", "drop-shadow(0 0 8px #f59e0b80)"] }}
            transition={{ repeat: Infinity, duration: 2.2, ease: "easeInOut" }}
            className="flex flex-col items-center"
          >
            <div className="flex items-center gap-1.5">
              <Zap className="w-8 h-8 text-amber-400 fill-amber-400" />
              <span className="font-black text-5xl italic tracking-tight" style={{
                background: "linear-gradient(90deg, #f59e0b, #fbbf24, #f97316)",
                WebkitBackgroundClip: "text",
                WebkitTextFillColor: "transparent",
              }}>FAST</span>
              <Zap className="w-8 h-8 text-amber-400 fill-amber-400" />
            </div>
          </motion.div>
          <p className="text-gray-400 text-xs font-medium tracking-widest uppercase mt-1">Chaque minute compte.</p>
        </div>

        {/* Desktop hero headline */}
        <div className="hidden md:flex relative z-10 flex-col items-center pt-12 pb-8">
          <p className="text-gray-400 text-xs font-bold tracking-[0.3em] uppercase mb-3">Chaque minute compte</p>
          <h1 className="font-black text-5xl text-white tracking-tight text-center leading-tight">
            Commandez.{" "}
            <span style={{
              background: "linear-gradient(90deg, #f59e0b, #f97316)",
              WebkitBackgroundClip: "text",
              WebkitTextFillColor: "transparent",
            }}>Vite.</span>{" "}
            Maintenant.
          </h1>
          <p className="text-gray-500 text-sm mt-3">Vos restaurants préférés, sans attendre.</p>
        </div>

        {/* Search avec autocomplétion */}
        <div className="relative z-20 px-5 pb-5 max-w-2xl mx-auto" ref={searchRef}>
          <div className="relative">
            <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400 z-10" />
            <Input
              value={search}
              onChange={(e) => handleSearchChange(e.target.value)}
              onFocus={() => search && setShowSuggestions(suggestions.length > 0)}
              placeholder="Rechercher un plat ou restaurant..."
              className="pl-10 h-11 md:h-12 border border-white/5 rounded-2xl text-sm placeholder:text-gray-500 text-white focus:border-violet-500/50 transition-colors"
              style={{ background: "#1a1f2e" }}
            />
            {search && (
              <button onClick={() => { setSearch(""); setShowSuggestions(false); }}
                className="absolute right-3 top-1/2 -translate-y-1/2">
                <X className="w-4 h-4 text-gray-400" />
              </button>
            )}
          </div>

          {/* Suggestions dropdown */}
          <AnimatePresence>
            {showSuggestions && suggestions.length > 0 && (
              <motion.div
                initial={{ opacity: 0, y: -8 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -8 }}
                className="absolute left-5 right-5 mt-2 rounded-2xl overflow-hidden shadow-2xl z-50"
                style={{ background: "#1a1f2e", border: "1px solid rgba(255,255,255,0.08)" }}
              >
                {suggestions.map((s, i) => (
                  <button key={i} onClick={() => handleSuggestionClick(s)}
                    className="w-full flex items-center gap-3 px-4 py-3 text-left hover:bg-white/5 transition-colors border-b border-white/5 last:border-0">
                    <span className="w-9 h-9 rounded-lg bg-white/5 flex items-center justify-center shrink-0">
                      {s.type === "cuisine" ? <UtensilsCrossed className="w-4 h-4 text-cyan-400" /> : <Store className="w-4 h-4 text-violet-400" />}
                    </span>
                    <div>
                      <p className="text-white text-sm font-semibold">{s.label}</p>
                      <p className="text-gray-500 text-xs">{s.type === "cuisine" ? "Catégorie" : "Restaurant"}</p>
                    </div>
                  </button>
                ))}
              </motion.div>
            )}
          </AnimatePresence>
        </div>
      </div>

      {/* ── BODY ── */}
      <div className="max-w-screen-xl mx-auto px-5 md:px-8 pt-5 pb-8 md:flex md:gap-8">

        {/* ── DESKTOP SIDEBAR ── */}
        <aside className="hidden md:flex flex-col gap-6 w-56 shrink-0">
          {/* Banner cards (stacked on desktop) */}
          <div className="space-y-3">
            {quickCategories.map((cat) => (
              <motion.button
                key={cat.id}
                whileHover={{ scale: 1.02 }}
                whileTap={{ scale: 0.97 }}
                onClick={() => handleBannerClick(cat.action)}
                className="w-full flex items-center justify-between px-4 py-3 rounded-2xl text-white"
                style={{ background: cat.bg }}
              >
                <div className="text-left">
                  <p className="text-sm font-black">{cat.label}</p>
                  <p className="text-[11px] text-white/75">{cat.subtitle}</p>
                </div>
                <cat.Icon className="w-7 h-7 text-white/80 shrink-0" strokeWidth={1.8} />
              </motion.button>
            ))}
          </div>

          {/* Cuisine filter sidebar */}
          <div>
            <p className="text-[10px] font-black uppercase tracking-widest text-gray-400 mb-3">Catégories</p>
            <div className="space-y-1">
              <button
                onClick={() => { setSearch(""); setActiveCuisine(null); }}
                className={`w-full text-left px-3 py-2 rounded-xl text-sm font-semibold transition-colors ${
                  !activeCuisine ? "bg-violet-500 text-white" : "text-gray-600 hover:bg-gray-100"
                }`}
              >
                Tous les restaurants
              </button>
              {cuisineTypes.map((c) => (
                <button
                  key={c.type}
                  onClick={() => { setSearch(""); setActiveCuisine(activeCuisine === c.type ? null : c.type); }}
                  className={`w-full text-left px-3 py-2 rounded-xl text-sm font-semibold transition-colors ${
                    activeCuisine === c.type ? "bg-violet-500 text-white" : "text-gray-600 hover:bg-gray-100"
                  }`}
                >
                  {c.label}
                </button>
              ))}
            </div>
          </div>
        </aside>

        {/* ── MAIN CONTENT ── */}
        <div className="flex-1 min-w-0">

          {/* Active order card */}
          <AnimatePresence>
            {activeOrder && (
              <motion.div
                className="mb-4"
                initial={{ opacity: 0, y: -10 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -10 }}
              >
                <Link href={`/order-tracking/${activeOrder.id}`}>
                  <div className="rounded-2xl p-4 border border-cyan-400/30" style={{ background: "rgba(6,182,212,0.08)" }}>
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
                        <span className="text-sm font-bold text-cyan-400">Commande en cours</span>
                      </div>
                      <span className="text-xs text-gray-400">#{activeOrder.id?.slice(-6).toUpperCase()}</span>
                    </div>
                    <p className="text-gray-700 text-sm mt-1 font-semibold">
                      {activeOrder.restaurant?.name || "Restaurant"}
                    </p>
                  </div>
                </Link>
              </motion.div>
            )}
          </AnimatePresence>

          {/* Mobile: scrollable banner */}
          <div className="md:hidden mb-4">
            <div
              className="relative overflow-hidden rounded-2xl border border-white/10"
              style={{ height: 100, boxShadow: "0 12px 30px rgba(0,0,0,0.15), 0 0 0 1px rgba(255,255,255,0.04) inset" }}
            >
              <AnimatePresence mode="wait">
                {quickCategories.map((cat, i) =>
                  i === activeBanner ? (
                    <motion.button
                      key={cat.id}
                      initial={{ opacity: 0, x: 60, scale: 0.98 }}
                      animate={{ opacity: 1, x: 0, scale: 1 }}
                      exit={{ opacity: 0, x: -60, scale: 0.98 }}
                      transition={{ duration: 0.4, ease: "easeInOut" }}
                      whileTap={{ scale: 0.97 }}
                      onClick={() => handleBannerClick(cat.action)}
                      className="absolute inset-0 w-full flex items-center justify-between px-6 text-white shadow-lg rounded-2xl"
                      style={{ background: cat.bg }}
                    >
                      <div className="flex flex-col items-start gap-1">
                        <span className="text-xl font-black tracking-wide">{cat.label}</span>
                        <span className="text-xs text-white/80 font-medium">{cat.subtitle}</span>
                      </div>
                      <cat.Icon className="w-12 h-12 text-white/90" strokeWidth={1.8} />
                    </motion.button>
                  ) : null
                )}
              </AnimatePresence>
              <div className="absolute bottom-2 left-1/2 -translate-x-1/2 flex gap-1.5 z-10">
                {quickCategories.map((_, i) => (
                  <button
                    key={i}
                    onClick={() => setActiveBanner(i)}
                    className="rounded-full transition-all duration-300"
                    style={{
                      width: i === activeBanner ? 18 : 6,
                      height: 6,
                      background: i === activeBanner ? "rgba(255,255,255,0.95)" : "rgba(255,255,255,0.35)",
                      boxShadow: i === activeBanner ? "0 0 8px rgba(255,255,255,0.5)" : "none",
                    }}
                  />
                ))}
              </div>
            </div>
          </div>

          {/* Mobile: horizontal cuisine chips */}
          <div className="md:hidden mb-4">
            <div className="flex gap-2 overflow-x-auto pb-3 scrollbar-hide -mx-1 px-1">
              {cuisineTypes.map((c) => (
                <CuisineChip
                  key={c.type}
                  type={c.type}
                  label={c.label}
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
            <div className="mb-5">
              <div className="flex items-center justify-between mb-2">
                <h3 className="font-bold text-gray-900">Mes favoris</h3>
                <Link href="/favorites" className="text-xs font-semibold text-violet-500">Voir tout</Link>
              </div>
              <FavoritesSection favoriteIds={favorites} restaurants={restaurants} />
            </div>
          )}

          {/* Restaurants */}
          <div>
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-2">
                <div className="w-1 h-5 rounded-full bg-gradient-to-b from-violet-500 to-cyan-400" />
                <h3 className="font-black text-gray-900 text-lg">
                  {activeCuisine
                    ? cuisineTypes.find((c) => c.type === activeCuisine)?.label
                    : "Près de vous"}
                </h3>
              </div>
              <span className="text-xs font-bold text-gray-400 bg-gray-100 px-2 py-1 rounded-full">
                {filtered.length} résultat{filtered.length > 1 ? "s" : ""}
              </span>
            </div>

            {error ? (
              <div className="text-center py-16 px-5 rounded-2xl bg-gray-50 border border-gray-100">
                <AlertTriangle className="w-12 h-12 text-amber-400 mx-auto mb-3" />
                <p className="text-gray-700 text-sm font-bold mb-1">Impossible de charger les restaurants</p>
                <p className="text-gray-400 text-xs mb-4">Vérifie ta connexion et réessaie.</p>
                <button
                  onClick={() => queryClient.invalidateQueries({ queryKey: ["restaurants"] })}
                  className="px-5 py-2.5 rounded-xl bg-gradient-to-r from-violet-500 to-purple-600 text-white text-sm font-bold shadow-lg shadow-violet-200"
                >
                  Réessayer
                </button>
              </div>
            ) : isLoading ? (
              <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-3 xl:grid-cols-4 gap-3 sm:gap-4">
                {[1, 2, 3, 4, 5, 6, 7, 8].map((i) => (
                  <div key={i} className="bg-white border border-gray-100 rounded-2xl h-56 overflow-hidden">
                    <div className="h-40 skeleton-shimmer" />
                    <div className="p-3 space-y-2">
                      <div className="h-3 w-2/3 rounded skeleton-shimmer" />
                      <div className="h-2 w-1/2 rounded skeleton-shimmer" />
                    </div>
                  </div>
                ))}
              </div>
            ) : filtered.length === 0 ? (
              <div className="text-center py-16 rounded-2xl bg-gray-50 border border-dashed border-gray-200">
                <SearchX className="w-12 h-12 text-gray-300 mx-auto mb-3" />
                <p className="text-gray-500 text-sm font-semibold">Aucun restaurant trouvé</p>
                <p className="text-gray-400 text-xs mt-1">Essayez une autre recherche ou catégorie.</p>
              </div>
            ) : (
              <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-3 xl:grid-cols-4 gap-3 sm:gap-4">
                {filtered.map((restaurant: any) => (
                  <Link key={restaurant.id} href={`/restaurant/${restaurant.id}`}>
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
