"use client";

import { ArrowLeft, FileText } from "lucide-react";
import Link from "next/link";

export default function TermsOfServicePage() {
  return (
    <div className="min-h-screen bg-background pb-24">
      <div className="night-band">
        <div className="max-w-3xl mx-auto px-4 sm:px-6 md:px-8 pt-4 pb-10">
          <Link href="/profile" className="w-11 h-11 rounded-full bg-white/10 border border-white/15 flex items-center justify-center hover:bg-white/20 transition-colors">
            <ArrowLeft className="w-5 h-5" />
          </Link>
          <div className="flex items-center gap-3 mt-8">
            <FileText className="w-6 h-6 text-fast-gold shrink-0" />
            <h1 className="font-display font-extrabold text-3xl md:text-4xl leading-tight">CGU</h1>
          </div>
        </div>
      </div>

      <div className="max-w-3xl mx-auto px-4 sm:px-6 md:px-8 pt-10">
        <h2 className="font-display font-bold text-2xl text-foreground mb-3">Conditions générales d'utilisation</h2>
        <p className="text-base text-muted-foreground leading-relaxed mb-10">
          En utilisant <span className="notranslate" translate="no">FAST</span>, vous acceptez les conditions suivantes.
        </p>

        <div className="space-y-8 text-base text-muted-foreground leading-relaxed">
          <div>
            <h3 className="font-display font-bold text-xl text-foreground mb-2">Service</h3>
            <p><span className="notranslate" translate="no">FAST</span> met en relation des clients et des restaurants pour la commande et le retrait de repas. Les restaurants sont responsables de la préparation et de la disponibilité des articles.</p>
          </div>
          <div>
            <h3 className="font-display font-bold text-xl text-foreground mb-2">Compte</h3>
            <p>Vous êtes responsable de la confidentialité de vos identifiants. Toute activité sur votre compte est réputée effectuée par vous.</p>
          </div>
          <div>
            <h3 className="font-display font-bold text-xl text-foreground mb-2">Commandes</h3>
            <p>Une fois une commande validée, elle ne peut être annulée que si le restaurant n'a pas encore commencé la préparation.</p>
          </div>
        </div>
      </div>
    </div>
  );
}
