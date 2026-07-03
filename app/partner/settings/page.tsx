"use client";

import { useEffect, useState } from "react";
import { useQuery, useQueryClient, useMutation } from "@tanstack/react-query";
import { Save, Zap, Store, Clock, MapPin, Utensils, FileText, ChefHat, ToggleLeft, ToggleRight } from "lucide-react";
import { restaurantApi } from "@/api/fastBackend";
import { showToast } from "@/components/partner/Toast";

const DIETARY_OPTIONS = [
  { value: "VEGAN", label: "Vegan" },
  { value: "VEGETARIAN", label: "Végétarien" },
  { value: "GLUTEN_FREE", label: "Sans gluten" },
  { value: "HALAL", label: "Halal" },
  { value: "KETO", label: "Keto" },
  { value: "DAIRY_FREE", label: "Sans lactose" },
];

export default function PartnerSettingsPage() {
  const queryClient = useQueryClient();
  const { data: restaurant, isLoading } = useQuery({
    queryKey: ["my-restaurant"],
    queryFn: () => restaurantApi.mine(),
  });

  const [form, setForm] = useState({
    name: "",
    description: "",
    address: "",
    city: "",
    cuisineType: "",
    category: "",
    normalPrepTime: 15,
    rushPrepTime: 25,
    pickupPrepTime: 15,
    dietaryOptions: [] as string[],
  });
  const [rushMode, setRushMode] = useState(false);

  useEffect(() => {
    if (restaurant) {
      setForm({
        name: restaurant.name || "",
        description: restaurant.description || "",
        address: restaurant.address || "",
        city: restaurant.city || "",
        cuisineType: restaurant.cuisineType || "",
        category: restaurant.category || "",
        normalPrepTime: restaurant.normalPrepTime || 15,
        rushPrepTime: restaurant.rushPrepTime || 25,
        pickupPrepTime: restaurant.pickupPrepTime || 15,
        dietaryOptions: restaurant.dietaryOptions?.map((o: any) => o.option) || [],
      });
      setRushMode(!!restaurant.isRushMode);
    }
  }, [restaurant]);

  const updateMutation = useMutation({
    mutationFn: (data: any) => restaurantApi.update(restaurant!.id, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["my-restaurant"] });
      queryClient.invalidateQueries({ queryKey: ["settings"] });
      showToast(" Paramètres enregistrés");
    },
    onError: (err: any) => showToast(err?.message || " Erreur lors de la sauvegarde"),
  });

  const toggleRushMutation = useMutation({
    mutationFn: () => restaurantApi.toggleRush(),
    onSuccess: (res: any) => {
      setRushMode(!!res.isRushMode);
      queryClient.invalidateQueries({ queryKey: ["my-restaurant"] });
      queryClient.invalidateQueries({ queryKey: ["settings"] });
      showToast(res.isRushMode ? " Mode Rush activé" : " Mode Rush désactivé");
    },
    onError: (err: any) => showToast(err?.message || " Erreur"),
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!restaurant) return;
    updateMutation.mutate({
      name: form.name,
      description: form.description,
      address: form.address,
      city: form.city,
      cuisineType: form.cuisineType,
      category: form.category,
      normalPrepTime: Number(form.normalPrepTime),
      rushPrepTime: Number(form.rushPrepTime),
      pickupPrepTime: Number(form.pickupPrepTime),
      dietaryOptions: form.dietaryOptions,
    });
  };

  const toggleDietary = (opt: string) => {
    setForm((prev) => ({
      ...prev,
      dietaryOptions: prev.dietaryOptions.includes(opt) ? prev.dietaryOptions.filter((o) => o !== opt) : [...prev.dietaryOptions, opt],
    }));
  };

  const ToggleIcon = rushMode ? ToggleRight : ToggleLeft;

  if (isLoading) {
    return <div className="py-12 text-center text-slate-500 text-sm">Chargement des paramètres...</div>;
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-lg font-black text-white">Paramètres restaurant</h1>
      </div>

      <div className="bg-[#0B1120] border border-white/[0.08] rounded-2xl p-4">
        <div className="flex items-center justify-between mb-2">
          <div className="flex items-center gap-2">
            <div className={`w-8 h-8 rounded-lg flex items-center justify-center ${rushMode ? "bg-[#ff0066]/20" : "bg-white/[0.06]"}`}>
              <Zap className={`w-4 h-4 ${rushMode ? "text-[#ff0066]" : "text-slate-300"}`} />
            </div>
            <div>
              <p className="text-sm font-bold text-white">Mode Rush</p>
              <p className="text-[11px] text-slate-400">Augmente les temps de préparation et priorise les commandes.</p>
            </div>
          </div>
          <button
            onClick={() => toggleRushMutation.mutate()}
            disabled={toggleRushMutation.isPending}
            className="text-[#00c8b3] disabled:opacity-50"
          >
            <ToggleIcon className="w-10 h-10" />
          </button>
        </div>
      </div>

      <form onSubmit={handleSubmit} className="bg-[#0B1120] border border-white/[0.08] rounded-2xl p-4 space-y-4">
        <div className="flex items-center gap-2 text-sm font-bold text-[#00c8b3]">
          <Store className="w-4 h-4" /> Informations
        </div>

        <div className="space-y-1">
          <label className="text-[11px] font-bold text-slate-500 uppercase tracking-wider">Nom du restaurant</label>
          <div className="relative">
            <Store className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-500" />
            <input
              type="text"
              value={form.name}
              onChange={(e) => setForm({ ...form, name: e.target.value })}
              className="w-full bg-[#020617] border border-white/[0.08] rounded-xl pl-9 pr-3 py-2.5 text-sm text-white placeholder:text-slate-500 focus:border-[#00c8b3]/50 outline-none"
              required
            />
          </div>
        </div>

        <div className="space-y-1">
          <label className="text-[11px] font-bold text-slate-500 uppercase tracking-wider">Description</label>
          <div className="relative">
            <FileText className="absolute left-3 top-3 w-4 h-4 text-slate-500" />
            <textarea
              value={form.description}
              onChange={(e) => setForm({ ...form, description: e.target.value })}
              className="w-full bg-[#020617] border border-white/[0.08] rounded-xl pl-9 pr-3 py-2.5 text-sm text-white placeholder:text-slate-500 focus:border-[#00c8b3]/50 outline-none min-h-[80px] resize-none"
            />
          </div>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <div className="space-y-1">
            <label className="text-[11px] font-bold text-slate-500 uppercase tracking-wider">Type de cuisine</label>
            <div className="relative">
              <Utensils className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-500" />
              <input
                type="text"
                value={form.cuisineType}
                onChange={(e) => setForm({ ...form, cuisineType: e.target.value })}
                className="w-full bg-[#020617] border border-white/[0.08] rounded-xl pl-9 pr-3 py-2.5 text-sm text-white placeholder:text-slate-500 focus:border-[#00c8b3]/50 outline-none"
              />
            </div>
          </div>
          <div className="space-y-1">
            <label className="text-[11px] font-bold text-slate-500 uppercase tracking-wider">Catégorie</label>
            <input
              type="text"
              value={form.category}
              onChange={(e) => setForm({ ...form, category: e.target.value })}
              className="w-full bg-[#020617] border border-white/[0.08] rounded-xl px-3 py-2.5 text-sm text-white placeholder:text-slate-500 focus:border-[#00c8b3]/50 outline-none"
              placeholder="fast-food, italien..."
            />
          </div>
        </div>

        <div className="space-y-1">
          <label className="text-[11px] font-bold text-slate-500 uppercase tracking-wider">Adresse</label>
          <div className="relative">
            <MapPin className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-500" />
            <input
              type="text"
              value={form.address}
              onChange={(e) => setForm({ ...form, address: e.target.value })}
              className="w-full bg-[#020617] border border-white/[0.08] rounded-xl pl-9 pr-3 py-2.5 text-sm text-white placeholder:text-slate-500 focus:border-[#00c8b3]/50 outline-none"
            />
          </div>
        </div>

        <div className="space-y-1">
          <label className="text-[11px] font-bold text-slate-500 uppercase tracking-wider">Ville</label>
          <input
            type="text"
            value={form.city}
            onChange={(e) => setForm({ ...form, city: e.target.value })}
            className="w-full bg-[#020617] border border-white/[0.08] rounded-xl px-3 py-2.5 text-sm text-white placeholder:text-slate-500 focus:border-[#00c8b3]/50 outline-none"
          />
        </div>

        <div className="flex items-center gap-2 text-sm font-bold text-[#00c8b3] pt-2">
          <Clock className="w-4 h-4" /> Temps de préparation (minutes)
        </div>

        <div className="grid grid-cols-3 gap-3">
          <div className="space-y-1">
            <label className="text-[10px] font-bold text-slate-500">Normal</label>
            <input
              type="number"
              min="1"
              value={form.normalPrepTime}
              onChange={(e) => setForm({ ...form, normalPrepTime: Number(e.target.value) })}
              className="w-full bg-[#020617] border border-white/[0.08] rounded-xl px-3 py-2 text-sm text-white focus:border-[#00c8b3]/50 outline-none"
            />
          </div>
          <div className="space-y-1">
            <label className="text-[10px] font-bold text-slate-500">Rush</label>
            <input
              type="number"
              min="1"
              value={form.rushPrepTime}
              onChange={(e) => setForm({ ...form, rushPrepTime: Number(e.target.value) })}
              className="w-full bg-[#020617] border border-white/[0.08] rounded-xl px-3 py-2 text-sm text-white focus:border-[#00c8b3]/50 outline-none"
            />
          </div>
          <div className="space-y-1">
            <label className="text-[10px] font-bold text-slate-500">Pickup</label>
            <input
              type="number"
              min="1"
              value={form.pickupPrepTime}
              onChange={(e) => setForm({ ...form, pickupPrepTime: Number(e.target.value) })}
              className="w-full bg-[#020617] border border-white/[0.08] rounded-xl px-3 py-2 text-sm text-white focus:border-[#00c8b3]/50 outline-none"
            />
          </div>
        </div>

        <div className="space-y-2">
          <label className="text-[11px] font-bold text-slate-500 uppercase tracking-wider">Options diététiques proposées</label>
          <div className="flex flex-wrap gap-2">
            {DIETARY_OPTIONS.map((opt) => (
              <button
                key={opt.value}
                type="button"
                onClick={() => toggleDietary(opt.value)}
                className={`px-2.5 py-1 rounded-full text-[11px] font-bold border transition-all ${form.dietaryOptions.includes(opt.value) ? "border-[#00c8b3] text-[#00c8b3] bg-[#00c8b3]/10" : "border-white/10 text-slate-400 hover:border-white/20"}`}
              >
                {opt.label}
              </button>
            ))}
          </div>
        </div>

        <button
          type="submit"
          disabled={updateMutation.isPending}
          className="w-full bg-[#00c8b3] text-[#020617] rounded-xl py-2.5 text-sm font-black flex items-center justify-center gap-2 disabled:opacity-50"
        >
          {updateMutation.isPending ? <span className="w-4 h-4 border-2 border-[#020617]/30 border-t-[#020617] rounded-full animate-spin" /> : <Save className="w-4 h-4" />}
          Enregistrer les paramètres
        </button>
      </form>
    </div>
  );
}
