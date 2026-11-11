import { Inter, Bebas_Neue } from "next/font/google";
import localFont from "next/font/local";

export const inter = Inter({
  subsets: ["latin"],
  display: "swap",
  variable: "--font-inter",
  fallback: ["system-ui", "-apple-system", "BlinkMacSystemFont", "Segoe UI", "sans-serif"],
});

export const bebas = Bebas_Neue({
  weight: "400",
  subsets: ["latin"],
  display: "swap",
  variable: "--font-bebas",
  fallback: ["cursive"],
});

// Display face for headlines and section titles: the same serif the
// mobile app uses (Playfair Display, SIL Open Font License, see
// app/fonts/PlayfairDisplay-OFL.txt). Loaded from files in the repo, not
// from Google at build time: the Google loader failed on Vercel's build.
export const display = localFont({
  src: [
    { path: "./fonts/PlayfairDisplay-wght.ttf", weight: "400 900", style: "normal" },
    { path: "./fonts/PlayfairDisplay-Italic-wght.ttf", weight: "400 900", style: "italic" },
  ],
  display: "swap",
  variable: "--font-display",
  fallback: ["Georgia", "Times New Roman", "serif"],
});
