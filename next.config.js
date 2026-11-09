const API_URL = process.env.NEXT_PUBLIC_API_URL || "https://backend-six-iota-69.vercel.app/api";
const API_ORIGIN = new URL(API_URL).origin;

// Hosts whose images go through the Next image optimizer. Keep this short:
// every entry lets anyone use our optimizer as a proxy for that host.
// Must stay in sync with OPTIMIZED_IMAGE_HOSTS in components/SafeImage.tsx;
// other hosts still display, as plain <img> without optimization.
const SUPABASE_STORAGE_HOST = "qrubbfaqxrndjvnpchlc.supabase.co";

const isDev = process.env.NODE_ENV !== "production";

// Google Identity Services (the "Sign in with Google" button) is the only
// third-party script. Next 14 App Router injects inline hydration scripts,
// so script-src needs 'unsafe-inline' unless we move to per-request nonces.
const csp = [
  "default-src 'self'",
  `script-src 'self' 'unsafe-inline'${isDev ? " 'unsafe-eval'" : ""} https://accounts.google.com/gsi/client`,
  "style-src 'self' 'unsafe-inline' https://accounts.google.com/gsi/style",
  "img-src 'self' data: blob: https:",
  "font-src 'self' data:",
  `connect-src 'self' ${API_ORIGIN} https://accounts.google.com/gsi/${isDev ? " ws: http://localhost:*" : ""}`,
  "frame-src https://accounts.google.com/gsi/",
  "frame-ancestors 'none'",
  "object-src 'none'",
  "base-uri 'self'",
  "form-action 'self'",
].join("; ");

const securityHeaders = [
  { key: "Content-Security-Policy", value: csp },
  { key: "X-Frame-Options", value: "DENY" },
  { key: "X-Content-Type-Options", value: "nosniff" },
  { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
  { key: "Strict-Transport-Security", value: "max-age=63072000; includeSubDomains" },
  // Google sign-in opens a popup that must be able to report back.
  { key: "Cross-Origin-Opener-Policy", value: "same-origin-allow-popups" },
  { key: "Permissions-Policy", value: "camera=(), microphone=(), geolocation=(), payment=()" },
];

/** @type {import('next').NextConfig} */
const nextConfig = {
  experimental: {
    turbo: {},
  },
  images: {
    unoptimized: false,
    formats: ["image/webp", "image/avif"],
    deviceSizes: [320, 420, 640, 750, 828, 1080, 1200, 1920, 2048, 3840],
    imageSizes: [16, 32, 48, 64, 96, 128, 256, 384],
    remotePatterns: [
      { protocol: "https", hostname: "images.unsplash.com" },
      { protocol: "https", hostname: SUPABASE_STORAGE_HOST, pathname: "/storage/v1/object/public/**" },
      { protocol: "https", hostname: new URL(API_URL).hostname },
    ],
  },
  env: {
    NEXT_PUBLIC_API_URL: API_URL,
  },
  async headers() {
    return [{ source: "/:path*", headers: securityHeaders }];
  },
  optimizeFonts: true,
  poweredByHeader: false,
  compress: true,
}

module.exports = nextConfig
