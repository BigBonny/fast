"use client";

import { ArrowLeft, Mail, UserX } from "lucide-react";
import Link from "next/link";

const SUPPORT_EMAIL = "bigbonny481@gmail.com";
const MAILTO = `mailto:${SUPPORT_EMAIL}?subject=${encodeURIComponent("Suppression de mon compte FAST")}`;

// Public page required by Google Play (Data safety → account deletion URL).
// Keep it reachable without being signed in, and keep what it says in sync
// with `deleteAccount` in the backend auth controller.
export default function DeleteAccountPage() {
  return (
    <div className="min-h-screen bg-background pb-24">
      <div className="night-band">
        <div className="max-w-3xl mx-auto px-4 sm:px-6 md:px-8 pt-4 pb-10">
          <Link href="/" className="w-11 h-11 rounded-full bg-white/10 border border-white/15 flex items-center justify-center hover:bg-white/20 transition-colors">
            <ArrowLeft className="w-5 h-5" />
          </Link>
          <div className="flex items-center gap-3 mt-8">
            <UserX className="w-6 h-6 text-fast-gold shrink-0" />
            <h1 className="font-display font-extrabold text-3xl md:text-4xl leading-tight">Supprimer mon compte</h1>
          </div>
        </div>
      </div>

      <div className="max-w-3xl mx-auto px-4 sm:px-6 md:px-8 pt-10">
        <h2 className="font-display font-bold text-2xl text-foreground mb-3">
          Suppression de votre compte <span className="notranslate" translate="no">FAST</span>
        </h2>
        <p className="text-base text-muted-foreground leading-relaxed mb-10">
          Vous pouvez supprimer votre compte <span className="notranslate" translate="no">FAST</span> et les données
          personnelles associées à tout moment, depuis l&apos;application ou par email.
        </p>

        <div className="space-y-8 text-base text-muted-foreground leading-relaxed">
          <div>
            <h3 className="font-display font-bold text-xl text-foreground mb-2">Depuis l&apos;application</h3>
            <ol className="list-decimal pl-5 space-y-1">
              <li>Ouvrez l&apos;application <span className="notranslate" translate="no">FAST</span> et connectez-vous.</li>
              <li>Allez dans l&apos;onglet <span className="font-bold text-foreground">Compte</span>.</li>
              <li>Touchez <span className="font-bold text-foreground">Supprimer mon compte</span>, puis confirmez.</li>
            </ol>
            <p className="mt-3">La suppression est immédiate et définitive.</p>
          </div>

          <div>
            <h3 className="font-display font-bold text-xl text-foreground mb-2">Par email</h3>
            <p className="mb-4">
              Si vous n&apos;avez plus accès à l&apos;application, écrivez-nous depuis l&apos;adresse email de votre
              compte. Nous traitons la demande sous 30 jours.
            </p>
            <a
              href={MAILTO}
              className="flex items-center gap-4 bg-card border border-border rounded-2xl p-4 hover:bg-muted transition-colors"
            >
              <div className="w-11 h-11 rounded-full bg-fast-rose/10 flex items-center justify-center shrink-0">
                <Mail className="w-5 h-5 text-fast-rose" />
              </div>
              <div className="min-w-0">
                <p className="text-sm font-bold text-foreground">Demander la suppression</p>
                <p className="text-sm font-bold text-fast-rose truncate">{SUPPORT_EMAIL}</p>
              </div>
            </a>
          </div>

          <div>
            <h3 className="font-display font-bold text-xl text-foreground mb-2">Données supprimées</h3>
            <ul className="list-disc pl-5 space-y-1">
              <li>Votre nom, votre adresse email et votre numéro de téléphone.</li>
              <li>Votre mot de passe et vos sessions ouvertes sur tous vos appareils.</li>
              <li>Vos notifications et l&apos;enregistrement de vos appareils pour les notifications push.</li>
              <li>Vos points.</li>
            </ul>
            <p className="mt-3">
              Si vous êtes restaurateur, votre restaurant est désactivé et n&apos;apparaît plus dans l&apos;application.
            </p>
          </div>

          <div>
            <h3 className="font-display font-bold text-xl text-foreground mb-2">Données conservées</h3>
            <p>
              L&apos;historique de vos commandes et des paiements associés est conservé sous une forme qui ne
              permet plus de vous identifier, pour répondre à nos obligations comptables et légales. Les données de
              paiement sont détenues par notre prestataire Stripe selon ses propres durées de conservation.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
