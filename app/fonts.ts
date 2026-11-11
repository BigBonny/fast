import { Inter, Bebas_Neue, Playfair_Display } from "next/font/google";

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
// mobile app uses (Playfair Display).
export const display = Playfair_Display({
  subsets: ["latin", "latin-ext"],
  weight: ["700", "800", "900"],
  style: ["normal", "italic"],
  display: "swap",
  variable: "--font-display",
  fallback: ["Georgia", "Times New Roman", "serif"],
});
