"use client";

import { useState, memo } from "react";
import Image from "next/image";

const KNOWN_HOSTS = [
  "images.unsplash.com",
  "unsplash.com",
  "supabase.co",
  "cloudinary.com",
  "imgur.com",
  "s3.amazonaws.com",
  "amazonaws.com",
  "vercel.app",
];

function isKnownHost(src?: string) {
  if (!src || src.startsWith("/")) return false;
  try {
    const url = new URL(src);
    return KNOWN_HOSTS.some(
      (h) => url.hostname === h || url.hostname.endsWith("." + h)
    );
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
        style={style}
        loading={loadingMode}
        decoding="async"
        width={width}
        height={height}
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
