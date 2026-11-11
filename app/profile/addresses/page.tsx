"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/AuthContext";
import {
  Address,
  addAddress,
  getAddresses,
  removeAddress,
  setDefaultAddress,
} from "@/lib/localPreferences";
import { ArrowLeft, MapPin, Plus, Home, Trash2, X } from "lucide-react";
import Link from "next/link";
import AddressAutocomplete from "@/components/AddressAutocomplete";

export default function AddressesPage() {
  const router = useRouter();
  const { isAuthenticated } = useAuth();
  const [addresses, setAddresses] = useState<Address[]>([]);
  const [isAdding, setIsAdding] = useState(false);
  const [label, setLabel] = useState("");
  const [line, setLine] = useState("");

  useEffect(() => {
    if (!isAuthenticated) router.replace("/login");
  }, [isAuthenticated, router]);

  useEffect(() => {
    setAddresses(getAddresses());
  }, []);

  if (!isAuthenticated) return null;

  const submit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!label.trim() || !line.trim()) return;
    setAddresses(addAddress({ label, line }));
    setLabel("");
    setLine("");
    setIsAdding(false);
  };

  return (
    <div className="min-h-screen bg-background pb-24">
      <div className="bg-background/90 backdrop-blur-md px-4 sm:px-6 py-3 border-b border-border sticky top-0 z-20">
        <div className="max-w-2xl mx-auto flex items-center gap-3">
          <Link href="/profile" className="w-11 h-11 rounded-full border border-border bg-card flex items-center justify-center hover:bg-muted transition-colors shrink-0">
            <ArrowLeft className="w-5 h-5 text-foreground" />
          </Link>
          <h1 className="font-display font-bold text-xl text-foreground">Mes adresses</h1>
        </div>
      </div>

      <div className="px-4 sm:px-6 pt-6 max-w-2xl mx-auto">
        {addresses.length === 0 && !isAdding && (
          <div className="flex flex-col items-center text-center py-12">
            <div className="w-20 h-20 rounded-full bg-muted flex items-center justify-center mb-5">
              <MapPin className="w-9 h-9 text-muted-foreground" />
            </div>
            <p className="font-display font-bold text-2xl text-foreground">Aucune adresse</p>
            <p className="text-sm text-muted-foreground mt-2 max-w-xs">Ajoutez une adresse pour aller plus vite à la commande.</p>
          </div>
        )}

        {addresses.length > 0 && (
          <div className="border-y border-border divide-y divide-border">
            {addresses.map((address) => (
              <div
                key={address.id}
                className="py-3.5 flex items-center gap-3"
              >
                <div className="w-11 h-11 bg-muted rounded-full flex items-center justify-center shrink-0">
                  <Home className="w-5 h-5 text-foreground" />
                </div>
                <div className="flex-1 min-w-0">
                  <p className="font-bold text-foreground truncate">{address.label}</p>
                  <p className="text-sm text-muted-foreground truncate">{address.line}</p>
                </div>
                {address.isDefault ? (
                  <span className="text-xs font-bold text-white bg-primary px-3 py-1.5 rounded-full shrink-0">
                    Défaut
                  </span>
                ) : (
                  <button
                    onClick={() => setAddresses(setDefaultAddress(address.id))}
                    className="text-xs font-bold text-foreground border border-border rounded-full px-3 min-h-[44px] hover:bg-muted transition-colors shrink-0"
                  >
                    Définir
                  </button>
                )}
                <button
                  onClick={() => setAddresses(removeAddress(address.id))}
                  aria-label={`Supprimer l'adresse ${address.label}`}
                  className="w-11 h-11 rounded-full flex items-center justify-center hover:bg-red-500/10 transition-colors shrink-0"
                >
                  <Trash2 className="w-4 h-4 text-red-500" />
                </button>
              </div>
            ))}
          </div>
        )}
      </div>

      <div className="px-4 sm:px-6 mt-6 max-w-2xl mx-auto">
        {isAdding ? (
          <form
            onSubmit={submit}
            className="bg-card rounded-2xl p-4 border border-border space-y-3"
          >
            <div className="flex items-center justify-between">
              <h2 className="font-display font-bold text-xl text-foreground">Nouvelle adresse</h2>
              <button
                type="button"
                onClick={() => setIsAdding(false)}
                aria-label="Annuler"
                className="w-11 h-11 rounded-full border border-border flex items-center justify-center hover:bg-muted transition-colors"
              >
                <X className="w-4 h-4 text-foreground" />
              </button>
            </div>
            <input
              value={label}
              onChange={(e) => setLabel(e.target.value)}
              placeholder="Nom (Maison, Bureau…)"
              aria-label="Nom de l'adresse"
              className="w-full bg-background text-foreground placeholder:text-muted-foreground rounded-xl px-4 py-3 text-sm border border-border outline-none focus:border-fast-rose focus:ring-2 focus:ring-fast-rose/25"
            />
            <AddressAutocomplete
              value={line}
              onChange={setLine}
              placeholder="Adresse complète"
            />
            <button type="submit" disabled={!label.trim() || !line.trim()} className="btn-neon w-full">
              Enregistrer
            </button>
          </form>
        ) : (
          <button
            onClick={() => setIsAdding(true)}
            className="btn-outline w-full"
          >
            <Plus className="w-5 h-5" />
            <span>Ajouter une adresse</span>
          </button>
        )}
      </div>
    </div>
  );
}
