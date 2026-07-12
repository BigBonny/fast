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
      <div
        className="w-20 h-20 rounded-3xl flex items-center justify-center text-4xl mb-5"
        style={{
          background: "linear-gradient(145deg, rgba(0,200,179,0.15), rgba(255,0,102,0.08))",
          boxShadow: "0 8px 32px rgba(0,200,179,0.15), 0 0 0 1px rgba(255,255,255,0.05) inset",
        }}
      >
        {icon}
      </div>
      <h1
        className="font-bebas text-[28px] tracking-[3px] mb-2"
        style={{ color: "var(--blk)" }}
      >
        {title}
      </h1>
      <p className="text-[13px] font-semibold max-w-xs leading-relaxed" style={{ color: "var(--gray)" }}>
        {subtitle}
      </p>
      {action && (
        <Link
          href={action.href}
          className="mt-6 px-5 py-2.5 rounded-xl text-[12px] font-black text-white no-underline transition-all hover:scale-105 active:scale-95"
          style={{
            background: "linear-gradient(135deg, #00c8b3, #00a090)",
            boxShadow: "0 4px 16px rgba(0,200,179,0.25)",
          }}
        >
          {action.label}
        </Link>
      )}
    </m.div>
  );
}
