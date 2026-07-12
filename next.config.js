const API_URL = process.env.NEXT_PUBLIC_API_URL || "https://backend-lovat-xi-0axv990rct.vercel.app/api";

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
      { protocol: "https", hostname: "*.unsplash.com" },
      { protocol: "https", hostname: new URL(API_URL).hostname },
      { protocol: "https", hostname: "*.vercel.app" },
      { protocol: "https", hostname: "*.supabase.co" },
      { protocol: "https", hostname: "*.cloudinary.com" },
      { protocol: "https", hostname: "*.imgur.com" },
      { protocol: "https", hostname: "*.s3.amazonaws.com" },
      { protocol: "https", hostname: "s3.amazonaws.com" },
      { protocol: "https", hostname: "*.amazonaws.com" },
    ],
  },
  env: {
    NEXT_PUBLIC_API_URL: API_URL,
  },
  optimizeFonts: true,
  poweredByHeader: false,
  compress: true,
}

module.exports = nextConfig
