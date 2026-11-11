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

const sectionLabel = "text-xs font-bold uppercase tracking-wide text-muted-foreground";
const inputClass =
  "w-full min-h-[44px] bg-background border border-border rounded-xl px-3 py-2.5 text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:border-fast-teal focus:ring-2 focus:ring-fast-teal/30";
const chipClass = (on: boolean) =>
  `inline-flex items-center px-4 min-h-[44px] rounded-full text-xs font-bold border transition-colors focus-visible:outline-fast-teal ${
    on ? "border-fast-teal bg-fast-teal/15 text-foreground" : "border-border text-muted-foreground hover:text-foreground"
  }`;

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
    return <div className="py-12 text-center text-muted-foreground text-sm">Chargement des paramètres...</div>;
  }

  return (
    <div className="space-y-8">
      <div className="flex items-center justify-between">
        <h1 className="font-display text-2xl font-bold text-foreground">Paramètres restaurant</h1>
      </div>

      <div className="bg-card border border-border rounded-2xl p-4">
        <div className="flex items-center justify-between gap-3">
          <div className="flex items-center gap-3 min-w-0">
            <div className={`w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0 ${rushMode ? "bg-[#ff0066]/20" : "bg-muted"}`}>
              <Zap className={`w-4 h-4 ${rushMode ? "text-[color:var(--ac)]" : "text-muted-foreground"}`} />
            </div>
            <div className="min-w-0">
              <p className="text-sm font-bold text-foreground">Mode Rush</p>
              <p className="text-xs text-muted-foreground">Augmente les temps de préparation et priorise les commandes.</p>
            </div>
          </div>
          <button
            onClick={() => toggleRushMutation.mutate()}
            disabled={toggleRushMutation.isPending}
            role="switch"
            aria-checked={rushMode}
            aria-label="Mode Rush"
            className={`w-11 h-11 flex items-center justify-center flex-shrink-0 disabled:opacity-50 focus-visible:outline-fast-teal ${rushMode ? "text-fast-teal" : "text-muted-foreground"}`}
          >
            <ToggleIcon className="w-10 h-10" />
          </button>
        </div>
      </div>

      <form onSubmit={handleSubmit} className="space-y-8">
        <section className="space-y-3">
          <div className={`flex items-center gap-2 px-1 ${sectionLabel}`}>
            <Store className="w-4 h-4 text-fast-teal" /> Informations
          </div>

          <div className="bg-card border border-border rounded-2xl p-4 space-y-4">
            <div className="space-y-1.5">
              <label className={sectionLabel}>Nom du restaurant</label>
              <div className="relative">
                <Store className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
                <input
                  type="text"
                  value={form.name}
                  onChange={(e) => setForm({ ...form, name: e.target.value })}
                  className={`${inputClass} !pl-9`}
                  required
                />
              </div>
            </div>

            <div className="space-y-1.5">
              <label className={sectionLabel}>Description</label>
              <div className="relative">
                <FileText className="absolute left-3 top-3.5 w-4 h-4 text-muted-foreground" />
                <textarea
                  value={form.description}
                  onChange={(e) => setForm({ ...form, description: e.target.value })}
                  className={`${inputClass} !pl-9 min-h-[80px] resize-none`}
                />
              </div>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div className="space-y-1.5">
                <label className={sectionLabel}>Type de cuisine</label>
                <div className="relative">
                  <Utensils className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
                  <input
                    type="text"
                    value={form.cuisineType}
                    onChange={(e) => setForm({ ...form, cuisineType: e.target.value })}
                    className={`${inputClass} !pl-9`}
                  />
                </div>
              </div>
              <div className="space-y-1.5">
                <label className={sectionLabel}>Catégorie</label>
                <input
                  type="text"
                  value={form.category}
                  onChange={(e) => setForm({ ...form, category: e.target.value })}
                  className={inputClass}
                  placeholder="fast-food, italien..."
                />
              </div>
            </div>

            <div className="space-y-1.5">
              <label className={sectionLabel}>Adresse</label>
              <div className="relative">
                <MapPin className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
                <input
                  type="text"
                  value={form.address}
                  onChange={(e) => setForm({ ...form, address: e.target.value })}
                  className={`${inputClass} !pl-9`}
                />
              </div>
            </div>

            <div className="space-y-1.5">
              <label className={sectionLabel}>Ville</label>
              <input
                type="text"
                value={form.city}
                onChange={(e) => setForm({ ...form, city: e.target.value })}
                className={inputClass}
              />
            </div>
          </div>
        </section>

        <section className="space-y-3">
          <div className={`flex items-center gap-2 px-1 ${sectionLabel}`}>
            <Clock className="w-4 h-4 text-fast-teal" /> Temps de préparation (minutes)
          </div>

          <div className="bg-card border border-border rounded-2xl p-4">
            <div className="grid grid-cols-3 gap-3">
              <div className="space-y-1.5">
                <label className="text-xs font-bold text-muted-foreground">Normal</label>
                <input
                  type="number"
                  min="1"
                  value={form.normalPrepTime}
                  onChange={(e) => setForm({ ...form, normalPrepTime: Number(e.target.value) })}
                  className={`${inputClass} tabular-nums`}
                />
              </div>
              <div className="space-y-1.5">
                <label className="text-xs font-bold text-muted-foreground">Rush</label>
                <input
                  type="number"
                  min="1"
                  value={form.rushPrepTime}
                  onChange={(e) => setForm({ ...form, rushPrepTime: Number(e.target.value) })}
                  className={`${inputClass} tabular-nums`}
                />
              </div>
              <div className="space-y-1.5">
                <label className="text-xs font-bold text-muted-foreground">Pickup</label>
                <input
                  type="number"
                  min="1"
                  value={form.pickupPrepTime}
                  onChange={(e) => setForm({ ...form, pickupPrepTime: Number(e.target.value) })}
                  className={`${inputClass} tabular-nums`}
                />
              </div>
            </div>
          </div>
        </section>

        <section className="space-y-3">
          <label className={`block px-1 ${sectionLabel}`}>Options diététiques proposées</label>
          <div className="flex flex-wrap gap-2">
            {DIETARY_OPTIONS.map((opt) => (
              <button
                key={opt.value}
                type="button"
                onClick={() => toggleDietary(opt.value)}
                aria-pressed={form.dietaryOptions.includes(opt.value)}
                className={chipClass(form.dietaryOptions.includes(opt.value))}
              >
                {opt.label}
              </button>
            ))}
          </div>
        </section>

        <button type="submit" disabled={updateMutation.isPending} className="btn-neon w-full text-sm">
          {updateMutation.isPending ? <span className="w-4 h-4 border-2 border-fast-ink/30 border-t-fast-ink rounded-full animate-spin" /> : <Save className="w-4 h-4" />}
          Enregistrer les paramètres
        </button>
      </form>
    </div>
  );
}
