import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "FAST — Chaque minute compte",
    short_name: "FAST",
    description: "Commande rapide de nourriture — Livraison express",
    start_url: "/",
    display: "standalone",
    background_color: "#08090f",
    theme_color: "#08090f",
    orientation: "portrait",
    categories: ["food", "shopping"],
    // Installability additionally requires 192x192 and 512x512 PNG icons in /public.
    // Add them here once the assets exist:
    // icons: [{ src: "/icon-192.png", sizes: "192x192", type: "image/png" }, ...]
    icons: [],
  };
}
