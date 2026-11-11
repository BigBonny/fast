"use client";

import { useEffect, useState } from "react";
import { useQuery, useQueryClient, useMutation } from "@tanstack/react-query";
import { Save, Store, MapPin, Utensils, FileText, Image, Star, Clock } from "lucide-react";
import { restaurantApi } from "@/api/fastBackend";
import { showToast } from "@/components/partner/Toast";
import SafeImage from "@/components/SafeImage";

const sectionLabel = "text-xs font-bold uppercase tracking-wide text-muted-foreground";
const inputClass =
  "w-full min-h-[44px] bg-background border border-border rounded-xl px-3 py-2.5 text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:border-fast-teal focus:ring-2 focus:ring-fast-teal/30";

export default function RestaurantProfile() {
  const queryClient = useQueryClient();
  const { data: restaurant, isLoading } = useQuery({
    queryKey: ["my-restaurant"],
    queryFn: () => restaurantApi.mine(),
  });

  const [form, setForm] = useState({ name: "", description: "", address: "", city: "", cuisineType: "", image: "", normalPrepTime: 15 });

  useEffect(() => {
    if (restaurant) {
      setForm({
        name: restaurant.name || "",
        description: restaurant.description || "",
        address: restaurant.address || "",
        city: restaurant.city || "",
        cuisineType: restaurant.cuisineType || "",
        image: restaurant.image || "",
        normalPrepTime: restaurant.normalPrepTime || 15,
      });
    }
  }, [restaurant]);

  const updateMutation = useMutation({
    mutationFn: (data: any) => restaurantApi.update(restaurant!.id, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["my-restaurant"] });
      queryClient.invalidateQueries({ queryKey: ["settings"] });
      showToast(" Profil mis à jour");
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
      image: form.image,
      normalPrepTime: Number(form.normalPrepTime),
    });
  };

  if (isLoading) return <div className="py-12 text-center text-muted-foreground text-sm">Chargement du profil...</div>;

  return (
    <div className="space-y-8">
      <div className="flex items-center justify-between">
        <h1 className="font-display text-2xl font-bold text-foreground">Profil restaurant</h1>
      </div>

      <div className="night-surface p-5 flex items-center gap-4">
        <div className="w-16 h-16 rounded-xl bg-white/[0.08] border border-white/10 flex items-center justify-center overflow-hidden flex-shrink-0">
          {restaurant?.image ? <SafeImage src={restaurant.image} alt="" width={64} height={64} className="w-full h-full object-cover" /> : <Store className="w-7 h-7 text-white/80" aria-hidden="true" />}
        </div>
        <div className="min-w-0">
          <p className="font-display text-xl font-bold text-white truncate">{restaurant?.name || "Mon restaurant"}</p>
          <div className="flex items-center gap-x-3 gap-y-1 flex-wrap text-xs on-night-muted mt-1 tabular-nums">
            <span className="flex items-center gap-1"><Star className="w-3.5 h-3.5 text-yellow-400 fill-current" /> {restaurant?.rating?.toFixed(1) || "0.0"}</span>
            <span>{restaurant?.reviewsCount || 0} avis</span>
            <span className="flex items-center gap-1"><Clock className="w-3.5 h-3.5" /> {restaurant?.normalPrepTime || 15} min</span>
          </div>
        </div>
      </div>

      <form onSubmit={handleSubmit} className="space-y-3">
        <div className={`flex items-center gap-2 px-1 ${sectionLabel}`}><Store className="w-4 h-4 text-fast-teal" /> Modifier le profil</div>

        <div className="bg-card border border-border rounded-2xl p-4 space-y-4">
          <div className="space-y-1.5">
            <label className={sectionLabel}>Nom</label>
            <input type="text" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} className={inputClass} required />
          </div>

          <div className="space-y-1.5">
            <label className={sectionLabel}>Description</label>
            <div className="relative">
              <FileText className="absolute left-3 top-3.5 w-4 h-4 text-muted-foreground" />
              <textarea value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} className={`${inputClass} !pl-9 min-h-[80px] resize-none`} />
            </div>
          </div>

          <div className="space-y-1.5">
            <label className={sectionLabel}>Type de cuisine</label>
            <div className="relative">
              <Utensils className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
              <input type="text" value={form.cuisineType} onChange={(e) => setForm({ ...form, cuisineType: e.target.value })} className={`${inputClass} !pl-9`} />
            </div>
          </div>

          <div className="space-y-1.5">
            <label className={sectionLabel}>Adresse</label>
            <div className="relative">
              <MapPin className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
              <input type="text" value={form.address} onChange={(e) => setForm({ ...form, address: e.target.value })} className={`${inputClass} !pl-9`} />
            </div>
          </div>

          <div className="space-y-1.5">
            <label className={sectionLabel}>Ville</label>
            <input type="text" value={form.city} onChange={(e) => setForm({ ...form, city: e.target.value })} className={inputClass} />
          </div>

          <div className="space-y-1.5">
            <label className={sectionLabel}>Image URL</label>
            <div className="relative">
              <Image className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
              <input type="text" value={form.image} onChange={(e) => setForm({ ...form, image: e.target.value })} className={`${inputClass} !pl-9`} />
            </div>
          </div>
        </div>

        <button type="submit" disabled={updateMutation.isPending} className="btn-neon w-full text-sm !mt-5">
          {updateMutation.isPending ? <span className="w-4 h-4 border-2 border-fast-ink/30 border-t-fast-ink rounded-full animate-spin" /> : <Save className="w-4 h-4" />}
          Enregistrer le profil
        </button>
      </form>
    </div>
  );
}
