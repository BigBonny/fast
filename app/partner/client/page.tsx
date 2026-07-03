"use client";

import { useEffect, useState } from "react";
import { motion } from "framer-motion";
import { Users, Star, ShoppingBag, Clock, Search, Plus, Trash2 } from "lucide-react";
import { useQuery } from "@tanstack/react-query";
import { orderApi } from "@/api/fastBackend";
import { showToast } from "@/components/partner/Toast";

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
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-lg font-black text-white">Clients</h1>
        <button onClick={() => setIsOpen(true)} className="px-3 py-2 rounded-xl bg-[#00c8b3] text-[#020617] text-xs font-black flex items-center gap-1"><Plus className="w-4 h-4" /> Ajouter</button>
      </div>

      <div className="relative">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-500" />
        <input type="text" value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Rechercher un client..." className="w-full bg-[#0B1120] border border-white/[0.08] rounded-xl pl-9 pr-3 py-2.5 text-sm text-white placeholder:text-slate-500 outline-none focus:border-[#00c8b3]/50" />
      </div>

      {filtered.length === 0 ? (
        <div className="bg-[#0B1120] border border-white/[0.08] rounded-2xl p-8 text-center text-slate-400 text-sm"><Users className="w-8 h-8 mx-auto mb-2 text-slate-500" />Aucun client trouvé.</div>
      ) : (
        <div className="space-y-2">
          {filtered.map((c) => (
            <motion.div key={c.id} layout className="bg-[#0B1120] border border-white/[0.08] rounded-2xl p-4">
              <div className="flex items-start justify-between gap-3">
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-bold text-white">{c.name}</p>
                  {c.phone && <p className="text-[11px] text-slate-400">{c.phone}</p>}
                  {c.notes && <p className="text-[11px] text-slate-500 mt-1">{c.notes}</p>}
                  <div className="flex items-center gap-3 mt-2 text-[11px] text-slate-500">
                    <span className="flex items-center gap-1"><ShoppingBag className="w-3 h-3" /> {c.orders || 0} commande{(c.orders || 0) > 1 ? "s" : ""}</span>
                    {c.lastOrder && <span className="flex items-center gap-1"><Clock className="w-3 h-3" /> {new Date(c.lastOrder).toLocaleDateString("fr-FR")}</span>}
                  </div>
                </div>
                <div className="flex items-center gap-1">
                  <span className="flex items-center gap-1 text-[11px] font-bold text-yellow-400"><Star className="w-3 h-3 fill-current" /> 5.0</span>
                  <button onClick={() => remove(c.id)} className="w-8 h-8 rounded-lg bg-red-500/10 text-red-400 flex items-center justify-center hover:bg-red-500/20"><Trash2 className="w-4 h-4" /></button>
                </div>
              </div>
            </motion.div>
          ))}
        </div>
      )}

      {isOpen && (
        <div className="fixed inset-0 z-[9000] flex items-end sm:items-center justify-center p-4 bg-black/60 backdrop-blur-sm">
          <div className="bg-[#0B1120] border border-white/[0.08] rounded-2xl p-5 w-full max-w-md space-y-4">
            <p className="text-sm font-black text-white">Ajouter un client</p>
            <form onSubmit={handleSubmit} className="space-y-3">
              <input type="text" placeholder="Nom" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} className="w-full bg-[#020617] border border-white/[0.08] rounded-xl px-3 py-2.5 text-sm text-white placeholder:text-slate-500 outline-none focus:border-[#00c8b3]/50" required />
              <input type="tel" placeholder="Téléphone" value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} className="w-full bg-[#020617] border border-white/[0.08] rounded-xl px-3 py-2.5 text-sm text-white placeholder:text-slate-500 outline-none focus:border-[#00c8b3]/50" />
              <textarea placeholder="Notes" value={form.notes} onChange={(e) => setForm({ ...form, notes: e.target.value })} className="w-full bg-[#020617] border border-white/[0.08] rounded-xl px-3 py-2.5 text-sm text-white placeholder:text-slate-500 outline-none focus:border-[#00c8b3]/50 min-h-[80px] resize-none" />
              <div className="flex gap-2 pt-2">
                <button type="button" onClick={() => setIsOpen(false)} className="flex-1 py-2.5 rounded-xl border border-white/10 text-slate-300 text-sm font-bold">Annuler</button>
                <button type="submit" className="flex-1 py-2.5 rounded-xl bg-[#00c8b3] text-[#020617] text-sm font-black">Ajouter</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
