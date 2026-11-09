"use client";

import { useState, memo } from "react";
import Image from "next/image";

// Hosts served through the Next image optimizer. Must match
// images.remotePatterns in next.config.js, or the optimizer rejects the
// image. Any other host still displays, as a plain <img>.
const OPTIMIZED_IMAGE_HOSTS = [
  "images.unsplash.com",
  "qrubbfaqxrndjvnpchlc.supabase.co",
  new URL(process.env.NEXT_PUBLIC_API_URL || "https://backend-six-iota-69.vercel.app/api").hostname,
];

function isKnownHost(src?: string) {
  if (!src || src.startsWith("/")) return false;
  try {
    const url = new URL(src);
    if (url.protocol !== "https:") return false;
    if (url.hostname.endsWith(".supabase.co")) {
      return (
        OPTIMIZED_IMAGE_HOSTS.includes(url.hostname) &&
        url.pathname.startsWith("/storage/v1/object/public/")
      );
    }
    return OPTIMIZED_IMAGE_HOSTS.includes(url.hostname);
  } catch {
    return false;
  }
}

interface SafeImageProps {
  src?: string;
  alt?: string;
  fill?: boolean;
  sizes?: string;
  width?: number;
  height?: number;
  className?: string;
  style?: React.CSSProperties;
  priority?: boolean;
  loading?: "eager" | "lazy";
}

function SafeImage({
  src,
  alt = "",
  fill,
  sizes,
  width,
  height,
  className,
  style,
  priority,
  loading,
}: SafeImageProps) {
  const [error, setError] = useState(false);

  if (!src || error) {
    return (
      <div
        className={className}
        style={{
          ...style,
          backgroundColor: "#f1f5f9",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
        }}
      />
    );
  }

  const loadingMode = priority || loading === "eager" ? "eager" : "lazy";

  // For non-optimized/unknown hosts, use a regular lazy img with decoding async.
  if (!isKnownHost(src)) {
    return (
      <img
        src={src}
        alt={alt}
        className={className}
        style={
          fill
            ? {
                position: "absolute",
                inset: 0,
                width: "100%",
                height: "100%",
                ...style,
              }
            : style
        }
        loading={loadingMode}
        decoding="async"
        width={fill ? undefined : width}
        height={fill ? undefined : height}
        onError={() => setError(true)}
      />
    );
  }

  if (fill) {
    return (
      <Image
        src={src}
        alt={alt}
        fill
        sizes={sizes || "100vw"}
        className={className}
        style={style}
        priority={priority}
        loading={loadingMode}
        onError={() => setError(true)}
      />
    );
  }

  return (
    <Image
      src={src}
      alt={alt}
      width={width || 80}
      height={height || 80}
      sizes={sizes}
      className={className}
      style={style}
      priority={priority}
      loading={loadingMode}
      onError={() => setError(true)}
    />
  );
}

export default memo(SafeImage);
