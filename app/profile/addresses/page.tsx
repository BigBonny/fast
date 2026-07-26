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
import { Button } from "@/components/ui/button";

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
    <div className="min-h-screen bg-gray-50 dark:bg-gray-950 pb-20">
      <div className="bg-white dark:bg-gray-900 px-5 py-4 flex items-center gap-3 border-b border-gray-100 dark:border-gray-800 sticky top-0 z-20">
        <Link href="/profile" className="w-9 h-9 bg-gray-50 dark:bg-gray-800 rounded-xl flex items-center justify-center">
          <ArrowLeft className="w-4 h-4 text-gray-600 dark:text-gray-300" />
        </Link>
        <h1 className="font-bold text-gray-900 dark:text-white">Mes adresses</h1>
      </div>

      <div className="px-5 pt-5 space-y-2">
        {addresses.length === 0 && !isAdding && (
          <div className="bg-white dark:bg-gray-900 rounded-2xl p-6 text-center shadow-sm border border-gray-100 dark:border-gray-800">
            <MapPin className="w-8 h-8 text-gray-300 dark:text-gray-600 mx-auto mb-2" />
            <p className="font-bold text-gray-900 dark:text-white">Aucune adresse</p>
            <p className="text-sm text-gray-400 mt-0.5">Ajoutez une adresse pour aller plus vite à la commande.</p>
          </div>
        )}

        {addresses.map((address) => (
          <div
            key={address.id}
            className="bg-white dark:bg-gray-900 rounded-2xl p-4 flex items-center gap-4 shadow-sm border border-gray-100 dark:border-gray-800"
          >
            <div className="w-12 h-12 bg-emerald-100 dark:bg-emerald-500/15 rounded-xl flex items-center justify-center shrink-0">
              <Home className="w-6 h-6 text-emerald-600 dark:text-emerald-400" />
            </div>
            <div className="flex-1 min-w-0">
              <p className="font-bold text-gray-900 dark:text-white truncate">{address.label}</p>
              <p className="text-sm text-gray-500 dark:text-gray-400 truncate">{address.line}</p>
            </div>
            {address.isDefault ? (
              <span className="text-xs font-bold text-emerald-600 dark:text-emerald-400 bg-emerald-50 dark:bg-emerald-500/15 px-2 py-1 rounded-lg shrink-0">
                Défaut
              </span>
            ) : (
              <button
                onClick={() => setAddresses(setDefaultAddress(address.id))}
                className="text-xs font-bold text-gray-400 hover:text-emerald-600 transition-colors shrink-0"
              >
                Définir
              </button>
            )}
            <button
              onClick={() => setAddresses(removeAddress(address.id))}
              aria-label={`Supprimer l'adresse ${address.label}`}
              className="w-8 h-8 rounded-lg flex items-center justify-center hover:bg-red-50 dark:hover:bg-red-500/10 transition-colors shrink-0"
            >
              <Trash2 className="w-4 h-4 text-red-400" />
            </button>
          </div>
        ))}
      </div>

      <div className="px-5 mt-4">
        {isAdding ? (
          <form
            onSubmit={submit}
            className="bg-white dark:bg-gray-900 rounded-2xl p-4 shadow-sm border border-gray-100 dark:border-gray-800 space-y-3"
          >
            <div className="flex items-center justify-between">
              <h2 className="font-bold text-gray-900 dark:text-white">Nouvelle adresse</h2>
              <button
                type="button"
                onClick={() => setIsAdding(false)}
                aria-label="Annuler"
                className="w-8 h-8 rounded-lg bg-gray-100 dark:bg-gray-800 flex items-center justify-center"
              >
                <X className="w-4 h-4 text-gray-500" />
              </button>
            </div>
            <input
              value={label}
              onChange={(e) => setLabel(e.target.value)}
              placeholder="Nom (Maison, Bureau…)"
              aria-label="Nom de l'adresse"
              className="w-full bg-gray-50 dark:bg-gray-800 dark:text-white rounded-xl px-4 py-3 text-sm border border-gray-200 dark:border-gray-700 outline-none focus:border-emerald-400"
            />
            <input
              value={line}
              onChange={(e) => setLine(e.target.value)}
              placeholder="Adresse complète"
              aria-label="Adresse complète"
              className="w-full bg-gray-50 dark:bg-gray-800 dark:text-white rounded-xl px-4 py-3 text-sm border border-gray-200 dark:border-gray-700 outline-none focus:border-emerald-400"
            />
            <Button type="submit" disabled={!label.trim() || !line.trim()} className="w-full rounded-xl">
              Enregistrer
            </Button>
          </form>
        ) : (
          <button
            onClick={() => setIsAdding(true)}
            className="w-full border-2 border-dashed border-gray-300 dark:border-gray-700 rounded-2xl p-4 flex items-center justify-center gap-2 text-gray-500 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-900 transition-colors"
          >
            <Plus className="w-5 h-5" />
            <span className="font-medium">Ajouter une adresse</span>
          </button>
        )}
      </div>
    </div>
  );
}
