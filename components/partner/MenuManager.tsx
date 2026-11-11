"use client";

import { useEffect, useMemo, useState } from "react";
import { useQuery, useQueryClient, useMutation } from "@tanstack/react-query";
import { m, AnimatePresence } from "framer-motion";
import { Plus, Pencil, Trash2, Save, X, ChevronDown, ChevronUp, AlertCircle, UtensilsCrossed } from "lucide-react";
import { menuApi, restaurantApi } from "@/api/fastBackend";
import { showToast } from "@/components/partner/Toast";
import SafeImage from "@/components/SafeImage";

const DIETARY_OPTIONS = [
  { value: "VEGAN", label: "Vegan", color: "bg-green-500" },
  { value: "VEGETARIAN", label: "Végétarien", color: "bg-lime-500" },
  { value: "GLUTEN_FREE", label: "Sans gluten", color: "bg-yellow-500" },
  { value: "HALAL", label: "Halal", color: "bg-teal-500" },
  { value: "KETO", label: "Keto", color: "bg-orange-500" },
  { value: "DAIRY_FREE", label: "Sans lactose", color: "bg-blue-500" },
];

const sectionLabel = "text-xs font-bold uppercase tracking-wide text-muted-foreground";
const inputClass =
  "w-full min-h-[44px] bg-background border border-border rounded-xl px-3 py-2.5 text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:border-fast-teal focus:ring-2 focus:ring-fast-teal/30";
const chipClass = (on: boolean) =>
  `inline-flex items-center px-4 min-h-[44px] rounded-full text-xs font-bold border transition-colors focus-visible:outline-fast-teal ${
    on ? "border-fast-teal bg-fast-teal/15 text-foreground" : "border-border text-muted-foreground hover:text-foreground"
  }`;
const iconButton =
  "w-11 h-11 rounded-full border border-border text-muted-foreground flex items-center justify-center transition-colors hover:bg-muted hover:text-foreground focus-visible:outline-fast-teal";

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
    queryFn: () => (restaurantId ? menuApi.managed(restaurantId) : Promise.resolve([])),
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
      // The server treats the submitted price as the BASE price and adds
      // FAST's markup; pre-filling the customer price would add it twice.
      price: (item.basePrice ?? item.price)?.toString() || "",
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
    <div className="space-y-8">
      <div className="flex items-end justify-between gap-3">
        <h1 className="font-display text-2xl font-bold text-foreground">Gestion du menu</h1>
        <span className="text-xs text-muted-foreground tabular-nums">{items.length} article{items.length > 1 ? "s" : ""}</span>
      </div>

      <form onSubmit={handleSubmit} className="bg-card border border-border rounded-2xl p-4 space-y-3">
        <div className={`flex items-center gap-2 ${sectionLabel}`}>
          {isEditing ? <Pencil className="w-4 h-4 text-fast-teal" /> : <Plus className="w-4 h-4 text-fast-teal" />}
          {isEditing ? "Modifier l'article" : "Ajouter un article"}
        </div>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <input type="text" placeholder="Nom du plat *" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} className={inputClass} required />
          <input type="number" step="0.01" min="0.01" placeholder="Prix de base (€) *" title="Votre prix, avant les frais FAST ajoutés au prix client" value={form.price} onChange={(e) => setForm({ ...form, price: e.target.value })} className={`${inputClass} tabular-nums`} required />
        </div>
        <input type="text" placeholder="Catégorie (ex: Burgers, Boissons...)" value={form.category} onChange={(e) => setForm({ ...form, category: e.target.value })} className={inputClass} />
        <input type="text" placeholder="URL image (optionnel)" value={form.image} onChange={(e) => setForm({ ...form, image: e.target.value })} className={inputClass} />
        <textarea placeholder="Description (optionnel)" value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} className={`${inputClass} min-h-[72px] resize-none`} />
        <div>
          <p className={`${sectionLabel} mb-2`}>Tags diététiques</p>
          <div className="flex flex-wrap gap-2">
            {DIETARY_OPTIONS.map((opt) => (
              <button key={opt.value} type="button" onClick={() => toggleTag(opt.value)} aria-pressed={form.dietaryTags.includes(opt.value)} className={chipClass(form.dietaryTags.includes(opt.value))}>{opt.label}</button>
            ))}
          </div>
        </div>
        <div className="flex items-center gap-3 pt-1">
          <button type="submit" disabled={isPending} className="btn-neon flex-1 text-sm">
            {isPending ? <span className="w-4 h-4 border-2 border-fast-ink/30 border-t-fast-ink rounded-full animate-spin" /> : <Save className="w-4 h-4" />}
            {isEditing ? "Enregistrer" : "Ajouter"}
          </button>
          {isEditing && <button type="button" onClick={resetForm} aria-label="Annuler" className="btn-outline !min-h-[3rem] !px-4"><X className="w-4 h-4" /></button>}
        </div>
      </form>

      {itemsLoading ? (
        <div className="py-12 text-center text-muted-foreground text-sm">Chargement du menu...</div>
      ) : categories.length === 0 ? (
        <div className="bg-card border border-border rounded-2xl p-8 text-center text-muted-foreground text-sm">
          <AlertCircle className="w-8 h-8 mx-auto mb-2 text-muted-foreground" />Aucun article. Ajoutez votre premier plat ci-dessus.
        </div>
      ) : (
        categories.map(([category, catItems]) => (
          <section key={category} className="space-y-2">
            <button onClick={() => setExpanded((prev) => ({ ...prev, [category]: !prev[category] }))} aria-expanded={expanded[category] !== false} className="w-full min-h-[44px] flex items-center justify-between gap-3 text-left focus-visible:outline-fast-teal">
              <span className="font-display text-xl font-bold text-foreground">{category}</span>
              <span className="text-xs text-muted-foreground flex items-center gap-1 tabular-nums flex-shrink-0">{catItems.length} article{catItems.length > 1 ? "s" : ""}{expanded[category] ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}</span>
            </button>
            <AnimatePresence>
              {expanded[category] !== false && (
                <m.div initial={{ height: 0, opacity: 0 }} animate={{ height: "auto", opacity: 1 }} exit={{ height: 0, opacity: 0 }} className="overflow-hidden">
                  <div className="bg-card border border-border rounded-2xl divide-y divide-border">
                    {catItems.map((item: any) => {
                      const available = item.isAvailable !== false;
                      return (
                        <div key={item.id} className="flex flex-wrap items-center gap-3 p-3 sm:p-4">
                          <div className={`w-14 h-14 rounded-xl bg-muted text-muted-foreground flex items-center justify-center flex-shrink-0 overflow-hidden ${available ? "" : "opacity-50"}`}>{item.image ? <SafeImage src={item.image} alt="" width={56} height={56} className="w-full h-full object-cover" /> : <UtensilsCrossed className="w-5 h-5" aria-hidden="true" />}</div>
                          <div className={`flex-1 min-w-[160px] ${available ? "" : "opacity-50"}`}>
                            <p className="text-sm font-bold text-foreground truncate">{item.name}</p>
                            <p className="text-xs text-muted-foreground truncate">{item.description || "Pas de description"}</p>
                            <div className="flex items-center gap-x-3 gap-y-1 flex-wrap mt-1">
                              <span className="text-sm font-bold text-foreground tabular-nums">{item.price?.toFixed(2)} </span>
                              {item.dietaryTags?.map((t: any) => {
                                const opt = DIETARY_OPTIONS.find((o) => o.value === t.option);
                                return opt ? (
                                  <span key={t.option} className="inline-flex items-center gap-1.5 text-xs font-semibold text-muted-foreground">
                                    <span className={`w-2 h-2 rounded-full ${opt.color}`} aria-hidden="true" />{opt.label}
                                  </span>
                                ) : null;
                              })}
                            </div>
                          </div>
                          <div className="flex items-center gap-1.5 flex-shrink-0 ml-auto">
                            <button
                              type="button"
                              role="switch"
                              aria-checked={available}
                              onClick={() => toggleAvailMutation.mutate({ id: item.id, isAvailable: item.isAvailable === false })}
                              title={item.isAvailable === false ? "Rendre disponible" : "Rendre indisponible"}
                              aria-label={item.isAvailable === false ? "Rendre disponible" : "Rendre indisponible"}
                              className="h-11 px-1 flex items-center focus-visible:outline-fast-teal"
                            >
                              <span className={`relative w-11 h-6 rounded-full transition-colors ${available ? "bg-fast-teal" : "bg-muted border border-border"}`}>
                                <span className={`absolute top-1/2 -translate-y-1/2 w-5 h-5 rounded-full bg-white shadow transition-all ${available ? "left-[22px]" : "left-0.5"}`} />
                              </span>
                            </button>
                            <button onClick={() => startEdit(item)} aria-label="Modifier" className={iconButton}><Pencil className="w-4 h-4" /></button>
                            <button onClick={() => deleteMutation.mutate(item.id)} aria-label="Supprimer" className={`${iconButton} hover:!text-[color:var(--red)]`}><Trash2 className="w-4 h-4" /></button>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </m.div>
              )}
            </AnimatePresence>
          </section>
        ))
      )}
    </div>
  );
}
