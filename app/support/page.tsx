"use client";

import { ArrowLeft, Headset, Mail } from "lucide-react";
import Link from "next/link";

export default function SupportPage() {
  return (
    <div className="min-h-screen bg-background pb-24">
      <div className="night-band">
        <div className="max-w-3xl mx-auto px-4 sm:px-6 md:px-8 pt-4 pb-10">
          <Link href="/profile" className="w-11 h-11 rounded-full bg-white/10 border border-white/15 flex items-center justify-center hover:bg-white/20 transition-colors">
            <ArrowLeft className="w-5 h-5" />
          </Link>
          <div className="flex items-center gap-3 mt-8">
            <Headset className="w-6 h-6 text-fast-gold shrink-0" />
            <h1 className="font-display font-extrabold text-3xl md:text-4xl leading-tight">Assistance</h1>
          </div>
        </div>
      </div>

      <div className="max-w-3xl mx-auto px-4 sm:px-6 md:px-8 pt-10">
        <h2 className="font-display font-bold text-2xl text-foreground mb-3">Besoin d&apos;aide ?</h2>
        <p className="text-base text-muted-foreground leading-relaxed mb-8">
          Une question sur une commande, un paiement ou votre compte ? Notre équipe vous répond sous 24 h ouvrées.
        </p>

        <a
          href="mailto:bigbonny481@gmail.com"
          className="flex items-center gap-4 bg-card border border-border rounded-2xl p-4 hover:bg-muted transition-colors"
        >
          <div className="w-11 h-11 rounded-full bg-fast-rose/10 flex items-center justify-center shrink-0">
            <Mail className="w-5 h-5 text-fast-rose" />
          </div>
          <div className="min-w-0">
            <p className="text-sm font-bold text-foreground">Nous écrire</p>
            <p className="text-sm font-bold text-fast-rose truncate">bigbonny481@gmail.com</p>
          </div>
        </a>

        <div className="space-y-8 text-base text-muted-foreground leading-relaxed mt-10">
          <div>
            <h3 className="font-display font-bold text-xl text-foreground mb-2">Commande en cours</h3>
            <p>Pour toute question sur une commande en préparation ou en livraison, précisez votre numéro de commande dans l&apos;email.</p>
          </div>
          <div>
            <h3 className="font-display font-bold text-xl text-foreground mb-2">Paiement et remboursement</h3>
            <p>Les remboursements sont traités via Stripe et apparaissent sous 5 à 10 jours ouvrés sur votre relevé bancaire.</p>
          </div>
          <div>
            <h3 className="font-display font-bold text-xl text-foreground mb-2">Restaurateurs partenaires</h3>
            <p>Pour vos questions sur <span className="notranslate" translate="no">FAST</span> Pro, le menu, les équipes ou les versements, écrivez-nous depuis l&apos;email de votre compte.</p>
          </div>
        </div>
      </div>
    </div>
  );
}
