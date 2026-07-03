"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useQuery, useQueryClient, useMutation } from "@tanstack/react-query";
import { Store, MapPin, Utensils, Clock, ArrowRight, CheckCircle } from "lucide-react";
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

export default function OnboardingPage() {
  const router = useRouter();
  const queryClient = useQueryClient();
  const { data: restaurant, isLoading } = useQuery({
    queryKey: ["my-restaurant"],
    queryFn: () => restaurantApi.mine(),
    retry: false,
  });

  const [form, setForm] = useState({
    name: "",
    description: "",
    category: "",
    address: "",
    city: "",
    cuisineType: "",
    normalPrepTime: 15,
    rushPrepTime: 25,
    dietaryOptions: [] as string[],
  });

  useEffect(() => {
    if (restaurant?.id) router.replace("/partner/orders");
  }, [restaurant, router]);

  const createMutation = useMutation({
    mutationFn: (data: any) => restaurantApi.create(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["my-restaurant"] });
      queryClient.invalidateQueries({ queryKey: ["settings"] });
      showToast(" Restaurant créé !");
      router.replace("/partner/orders");
    },
    onError: (err: any) => showToast(err?.message || " Erreur lors de la création"),
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    createMutation.mutate({
      name: form.name,
      description: form.description,
      category: form.category,
      address: form.address,
      city: form.city,
      cuisineType: form.cuisineType,
      normalPrepTime: Number(form.normalPrepTime),
      rushPrepTime: Number(form.rushPrepTime),
      dietaryOptions: form.dietaryOptions,
    });
  };

  const toggleDietary = (opt: string) => {
    setForm((prev) => ({
      ...prev,
      dietaryOptions: prev.dietaryOptions.includes(opt) ? prev.dietaryOptions.filter((o) => o !== opt) : [...prev.dietaryOptions, opt],
    }));
  };

  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center" style={{ background: "#020617" }}>
        <div className="font-bebas text-3xl tracking-[8px] animate-pulse" style={{ color: "#00c8b3" }}> FAST</div>
      </div>
    );
  }

  return (
    <div className="min-h-screen p-4" style={{ background: "#020617" }}>
      <div className="max-w-md mx-auto pt-8 pb-12">
        <div className="text-center mb-8">
          <div className="font-bebas text-4xl tracking-[8px] bg-gradient-to-br from-[#00c8b3] to-[#ff0066] bg-clip-text text-transparent mb-2"> FAST</div>
          <h1 className="text-2xl font-black text-white mb-2">Créez votre restaurant</h1>
          <p className="text-sm text-slate-400">Quelques informations pour commencer à recevoir des commandes.</p>
        </div>

        <form onSubmit={handleSubmit} className="bg-[#0B1120] border border-white/[0.08] rounded-2xl p-5 space-y-4">
          <div className="space-y-1">
            <label className="text-[11px] font-bold text-slate-500 uppercase tracking-wider flex items-center gap-1"><Store className="w-3 h-3" /> Nom du restaurant *</label>
            <input type="text" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} className="w-full bg-[#020617] border border-white/[0.08] rounded-xl px-3 py-2.5 text-sm text-white placeholder:text-slate-500 focus:border-[#00c8b3]/50 outline-none" required />
          </div>

          <div className="space-y-1">
            <label className="text-[11px] font-bold text-slate-500 uppercase tracking-wider">Description</label>
            <textarea value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} className="w-full bg-[#020617] border border-white/[0.08] rounded-xl px-3 py-2.5 text-sm text-white placeholder:text-slate-500 focus:border-[#00c8b3]/50 outline-none min-h-[80px] resize-none" />
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-1">
              <label className="text-[11px] font-bold text-slate-500 uppercase tracking-wider flex items-center gap-1"><Utensils className="w-3 h-3" /> Cuisine</label>
              <input type="text" value={form.cuisineType} onChange={(e) => setForm({ ...form, cuisineType: e.target.value })} className="w-full bg-[#020617] border border-white/[0.08] rounded-xl px-3 py-2.5 text-sm text-white placeholder:text-slate-500 focus:border-[#00c8b3]/50 outline-none" />
            </div>
            <div className="space-y-1">
              <label className="text-[11px] font-bold text-slate-500 uppercase tracking-wider">Catégorie</label>
              <input type="text" value={form.category} onChange={(e) => setForm({ ...form, category: e.target.value })} className="w-full bg-[#020617] border border-white/[0.08] rounded-xl px-3 py-2.5 text-sm text-white placeholder:text-slate-500 focus:border-[#00c8b3]/50 outline-none" placeholder="fast-food" />
            </div>
          </div>

          <div className="space-y-1">
            <label className="text-[11px] font-bold text-slate-500 uppercase tracking-wider flex items-center gap-1"><MapPin className="w-3 h-3" /> Adresse</label>
            <input type="text" value={form.address} onChange={(e) => setForm({ ...form, address: e.target.value })} className="w-full bg-[#020617] border border-white/[0.08] rounded-xl px-3 py-2.5 text-sm text-white placeholder:text-slate-500 focus:border-[#00c8b3]/50 outline-none" />
          </div>

          <div className="space-y-1">
            <label className="text-[11px] font-bold text-slate-500 uppercase tracking-wider">Ville</label>
            <input type="text" value={form.city} onChange={(e) => setForm({ ...form, city: e.target.value })} className="w-full bg-[#020617] border border-white/[0.08] rounded-xl px-3 py-2.5 text-sm text-white placeholder:text-slate-500 focus:border-[#00c8b3]/50 outline-none" />
          </div>

          <div className="space-y-1">
            <label className="text-[11px] font-bold text-slate-500 uppercase tracking-wider flex items-center gap-1"><Clock className="w-3 h-3" /> Temps de préparation (min)</label>
            <div className="grid grid-cols-2 gap-3">
              <input type="number" min="5" max="60" value={form.normalPrepTime} onChange={(e) => setForm({ ...form, normalPrepTime: Number(e.target.value) })} className="w-full bg-[#020617] border border-white/[0.08] rounded-xl px-3 py-2 text-sm text-white focus:border-[#00c8b3]/50 outline-none" />
              <input type="number" min="10" max="90" value={form.rushPrepTime} onChange={(e) => setForm({ ...form, rushPrepTime: Number(e.target.value) })} className="w-full bg-[#020617] border border-white/[0.08] rounded-xl px-3 py-2 text-sm text-white focus:border-[#00c8b3]/50 outline-none" placeholder="Rush" />
            </div>
          </div>

          <div className="space-y-2">
            <label className="text-[11px] font-bold text-slate-500 uppercase tracking-wider">Options diététiques</label>
            <div className="flex flex-wrap gap-2">
              {DIETARY_OPTIONS.map((opt) => (
                <button key={opt.value} type="button" onClick={() => toggleDietary(opt.value)} className={`px-2.5 py-1 rounded-full text-[11px] font-bold border transition-all ${form.dietaryOptions.includes(opt.value) ? "border-[#00c8b3] text-[#00c8b3] bg-[#00c8b3]/10" : "border-white/10 text-slate-400 hover:border-white/20"}`}>{opt.label}</button>
              ))}
            </div>
          </div>

          <button type="submit" disabled={createMutation.isPending} className="w-full bg-[#00c8b3] text-[#020617] rounded-xl py-3 text-sm font-black flex items-center justify-center gap-2 disabled:opacity-50 mt-2">
            {createMutation.isPending ? <span className="w-4 h-4 border-2 border-[#020617]/30 border-t-[#020617] rounded-full animate-spin" /> : <CheckCircle className="w-4 h-4" />}
            Créer mon restaurant
            <ArrowRight className="w-4 h-4" />
          </button>
        </form>
      </div>
    </div>
  );
}
