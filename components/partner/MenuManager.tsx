"use client";

import { useEffect, useMemo, useState } from "react";
import { useQuery, useQueryClient, useMutation } from "@tanstack/react-query";
import { motion, AnimatePresence } from "framer-motion";
import { Plus, Pencil, Trash2, Save, X, ChevronDown, ChevronUp, AlertCircle } from "lucide-react";
import { menuApi, restaurantApi } from "@/api/fastBackend";
import { showToast } from "@/components/partner/Toast";

const DIETARY_OPTIONS = [
  { value: "VEGAN", label: "Vegan", color: "bg-green-500" },
  { value: "VEGETARIAN", label: "Végétarien", color: "bg-lime-500" },
  { value: "GLUTEN_FREE", label: "Sans gluten", color: "bg-yellow-500" },
  { value: "HALAL", label: "Halal", color: "bg-teal-500" },
  { value: "KETO", label: "Keto", color: "bg-orange-500" },
  { value: "DAIRY_FREE", label: "Sans lactose", color: "bg-blue-500" },
];

export default function MenuManager() {
  const queryClient = useQueryClient();
  const [restaurantId, setRestaurantId] = useState<string | null>(null);
  const [expanded, setExpanded] = useState<Record<string, boolean>>({});
  const [isEditing, setIsEditing] = useState<string | null>(null);
  const [form, setForm] = useState({
    name: "",
    description: "",
    price: "",
    image: "",
    category: "",
    dietaryTags: [] as string[],
    isAvailable: true,
  });

  const { data: restaurant } = useQuery({
    queryKey: ["my-restaurant"],
    queryFn: () => restaurantApi.mine(),
  });

  useEffect(() => {
    if (restaurant?.id) setRestaurantId(restaurant.id);
  }, [restaurant]);

  const { data: items = [], isLoading: itemsLoading } = useQuery({
    queryKey: ["menu-items", restaurantId],
    queryFn: () => (restaurantId ? menuApi.byRestaurant(restaurantId) : Promise.resolve([])),
    enabled: !!restaurantId,
  });

  const categories = useMemo(() => {
    const map = new Map<string, typeof items>();
    items.forEach((item: any) => {
      const cat = item.category || "Sans catégorie";
      if (!map.has(cat)) map.set(cat, []);
      map.get(cat)!.push(item);
    });
    return Array.from(map.entries()).sort((a, b) => a[0].localeCompare(b[0]));
  }, [items]);

  const createMutation = useMutation({
    mutationFn: (data: any) => menuApi.create(restaurantId!, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["menu-items", restaurantId] });
      resetForm();
      showToast(" Article ajouté");
    },
    onError: (err: any) => showToast(err?.message || " Erreur"),
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, data }: { id: string; data: any }) => menuApi.update(id, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["menu-items", restaurantId] });
      setIsEditing(null);
      resetForm();
      showToast(" Article mis à jour");
    },
    onError: (err: any) => showToast(err?.message || " Erreur"),
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => menuApi.delete(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["menu-items", restaurantId] });
      showToast(" Article retiré");
    },
    onError: (err: any) => showToast(err?.message || " Erreur"),
  });

  const toggleAvailMutation = useMutation({
    mutationFn: ({ id, isAvailable }: { id: string; isAvailable: boolean }) => menuApi.update(id, { isAvailable }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["menu-items", restaurantId] });
      showToast(" Disponibilité mise à jour");
    },
    onError: (err: any) => showToast(err?.message || " Erreur"),
  });

  const resetForm = () => {
    setIsEditing(null);
    setForm({ name: "", description: "", price: "", image: "", category: "", dietaryTags: [], isAvailable: true });
  };

  const startEdit = (item: any) => {
    setIsEditing(item.id);
    setForm({
      name: item.name || "",
      description: item.description || "",
      price: item.price?.toString() || "",
      image: item.image || "",
      category: item.category || "",
      dietaryTags: item.dietaryTags?.map((t: any) => t.option) || [],
      isAvailable: item.isAvailable !== false,
    });
    window.scrollTo({ top: 0, behavior: "smooth" });
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!restaurantId) return;
    const price = parseFloat(form.price);
    if (!form.name || isNaN(price) || price <= 0) {
      showToast(" Nom et prix valides requis");
      return;
    }
    const payload = {
      name: form.name,
      description: form.description,
      price,
      image: form.image,
      category: form.category,
      dietaryTags: form.dietaryTags,
      isAvailable: form.isAvailable,
    };
    if (isEditing) {
      updateMutation.mutate({ id: isEditing, data: payload });
    } else {
      createMutation.mutate(payload);
    }
  };

  const toggleTag = (tag: string) => {
    setForm((prev) => ({
      ...prev,
      dietaryTags: prev.dietaryTags.includes(tag) ? prev.dietaryTags.filter((t) => t !== tag) : [...prev.dietaryTags, tag],
    }));
  };

  const isPending = createMutation.isPending || updateMutation.isPending || deleteMutation.isPending || toggleAvailMutation.isPending;

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-lg font-black text-white">Gestion du menu</h1>
        <span className="text-xs text-slate-400">{items.length} article{items.length > 1 ? "s" : ""}</span>
      </div>

      <form onSubmit={handleSubmit} className="bg-[#0B1120] border border-white/[0.08] rounded-2xl p-4 space-y-3">
        <div className="flex items-center gap-2 text-sm font-bold text-[#00c8b3]">
          {isEditing ? <Pencil className="w-4 h-4" /> : <Plus className="w-4 h-4" />}
          {isEditing ? "Modifier l'article" : "Ajouter un article"}
        </div>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <input type="text" placeholder="Nom du plat *" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} className="bg-[#020617] border border-white/[0.08] rounded-xl px-3 py-2.5 text-sm text-white placeholder:text-slate-500 focus:border-[#00c8b3]/50 outline-none" required />
          <input type="number" step="0.01" min="0.01" placeholder="Prix () *" value={form.price} onChange={(e) => setForm({ ...form, price: e.target.value })} className="bg-[#020617] border border-white/[0.08] rounded-xl px-3 py-2.5 text-sm text-white placeholder:text-slate-500 focus:border-[#00c8b3]/50 outline-none" required />
        </div>
        <input type="text" placeholder="Catégorie (ex: Burgers, Boissons...)" value={form.category} onChange={(e) => setForm({ ...form, category: e.target.value })} className="w-full bg-[#020617] border border-white/[0.08] rounded-xl px-3 py-2.5 text-sm text-white placeholder:text-slate-500 focus:border-[#00c8b3]/50 outline-none" />
        <input type="text" placeholder="URL image (optionnel)" value={form.image} onChange={(e) => setForm({ ...form, image: e.target.value })} className="w-full bg-[#020617] border border-white/[0.08] rounded-xl px-3 py-2.5 text-sm text-white placeholder:text-slate-500 focus:border-[#00c8b3]/50 outline-none" />
        <textarea placeholder="Description (optionnel)" value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} className="w-full bg-[#020617] border border-white/[0.08] rounded-xl px-3 py-2.5 text-sm text-white placeholder:text-slate-500 focus:border-[#00c8b3]/50 outline-none min-h-[72px] resize-none" />
        <div>
          <p className="text-[11px] font-bold text-slate-500 uppercase tracking-wider mb-2">Tags diététiques</p>
          <div className="flex flex-wrap gap-2">
            {DIETARY_OPTIONS.map((opt) => (
              <button key={opt.value} type="button" onClick={() => toggleTag(opt.value)} className={`px-2.5 py-1 rounded-full text-[11px] font-bold border transition-all ${form.dietaryTags.includes(opt.value) ? "border-[#00c8b3] text-[#00c8b3] bg-[#00c8b3]/10" : "border-white/10 text-slate-400 hover:border-white/20"}`}>{opt.label}</button>
            ))}
          </div>
        </div>
        <div className="flex items-center gap-3 pt-1">
          <button type="submit" disabled={isPending} className="flex-1 bg-[#00c8b3] text-[#020617] rounded-xl py-2.5 text-sm font-black flex items-center justify-center gap-2 disabled:opacity-50">
            {isPending ? <span className="w-4 h-4 border-2 border-[#020617]/30 border-t-[#020617] rounded-full animate-spin" /> : <Save className="w-4 h-4" />}
            {isEditing ? "Enregistrer" : "Ajouter"}
          </button>
          {isEditing && <button type="button" onClick={resetForm} className="px-4 py-2.5 rounded-xl border border-white/10 text-slate-300 text-sm font-bold hover:bg-white/5"><X className="w-4 h-4" /></button>}
        </div>
      </form>

      {itemsLoading ? (
        <div className="py-12 text-center text-slate-500 text-sm">Chargement du menu...</div>
      ) : categories.length === 0 ? (
        <div className="bg-[#0B1120] border border-white/[0.08] rounded-2xl p-8 text-center text-slate-400 text-sm">
          <AlertCircle className="w-8 h-8 mx-auto mb-2 text-slate-500" />Aucun article. Ajoutez votre premier plat ci-dessus.
        </div>
      ) : (
        categories.map(([category, catItems]) => (
          <div key={category} className="bg-[#0B1120] border border-white/[0.08] rounded-2xl overflow-hidden">
            <button onClick={() => setExpanded((prev) => ({ ...prev, [category]: !prev[category] }))} className="w-full flex items-center justify-between px-4 py-3 bg-white/[0.02]">
              <span className="text-sm font-black text-white">{category}</span>
              <span className="text-xs text-slate-400 flex items-center gap-1">{catItems.length} article{catItems.length > 1 ? "s" : ""}{expanded[category] ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}</span>
            </button>
            <AnimatePresence>
              {expanded[category] !== false && (
                <motion.div initial={{ height: 0, opacity: 0 }} animate={{ height: "auto", opacity: 1 }} exit={{ height: 0, opacity: 0 }} className="overflow-hidden">
                  <div className="p-2 space-y-2">
                    {catItems.map((item: any) => (
                      <div key={item.id} className={`flex items-center gap-3 p-3 rounded-xl border ${item.isAvailable === false ? "border-white/5 bg-white/[0.02] opacity-60" : "border-white/[0.06] bg-[#020617]"}`}>
                        <div className="w-12 h-12 rounded-xl bg-white/[0.06] flex items-center justify-center text-lg flex-shrink-0 overflow-hidden">{item.image ? <img src={item.image} alt="" className="w-full h-full object-cover" /> : ""}</div>
                        <div className="flex-1 min-w-0">
                          <div className="flex items-center gap-2 flex-wrap">
                            <span className="text-sm font-bold text-white truncate">{item.name}</span>
                            {item.dietaryTags?.map((t: any) => {
                              const opt = DIETARY_OPTIONS.find((o) => o.value === t.option);
                              return opt ? <span key={t.option} className={`text-[9px] font-black text-white px-1.5 py-0.5 rounded-full ${opt.color}`}>{opt.label}</span> : null;
                            })}
                          </div>
                          <p className="text-xs text-slate-400 truncate">{item.description || "Pas de description"}</p>
                          <p className="text-xs font-black text-[#00c8b3] mt-0.5">{item.price?.toFixed(2)} </p>
                        </div>
                        <div className="flex items-center gap-1">
                          <button onClick={() => startEdit(item)} className="w-8 h-8 rounded-lg bg-white/[0.06] text-slate-300 flex items-center justify-center hover:bg-white/10"><Pencil className="w-4 h-4" /></button>
                          <button onClick={() => toggleAvailMutation.mutate({ id: item.id, isAvailable: item.isAvailable === false })} className={`w-8 h-8 rounded-lg flex items-center justify-center text-xs font-black ${item.isAvailable === false ? "bg-green-500/20 text-green-400" : "bg-white/[0.06] text-slate-300"}`} title={item.isAvailable === false ? "Rendre disponible" : "Rendre indisponible"}>{item.isAvailable === false ? "" : ""}</button>
                          <button onClick={() => deleteMutation.mutate(item.id)} className="w-8 h-8 rounded-lg bg-red-500/10 text-red-400 flex items-center justify-center hover:bg-red-500/20"><Trash2 className="w-4 h-4" /></button>
                        </div>
                      </div>
                    ))}
                  </div>
                </motion.div>
              )}
            </AnimatePresence>
          </div>
        ))
      )}
    </div>
  );
}
