"use client";

import { ArrowLeft, Headset, Mail } from "lucide-react";
import Link from "next/link";

export default function SupportPage() {
  return (
    <div className="min-h-screen bg-gray-50 dark:bg-gray-950 pb-20">
      <div className="bg-white dark:bg-gray-900 px-5 py-4 flex items-center gap-3 border-b border-gray-100 dark:border-gray-800 sticky top-0 z-20">
        <Link href="/profile" className="w-9 h-9 bg-gray-50 dark:bg-gray-800 rounded-xl flex items-center justify-center">
          <ArrowLeft className="w-4 h-4 text-gray-600 dark:text-gray-300" />
        </Link>
        <h1 className="font-bold text-gray-900 dark:text-white">Assistance</h1>
      </div>

      <div className="px-5 pt-5">
        <div className="bg-white dark:bg-gray-900 rounded-2xl p-6 shadow-sm border border-gray-100 dark:border-gray-800">
          <div className="w-12 h-12 bg-teal-100 dark:bg-teal-500/15 rounded-xl flex items-center justify-center mb-4">
            <Headset className="w-6 h-6 text-teal-600 dark:text-teal-400" />
          </div>
          <h2 className="font-black text-lg text-gray-900 dark:text-white mb-2">Besoin d&apos;aide ?</h2>
          <p className="text-sm text-gray-500 dark:text-gray-400 mb-6">
            Une question sur une commande, un paiement ou votre compte ? Notre équipe vous répond sous 24 h ouvrées.
          </p>

          <a
            href="mailto:bigbonny481@gmail.com"
            className="flex items-center gap-3 bg-teal-50 dark:bg-teal-500/10 border border-teal-200 dark:border-teal-500/20 rounded-xl px-4 py-3.5"
          >
            <Mail className="w-5 h-5 text-teal-600 dark:text-teal-400" />
            <div>
              <p className="text-sm font-bold text-gray-900 dark:text-white">Nous écrire</p>
              <p className="text-xs text-teal-600 dark:text-teal-400">bigbonny481@gmail.com</p>
            </div>
          </a>

          <div className="space-y-4 text-sm text-gray-600 dark:text-gray-300 mt-6">
            <div>
              <h3 className="font-bold text-gray-900 dark:text-white mb-1">Commande en cours</h3>
              <p>Pour toute question sur une commande en préparation ou en livraison, précisez votre numéro de commande dans l&apos;email.</p>
            </div>
            <div>
              <h3 className="font-bold text-gray-900 dark:text-white mb-1">Paiement et remboursement</h3>
              <p>Les remboursements sont traités via Stripe et apparaissent sous 5 à 10 jours ouvrés sur votre relevé bancaire.</p>
            </div>
            <div>
              <h3 className="font-bold text-gray-900 dark:text-white mb-1">Restaurateurs partenaires</h3>
              <p>Pour vos questions sur <span className="notranslate" translate="no">FAST</span> Pro, le menu, les équipes ou les versements, écrivez-nous depuis l&apos;email de votre compte.</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
