"use client";

import { ArrowLeft, Shield } from "lucide-react";
import Link from "next/link";

export default function PrivacyPolicyPage() {
  return (
    <div className="min-h-screen bg-gray-50 dark:bg-gray-950 pb-20">
      <div className="bg-white dark:bg-gray-900 px-5 py-4 flex items-center gap-3 border-b border-gray-100 dark:border-gray-800 sticky top-0 z-20">
        <Link href="/profile" className="w-9 h-9 bg-gray-50 dark:bg-gray-800 rounded-xl flex items-center justify-center">
          <ArrowLeft className="w-4 h-4 text-gray-600 dark:text-gray-300" />
        </Link>
        <h1 className="font-bold text-gray-900 dark:text-white">Confidentialité</h1>
      </div>

      <div className="px-5 pt-5">
        <div className="bg-white dark:bg-gray-900 rounded-2xl p-6 shadow-sm border border-gray-100 dark:border-gray-800">
          <div className="w-12 h-12 bg-violet-100 dark:bg-violet-500/15 rounded-xl flex items-center justify-center mb-4">
            <Shield className="w-6 h-6 text-violet-600 dark:text-violet-400" />
          </div>
          <h2 className="font-black text-lg text-gray-900 dark:text-white mb-2">Politique de confidentialité</h2>
          <p className="text-sm text-gray-500 dark:text-gray-400 mb-4">
            Chez FAST, nous prenons la protection de vos données très au sérieux.
          </p>

          <div className="space-y-4 text-sm text-gray-600 dark:text-gray-300">
            <div>
              <h3 className="font-bold text-gray-900 dark:text-white mb-1">Données collectées</h3>
              <p>Nous collectons uniquement les informations nécessaires au fonctionnement de l'application : nom, email, téléphone, adresse de livraison et historique de commandes.</p>
            </div>
            <div>
              <h3 className="font-bold text-gray-900 dark:text-white mb-1">Utilisation</h3>
              <p>Vos données sont utilisées pour traiter vos commandes, améliorer nos services et vous envoyer des notifications importantes.</p>
            </div>
            <div>
              <h3 className="font-bold text-gray-900 dark:text-white mb-1">Partage</h3>
              <p>Nous ne vendons pas vos données. Elles ne sont partagées qu'avec les restaurants concernés pour le traitement de vos commandes.</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
