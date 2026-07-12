"use client";

import { useEffect, useState } from "react";
import { useQuery, useQueryClient, useMutation } from "@tanstack/react-query";
import { Save, Store, MapPin, Utensils, FileText, Image, Star, Clock } from "lucide-react";
import { restaurantApi } from "@/api/fastBackend";
import { showToast } from "@/components/partner/Toast";
import SafeImage from "@/components/SafeImage";

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

  if (isLoading) return <div className="py-12 text-center text-slate-500 text-sm">Chargement du profil...</div>;

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-lg font-black text-white">Profil restaurant</h1>
      </div>

      <div className="bg-[#0B1120] border border-white/[0.08] rounded-2xl p-4 flex items-center gap-4">
        <div className="w-16 h-16 rounded-2xl bg-white/[0.06] flex items-center justify-center text-3xl overflow-hidden flex-shrink-0">
          {restaurant?.image ? <SafeImage src={restaurant.image} alt="" width={64} height={64} className="w-full h-full object-cover" /> : ""}
        </div>
        <div>
          <p className="text-lg font-black text-white">{restaurant?.name || "Mon restaurant"}</p>
          <div className="flex items-center gap-2 text-xs text-slate-400">
            <span className="flex items-center gap-1"><Star className="w-3 h-3 text-yellow-400" /> {restaurant?.rating?.toFixed(1) || "0.0"}</span>
            <span></span>
            <span>{restaurant?.reviewsCount || 0} avis</span>
            <span></span>
            <span className="flex items-center gap-1"><Clock className="w-3 h-3" /> {restaurant?.normalPrepTime || 15} min</span>
          </div>
        </div>
      </div>

      <form onSubmit={handleSubmit} className="bg-[#0B1120] border border-white/[0.08] rounded-2xl p-4 space-y-4">
        <div className="flex items-center gap-2 text-sm font-bold text-[#00c8b3]"><Store className="w-4 h-4" /> Modifier le profil</div>

        <div className="space-y-1">
          <label className="text-[11px] font-bold text-slate-500 uppercase tracking-wider">Nom</label>
          <input type="text" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} className="w-full bg-[#020617] border border-white/[0.08] rounded-xl px-3 py-2.5 text-sm text-white placeholder:text-slate-500 focus:border-[#00c8b3]/50 outline-none" required />
        </div>

        <div className="space-y-1">
          <label className="text-[11px] font-bold text-slate-500 uppercase tracking-wider">Description</label>
          <div className="relative">
            <FileText className="absolute left-3 top-3 w-4 h-4 text-slate-500" />
            <textarea value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} className="w-full bg-[#020617] border border-white/[0.08] rounded-xl pl-9 pr-3 py-2.5 text-sm text-white placeholder:text-slate-500 focus:border-[#00c8b3]/50 outline-none min-h-[80px] resize-none" />
          </div>
        </div>

        <div className="space-y-1">
          <label className="text-[11px] font-bold text-slate-500 uppercase tracking-wider">Type de cuisine</label>
          <div className="relative">
            <Utensils className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-500" />
            <input type="text" value={form.cuisineType} onChange={(e) => setForm({ ...form, cuisineType: e.target.value })} className="w-full bg-[#020617] border border-white/[0.08] rounded-xl pl-9 pr-3 py-2.5 text-sm text-white placeholder:text-slate-500 focus:border-[#00c8b3]/50 outline-none" />
          </div>
        </div>

        <div className="space-y-1">
          <label className="text-[11px] font-bold text-slate-500 uppercase tracking-wider">Adresse</label>
          <div className="relative">
            <MapPin className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-500" />
            <input type="text" value={form.address} onChange={(e) => setForm({ ...form, address: e.target.value })} className="w-full bg-[#020617] border border-white/[0.08] rounded-xl pl-9 pr-3 py-2.5 text-sm text-white placeholder:text-slate-500 focus:border-[#00c8b3]/50 outline-none" />
          </div>
        </div>

        <div className="space-y-1">
          <label className="text-[11px] font-bold text-slate-500 uppercase tracking-wider">Ville</label>
          <input type="text" value={form.city} onChange={(e) => setForm({ ...form, city: e.target.value })} className="w-full bg-[#020617] border border-white/[0.08] rounded-xl px-3 py-2.5 text-sm text-white placeholder:text-slate-500 focus:border-[#00c8b3]/50 outline-none" />
        </div>

        <div className="space-y-1">
          <label className="text-[11px] font-bold text-slate-500 uppercase tracking-wider">Image URL</label>
          <div className="relative">
            <Image className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-500" />
            <input type="text" value={form.image} onChange={(e) => setForm({ ...form, image: e.target.value })} className="w-full bg-[#020617] border border-white/[0.08] rounded-xl pl-9 pr-3 py-2.5 text-sm text-white placeholder:text-slate-500 focus:border-[#00c8b3]/50 outline-none" />
          </div>
        </div>

        <button type="submit" disabled={updateMutation.isPending} className="w-full bg-[#00c8b3] text-[#020617] rounded-xl py-2.5 text-sm font-black flex items-center justify-center gap-2 disabled:opacity-50">
          {updateMutation.isPending ? <span className="w-4 h-4 border-2 border-[#020617]/30 border-t-[#020617] rounded-full animate-spin" /> : <Save className="w-4 h-4" />}
          Enregistrer le profil
        </button>
      </form>
    </div>
  );
}
