import type { Metadata, Viewport } from "next";
import "./globals.css";
import { inter, bebas } from "./fonts";
import { Providers } from "@/components/providers";
import { Toaster } from "@/components/ui/toaster";
import Layout from "@/components/Layout";

export const metadata: Metadata = {
  title: "FAST - Chaque minute compte",
  description: "Commande rapide de nourriture - Livraison express",
  manifest: "/manifest.webmanifest",
  applicationName: "FAST",
  appleWebApp: { capable: true, title: "FAST", statusBarStyle: "black-translucent" },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  // No maximumScale/userScalable lock: pinch-zoom must stay available (WCAG 1.4.4).
  viewportFit: "cover",
  themeColor: "#08090f",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="fr" suppressHydrationWarning className={`${inter.variable} ${bebas.variable}`}>
      <head>
        <script
          dangerouslySetInnerHTML={{
            __html: `(function(){try{var t=localStorage.getItem("fast_theme");var d=t?t==="dark":window.matchMedia("(prefers-color-scheme: dark)").matches;document.documentElement.classList.toggle("dark",d);document.documentElement.setAttribute("data-theme",d?"dark":"light");}catch(e){}})();`,
          }}
        />
      </head>
      <body className="antialiased">
        <Providers>
          <Layout>
            {children}
          </Layout>
          <Toaster />
        </Providers>
      </body>
    </html>
  );
}
