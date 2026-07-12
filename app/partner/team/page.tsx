"use client";

import { useEffect, useState } from "react";
import { m } from "framer-motion";
import { Plus, Trash2, User, Mail, Phone, ChefHat, Shield, Bike } from "lucide-react";
import { showToast } from "@/components/partner/Toast";

const ROLES = [
  { value: "manager", label: "Manager", icon: Shield },
  { value: "cuisinier", label: "Cuisinier", icon: ChefHat },
  { value: "livreur", label: "Livreur", icon: Bike },
  { value: "serveur", label: "Serveur", icon: User },
];

export default function TeamPage() {
  const [members, setMembers] = useState<any[]>([]);
  const [form, setForm] = useState({ name: "", email: "", phone: "", role: "serveur" });
  const [isOpen, setIsOpen] = useState(false);

  useEffect(() => {
    const saved = localStorage.getItem("fast_team");
    if (saved) setMembers(JSON.parse(saved));
  }, []);

  useEffect(() => {
    localStorage.setItem("fast_team", JSON.stringify(members));
  }, [members]);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!form.name) return;
    setMembers((prev) => [...prev, { id: crypto.randomUUID(), ...form }]);
    setForm({ name: "", email: "", phone: "", role: "serveur" });
    setIsOpen(false);
    showToast(" Membre ajouté");
  };

  const remove = (id: string) => {
    setMembers((prev) => prev.filter((m) => m.id !== id));
    showToast(" Membre retiré");
  };

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-lg font-black text-white">Mon équipe</h1>
        <button onClick={() => setIsOpen(true)} className="px-3 py-2 rounded-xl bg-[#00c8b3] text-[#020617] text-xs font-black flex items-center gap-1"><Plus className="w-4 h-4" /> Ajouter</button>
      </div>

      {members.length === 0 ? (
        <div className="bg-[#0B1120] border border-white/[0.08] rounded-2xl p-8 text-center text-slate-400 text-sm">
          <User className="w-8 h-8 mx-auto mb-2 text-slate-500" />Aucun membre d'équipe. Ajoutez votre premier collaborateur.
        </div>
      ) : (
        <div className="space-y-2">
          {members.map((m) => {
            const role = ROLES.find((r) => r.value === m.role) || ROLES[3];
            const Icon = role.icon;
            return (
              <m.div key={m.id} layout className="bg-[#0B1120] border border-white/[0.08] rounded-2xl p-4 flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-[#00c8b3]/10 flex items-center justify-center text-[#00c8b3]"><Icon className="w-5 h-5" /></div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-bold text-white">{m.name}</p>
                  <p className="text-[11px] text-slate-400">{role.label}</p>
                  <div className="text-[11px] text-slate-500 flex items-center gap-3 mt-1">
                    {m.email && <span className="flex items-center gap-1"><Mail className="w-3 h-3" /> {m.email}</span>}
                    {m.phone && <span className="flex items-center gap-1"><Phone className="w-3 h-3" /> {m.phone}</span>}
                  </div>
                </div>
                <button onClick={() => remove(m.id)} className="w-8 h-8 rounded-lg bg-red-500/10 text-red-400 flex items-center justify-center hover:bg-red-500/20"><Trash2 className="w-4 h-4" /></button>
              </m.div>
            );
          })}
        </div>
      )}

      {isOpen && (
        <div className="fixed inset-0 z-[9000] flex items-end sm:items-center justify-center p-4 bg-black/60 backdrop-blur-sm">
          <div className="bg-[#0B1120] border border-white/[0.08] rounded-2xl p-5 w-full max-w-md space-y-4">
            <p className="text-sm font-black text-white">Ajouter un membre</p>
            <form onSubmit={handleSubmit} className="space-y-3">
              <input type="text" placeholder="Nom" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} className="w-full bg-[#020617] border border-white/[0.08] rounded-xl px-3 py-2.5 text-sm text-white placeholder:text-slate-500 outline-none focus:border-[#00c8b3]/50" required />
              <input type="email" placeholder="Email" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} className="w-full bg-[#020617] border border-white/[0.08] rounded-xl px-3 py-2.5 text-sm text-white placeholder:text-slate-500 outline-none focus:border-[#00c8b3]/50" />
              <input type="tel" placeholder="Téléphone" value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} className="w-full bg-[#020617] border border-white/[0.08] rounded-xl px-3 py-2.5 text-sm text-white placeholder:text-slate-500 outline-none focus:border-[#00c8b3]/50" />
              <div className="flex flex-wrap gap-2">
                {ROLES.map((r) => (
                  <button key={r.value} type="button" onClick={() => setForm({ ...form, role: r.value })} className={`px-3 py-1.5 rounded-full text-[11px] font-bold border transition-all ${form.role === r.value ? "border-[#00c8b3] text-[#00c8b3] bg-[#00c8b3]/10" : "border-white/10 text-slate-400"}`}>{r.label}</button>
                ))}
              </div>
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
