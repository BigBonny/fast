"use client";

import { ArrowLeft, Shield } from "lucide-react";
import Link from "next/link";
import type { ReactNode } from "react";

const CONTACT_EMAIL = "bigbonny481@gmail.com";
const LAST_UPDATED = "18 novembre 2026";

const Fast = () => <span className="notranslate" translate="no">FAST</span>;

function Section({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section>
      <h3 className="font-display font-bold text-xl text-foreground mb-2">{title}</h3>
      <div className="space-y-3">{children}</div>
    </section>
  );
}

// Keep this page in sync with what the app and backend actually do: the
// Google Play Data safety form and the App Store privacy labels are
// declared from it. Location: ProximityService (app); deletion:
// `deleteAccount` in the backend auth controller (see /delete-account).
const PROCESSORS: { name: string; role: string }[] = [
  { name: "Stripe", role: "paiements, cartes enregistrées et versements aux restaurants (Stripe Connect)" },
  { name: "Supabase", role: "base de données et stockage des photos" },
  { name: "Vercel", role: "hébergement du site et de l'API" },
  { name: "Google Firebase", role: "notifications push" },
  { name: "Google et Apple", role: "connexion avec un compte Google ou Apple, si vous la choisissez" },
  { name: "Google Gemini et Mistral AI", role: "assistant FAST et lecture des cartes de menu par IA" },
  { name: "Sentry", role: "rapports d'erreurs techniques" },
  { name: "Resend et Twilio", role: "emails et SMS transactionnels (codes de vérification, confirmations)" },
  { name: "OpenFreeMap et OSRM", role: "affichage des cartes et calcul de l'itinéraire à pied vers le restaurant" },
  { name: "Base Adresse Nationale (État français)", role: "suggestions d'adresses pendant la saisie" },
];

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
        <p className="text-base text-muted-foreground leading-relaxed mb-2">
          Cette politique explique quelles données l&apos;application et le site <Fast /> collectent, pourquoi, avec
          qui elles sont partagées et comment exercer vos droits.
        </p>
        <p className="text-sm text-muted-foreground mb-10">Dernière mise à jour : {LAST_UPDATED}</p>

        <div className="space-y-8 text-base text-muted-foreground leading-relaxed">
          <Section title="Responsable du traitement">
            <p>
              Fast Enterprise, éditeur de <Fast />. Pour toute question sur vos données :{" "}
              <a href={`mailto:${CONTACT_EMAIL}`} className="font-bold text-fast-rose hover:underline">{CONTACT_EMAIL}</a>.
            </p>
          </Section>

          <Section title="Données collectées">
            <ul className="list-disc pl-5 space-y-2">
              <li>
                <span className="font-bold text-foreground">Compte :</span> nom, adresse email, numéro de téléphone,
                mot de passe (stocké chiffré), ou identifiant Google / Apple si vous vous connectez avec ces services.
              </li>
              <li>
                <span className="font-bold text-foreground">Commandes :</span> restaurants, articles, montants, heures
                de retrait, commandes de groupe, réservations, carte de fidélité et avis.
              </li>
              <li>
                <span className="font-bold text-foreground">Paiement :</span> les numéros de carte sont saisis et
                conservés par Stripe ; <Fast /> n&apos;y a jamais accès.
              </li>
              <li>
                <span className="font-bold text-foreground">Localisation :</span> voir la section dédiée ci-dessous.
              </li>
              <li>
                <span className="font-bold text-foreground">Adresses :</span> les adresses que vous enregistrez.
              </li>
              <li>
                <span className="font-bold text-foreground">Photos et caméra :</span> la caméra sert à scanner des QR
                codes (analysés sur votre appareil) et, pour les restaurateurs, à photographier plats et cartes de menu.
                Seules les photos que vous choisissez d&apos;envoyer quittent votre appareil.
              </li>
              <li>
                <span className="font-bold text-foreground">Notifications :</span> un identifiant technique de votre
                appareil pour vous envoyer les notifications push.
              </li>
              <li>
                <span className="font-bold text-foreground">Diagnostic :</span> rapports d&apos;erreurs techniques
                (type d&apos;appareil, version de l&apos;app, trace de l&apos;erreur), sans votre nom ni votre email.
              </li>
            </ul>
          </Section>

          <Section title="Localisation">
            <p>
              L&apos;application utilise votre position pour afficher les restaurants proches et, surtout, pendant
              qu&apos;une commande à emporter est en préparation ou prête : elle prévient le restaurant que vous êtes en
              route et vous signale quand vous arrivez, pour que votre commande soit prête à votre arrivée.
            </p>
            <p>
              Pendant ce suivi, Android affiche une notification permanente ; le suivi peut continuer écran éteint et
              s&apos;arrête dès que la commande est récupérée ou annulée. Le restaurant voit seulement votre
              progression et votre heure d&apos;arrivée estimée : vos coordonnées GPS ne sont pas enregistrées sur nos
              serveurs. Vous pouvez refuser ou retirer l&apos;accès à la localisation dans les réglages de votre
              téléphone ; l&apos;application reste utilisable, sans ces alertes.
            </p>
          </Section>

          <Section title="Pourquoi nous utilisons vos données">
            <ul className="list-disc pl-5 space-y-1">
              <li>Créer votre compte et traiter vos commandes et paiements (exécution du contrat).</li>
              <li>Vous informer de l&apos;état de vos commandes (exécution du contrat).</li>
              <li>Prévenir la fraude, corriger les erreurs et sécuriser le service (intérêt légitime).</li>
              <li>Respecter nos obligations comptables et légales (obligation légale).</li>
              <li>Le suivi de localisation et les notifications push, uniquement avec votre autorisation (consentement).</li>
            </ul>
            <p>
              <Fast /> n&apos;affiche pas de publicité, ne vend pas vos données et ne les utilise pas pour du ciblage
              publicitaire.
            </p>
          </Section>

          <Section title="Intelligence artificielle">
            <p>
              Quand vous écrivez à l&apos;assistant <Fast />, vos messages et la carte des restaurants concernés sont
              envoyés à Google Gemini (ou Mistral AI en secours) pour générer la réponse. Les photos de menu
              envoyées par les restaurateurs sont analysées de la même façon. N&apos;y indiquez pas d&apos;informations
              sensibles. Les plats peuvent aussi être illustrés par des images générées par IA.
            </p>
          </Section>

          <Section title="Partage">
            <p>
              Le restaurant qui prépare votre commande reçoit votre nom, votre commande, vos éventuelles remarques et,
              pendant le suivi, votre progression vers le restaurant. Nous faisons aussi appel aux prestataires
              suivants, qui traitent les données uniquement pour notre compte :
            </p>
            <ul className="list-disc pl-5 space-y-1">
              {PROCESSORS.map((p) => (
                <li key={p.name}>
                  <span className="font-bold text-foreground">{p.name}</span> : {p.role}.
                </li>
              ))}
            </ul>
            <p>
              Certains de ces prestataires peuvent traiter des données hors de l&apos;Union européenne, notamment aux
              États-Unis ; ces transferts sont encadrés par les clauses contractuelles types de la Commission
              européenne ou le cadre de protection des données UE–États-Unis.
            </p>
          </Section>

          <Section title="Durée de conservation">
            <ul className="list-disc pl-5 space-y-1">
              <li>Compte : tant qu&apos;il est actif. Il est supprimé dès que vous le demandez.</li>
              <li>
                Commandes et paiements : 10 ans pour nos obligations comptables, sous une forme qui ne permet plus de
                vous identifier après la suppression du compte.
              </li>
              <li>Rapports d&apos;erreurs : 90 jours maximum.</li>
            </ul>
          </Section>

          <Section title="Sur votre appareil">
            <p>
              L&apos;application garde sur votre téléphone votre jeton de connexion (dans le stockage sécurisé du
              système) et vos préférences (langue, thème, panier). Se déconnecter retire le jeton de connexion de
              l&apos;appareil sans supprimer votre compte.
            </p>
          </Section>

          <Section title="Vos droits">
            <p>
              Conformément au RGPD, vous pouvez accéder à vos données, les rectifier, les supprimer, en demander la
              portabilité, vous opposer à un traitement ou en limiter l&apos;usage, et retirer votre consentement à tout
              moment. Écrivez-nous à{" "}
              <a href={`mailto:${CONTACT_EMAIL}`} className="font-bold text-fast-rose hover:underline">{CONTACT_EMAIL}</a>
              {" "}: nous répondons sous un mois. Vous pouvez aussi saisir la CNIL (
              <a href="https://www.cnil.fr" className="font-bold text-fast-rose hover:underline">www.cnil.fr</a>).
            </p>
          </Section>

          <Section title="Suppression du compte">
            <p>
              Vous pouvez supprimer votre compte et vos données personnelles à tout moment.{" "}
              <Link href="/delete-account" className="font-bold text-fast-rose hover:underline">Voir comment supprimer mon compte</Link>.
            </p>
          </Section>

          <Section title="Âge minimum">
            <p>
              <Fast /> s&apos;adresse aux personnes de 18 ans et plus et ne collecte pas sciemment de données concernant
              des mineurs.
            </p>
          </Section>

          <Section title="Modifications">
            <p>
              Nous pouvons mettre à jour cette politique ; la date en haut de page indique la dernière version.
            </p>
          </Section>
        </div>
      </div>
    </div>
  );
}
