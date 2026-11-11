"use client";

import { ArrowLeft, Shield } from "lucide-react";
import Link from "next/link";

export default function PrivacyPolicyPage() {
  return (
    <div className="min-h-screen bg-background pb-24">
      <div className="night-band">
        <div className="max-w-3xl mx-auto px-4 sm:px-6 md:px-8 pt-4 pb-10">
          <Link href="/profile" className="w-11 h-11 rounded-full bg-white/10 border border-white/15 flex items-center justify-center hover:bg-white/20 transition-colors">
            <ArrowLeft className="w-5 h-5" />
          </Link>
          <div className="flex items-center gap-3 mt-8">
            <Shield className="w-6 h-6 text-fast-gold shrink-0" />
            <h1 className="font-display font-extrabold text-3xl md:text-4xl leading-tight">Confidentialité</h1>
          </div>
        </div>
      </div>

      <div className="max-w-3xl mx-auto px-4 sm:px-6 md:px-8 pt-10">
        <h2 className="font-display font-bold text-2xl text-foreground mb-3">Politique de confidentialité</h2>
        <p className="text-base text-muted-foreground leading-relaxed mb-10">
          Chez <span className="notranslate" translate="no">FAST</span>, nous prenons la protection de vos données très au sérieux.
        </p>

        <div className="space-y-8 text-base text-muted-foreground leading-relaxed">
          <div>
            <h3 className="font-display font-bold text-xl text-foreground mb-2">Données collectées</h3>
            <p>Nous collectons uniquement les informations nécessaires au fonctionnement de l'application : nom, email, téléphone, adresse de livraison et historique de commandes.</p>
          </div>
          <div>
            <h3 className="font-display font-bold text-xl text-foreground mb-2">Utilisation</h3>
            <p>Vos données sont utilisées pour traiter vos commandes, améliorer nos services et vous envoyer des notifications importantes.</p>
          </div>
          <div>
            <h3 className="font-display font-bold text-xl text-foreground mb-2">Partage</h3>
            <p>Nous ne vendons pas vos données. Elles ne sont partagées qu'avec les restaurants concernés pour le traitement de vos commandes.</p>
          </div>
        </div>
      </div>
    </div>
  );
}
