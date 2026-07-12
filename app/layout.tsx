import type { Metadata, Viewport } from "next";
import "./globals.css";
import { inter, bebas } from "./fonts";
import { Providers } from "@/components/providers";
import { Toaster } from "@/components/ui/toaster";
import Layout from "@/components/Layout";

export const metadata: Metadata = {
  title: "FAST - Chaque minute compte",
  description: "Commande rapide de nourriture - Livraison express",
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  maximumScale: 1,
  themeColor: "#08090f",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="fr" suppressHydrationWarning className={`${inter.variable} ${bebas.variable}`}>
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
