"use client";

import { ArrowLeft, FileText } from "lucide-react";
import Link from "next/link";

export default function TermsOfServicePage() {
  return (
    <div className="min-h-screen bg-gray-50 pb-20">
      <div className="bg-white px-5 py-4 flex items-center gap-3 border-b border-gray-100 sticky top-0 z-20">
        <Link href="/profile" className="w-9 h-9 bg-gray-50 rounded-xl flex items-center justify-center">
          <ArrowLeft className="w-4 h-4 text-gray-600" />
        </Link>
        <h1 className="font-bold text-gray-900">CGU</h1>
      </div>

      <div className="px-5 pt-5">
        <div className="bg-white rounded-2xl p-6 shadow-sm border border-gray-100">
          <div className="w-12 h-12 bg-blue-100 rounded-xl flex items-center justify-center mb-4">
            <FileText className="w-6 h-6 text-blue-600" />
          </div>
          <h2 className="font-black text-lg text-gray-900 mb-2">Conditions générales d'utilisation</h2>
          <p className="text-sm text-gray-500 mb-4">
            En utilisant FAST, vous acceptez les conditions suivantes.
          </p>

          <div className="space-y-4 text-sm text-gray-600">
            <div>
              <h3 className="font-bold text-gray-900 mb-1">Service</h3>
              <p>FAST met en relation des clients et des restaurants pour la commande et le retrait de repas. Les restaurants sont responsables de la préparation et de la disponibilité des articles.</p>
            </div>
            <div>
              <h3 className="font-bold text-gray-900 mb-1">Compte</h3>
              <p>Vous êtes responsable de la confidentialité de vos identifiants. Toute activité sur votre compte est réputée effectuée par vous.</p>
            </div>
            <div>
              <h3 className="font-bold text-gray-900 mb-1">Commandes</h3>
              <p>Une fois une commande validée, elle ne peut être annulée que si le restaurant n'a pas encore commencé la préparation.</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
