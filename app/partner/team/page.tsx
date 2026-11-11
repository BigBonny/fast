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

const sectionLabel = "text-xs font-bold uppercase tracking-wide text-muted-foreground";
const inputClass =
  "w-full min-h-[44px] bg-background border border-border rounded-xl px-3 py-2.5 text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:border-fast-teal focus:ring-2 focus:ring-fast-teal/30";

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
    <div className="space-y-5">
      <div className="flex items-center justify-between gap-3">
        <h1 className="font-display text-2xl font-bold text-foreground">Mon équipe</h1>
        <button onClick={() => setIsOpen(true)} className="btn-neon !min-h-[44px] !px-5 text-sm"><Plus className="w-4 h-4" /> Ajouter</button>
      </div>

      {members.length === 0 ? (
        <div className="bg-card border border-border rounded-2xl p-8 text-center text-muted-foreground text-sm">
          <User className="w-8 h-8 mx-auto mb-2 text-muted-foreground" />Aucun membre d'équipe. Ajoutez votre premier collaborateur.
        </div>
      ) : (
        <div className="space-y-3">
          {members.map((m) => {
            const role = ROLES.find((r) => r.value === m.role) || ROLES[3];
            const Icon = role.icon;
            return (
              <m.div key={m.id} layout className="bg-card border border-border rounded-2xl p-4 flex items-center gap-3">
                <div className="w-11 h-11 rounded-xl bg-fast-teal/15 flex items-center justify-center text-fast-teal flex-shrink-0"><Icon className="w-5 h-5" /></div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-bold text-foreground">{m.name}</p>
                  <p className="text-xs text-muted-foreground">{role.label}</p>
                  <div className="text-xs text-muted-foreground flex items-center gap-x-3 gap-y-1 flex-wrap mt-1">
                    {m.email && <span className="flex items-center gap-1 min-w-0"><Mail className="w-3.5 h-3.5 flex-shrink-0" /> <span className="truncate">{m.email}</span></span>}
                    {m.phone && <span className="flex items-center gap-1 tabular-nums"><Phone className="w-3.5 h-3.5" /> {m.phone}</span>}
                  </div>
                </div>
                <button onClick={() => remove(m.id)} aria-label="Supprimer" className="w-11 h-11 rounded-full border border-[color:var(--red)] text-[color:var(--red)] flex items-center justify-center flex-shrink-0 transition-colors hover:bg-red-500/10"><Trash2 className="w-4 h-4" /></button>
              </m.div>
            );
          })}
        </div>
      )}

      {isOpen && (
        <div className="fixed inset-0 z-[9000] flex items-end sm:items-center justify-center p-4 bg-black/60 backdrop-blur-sm">
          <div className="bg-card text-foreground border border-border rounded-2xl p-5 w-full max-w-md space-y-4">
            <p className="font-display text-xl font-bold text-foreground">Ajouter un membre</p>
            <form onSubmit={handleSubmit} className="space-y-3">
              <input type="text" placeholder="Nom" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} className={inputClass} required />
              <input type="email" placeholder="Email" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} className={inputClass} />
              <input type="tel" placeholder="Téléphone" value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} className={inputClass} />
              <div className="flex flex-wrap gap-2">
                {ROLES.map((r) => (
                  <button key={r.value} type="button" onClick={() => setForm({ ...form, role: r.value })} aria-pressed={form.role === r.value} className={`inline-flex items-center px-4 min-h-[44px] rounded-full text-xs font-bold border transition-colors focus-visible:outline-fast-teal ${form.role === r.value ? "border-fast-teal bg-fast-teal/15 text-foreground" : "border-border text-muted-foreground hover:text-foreground"}`}>{r.label}</button>
                ))}
              </div>
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
