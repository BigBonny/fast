"use client";

import { useEffect, useState } from "react";
import { m } from "framer-motion";
import { Users, Star, ShoppingBag, Clock, Search, Plus, Trash2 } from "lucide-react";
import { useQuery } from "@tanstack/react-query";
import { orderApi } from "@/api/fastBackend";
import { showToast } from "@/components/partner/Toast";

const sectionLabel = "text-xs font-bold uppercase tracking-wide text-muted-foreground";
const inputClass =
  "w-full min-h-[44px] bg-background border border-border rounded-xl px-3 py-2.5 text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:border-fast-teal focus:ring-2 focus:ring-fast-teal/30";

export default function ClientPage() {
  const { data: orders = [] } = useQuery({ queryKey: ["orders"], queryFn: () => orderApi.restaurantOrders() });

  const [clients, setClients] = useState<any[]>([]);
  const [search, setSearch] = useState("");
  const [form, setForm] = useState({ name: "", phone: "", notes: "" });
  const [isOpen, setIsOpen] = useState(false);

  useEffect(() => {
    const saved = localStorage.getItem("fast_clients");
    const base = JSON.parse(saved || "[]");
    const fromOrders = orders.reduce((acc: any[], o: any) => {
      if (!o.user || acc.find((c) => c.userId === o.userId)) return acc;
      return [...acc, { id: o.userId, userId: o.userId, name: o.user.name || "Client", orders: 1, lastOrder: o.createdAt }];
    }, []);
    const merged = [...fromOrders, ...base.filter((c: any) => !c.userId)];
    setClients(merged);
  }, [orders]);

  useEffect(() => {
    localStorage.setItem("fast_clients", JSON.stringify(clients));
  }, [clients]);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!form.name) return;
    setClients((prev) => [...prev, { id: crypto.randomUUID(), name: form.name, phone: form.phone, notes: form.notes, orders: 0 }]);
    setForm({ name: "", phone: "", notes: "" });
    setIsOpen(false);
    showToast(" Client ajouté");
  };

  const remove = (id: string) => {
    setClients((prev) => prev.filter((c) => c.id !== id));
    showToast(" Client retiré");
  };

  const filtered = clients.filter((c) => c.name?.toLowerCase().includes(search.toLowerCase()) || c.phone?.includes(search));

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between gap-3">
        <h1 className="font-display text-2xl font-bold text-foreground">Clients</h1>
        <button onClick={() => setIsOpen(true)} className="btn-neon !min-h-[44px] !px-5 text-sm"><Plus className="w-4 h-4" /> Ajouter</button>
      </div>

      <div className="relative">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
        <input type="text" value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Rechercher un client..." className={`${inputClass} !bg-card !pl-9`} />
      </div>

      {filtered.length === 0 ? (
        <div className="bg-card border border-border rounded-2xl p-8 text-center text-muted-foreground text-sm"><Users className="w-8 h-8 mx-auto mb-2 text-muted-foreground" />Aucun client trouvé.</div>
      ) : (
        <div className="space-y-3">
          {filtered.map((c) => (
            <m.div key={c.id} layout className="bg-card border border-border rounded-2xl p-4">
              <div className="flex items-start justify-between gap-3">
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-bold text-foreground">{c.name}</p>
                  {c.phone && <p className="text-xs text-muted-foreground tabular-nums">{c.phone}</p>}
                  {c.notes && <p className="text-xs text-muted-foreground mt-1">{c.notes}</p>}
                  <div className="flex items-center gap-3 flex-wrap mt-2 text-xs text-muted-foreground tabular-nums">
                    <span className="flex items-center gap-1"><ShoppingBag className="w-3.5 h-3.5" /> {c.orders || 0} commande{(c.orders || 0) > 1 ? "s" : ""}</span>
                    {c.lastOrder && <span className="flex items-center gap-1"><Clock className="w-3.5 h-3.5" /> {new Date(c.lastOrder).toLocaleDateString("fr-FR")}</span>}
                  </div>
                </div>
                <div className="flex items-center gap-2 flex-shrink-0">
                  <span className="flex items-center gap-1 text-xs font-bold text-foreground tabular-nums"><Star className="w-3.5 h-3.5 text-yellow-400 fill-current" /> 5.0</span>
                  <button onClick={() => remove(c.id)} aria-label="Supprimer" className="w-11 h-11 rounded-full border border-[color:var(--red)] text-[color:var(--red)] flex items-center justify-center transition-colors hover:bg-red-500/10"><Trash2 className="w-4 h-4" /></button>
                </div>
              </div>
            </m.div>
          ))}
        </div>
      )}

      {isOpen && (
        <div className="fixed inset-0 z-[9000] flex items-end sm:items-center justify-center p-4 bg-black/60 backdrop-blur-sm">
          <div className="bg-card text-foreground border border-border rounded-2xl p-5 w-full max-w-md space-y-4">
            <p className="font-display text-xl font-bold text-foreground">Ajouter un client</p>
            <form onSubmit={handleSubmit} className="space-y-3">
              <input type="text" placeholder="Nom" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} className={inputClass} required />
              <input type="tel" placeholder="Téléphone" value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} className={inputClass} />
              <textarea placeholder="Notes" value={form.notes} onChange={(e) => setForm({ ...form, notes: e.target.value })} className={`${inputClass} min-h-[80px] resize-none`} />
              <div className="flex gap-2 pt-2">
                <button type="button" onClick={() => setIsOpen(false)} className="btn-outline flex-1 text-sm !min-h-[3rem]">Annuler</button>
                <button type="submit" className="btn-neon flex-1 text-sm">Ajouter</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
