"use client";

import React from "react";
import { m } from "framer-motion";
import Link from "next/link";

export default function PlaceholderPage({
  icon,
  title,
  subtitle,
  action,
}: {
  icon: string;
  title: string;
  subtitle: string;
  action?: { label: string; href: string };
}) {
  return (
    <m.div
      initial={{ opacity: 0, y: 16 }}
      animate={{ opacity: 1, y: 0 }}
      className="min-h-[60vh] flex flex-col items-center justify-center text-center px-6"
    >
      <div className="w-20 h-20 rounded-2xl bg-muted border border-border flex items-center justify-center text-4xl mb-5">
        {icon}
      </div>
      <h1 className="font-display text-2xl font-bold text-foreground mb-2">{title}</h1>
      <p className="text-sm max-w-xs leading-relaxed text-muted-foreground">{subtitle}</p>
      {action && (
        <Link href={action.href} className="btn-neon mt-6 text-sm no-underline">
          {action.label}
        </Link>
      )}
    </m.div>
  );
}
