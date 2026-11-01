"use client";

import { useEffect, useRef, useState } from "react";

const API_URL =
  process.env.NEXT_PUBLIC_API_URL ||
  "https://backend-six-iota-69.vercel.app/api";

export type PlaceSuggestion = {
  label: string;
  lat: number;
  lng: number;
  city: string;
};

/** Address input with live place suggestions (backend Nominatim proxy). */
export default function AddressAutocomplete({
  value,
  onChange,
  onSelect,
  placeholder = "Votre adresse…",
  className = "",
}: {
  value: string;
  onChange: (v: string) => void;
  onSelect?: (s: PlaceSuggestion) => void;
  placeholder?: string;
  className?: string;
}) {
  const [suggestions, setSuggestions] = useState<PlaceSuggestion[]>([]);
  const [open, setOpen] = useState(false);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const boxRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const close = (e: MouseEvent) => {
      if (!boxRef.current?.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener("mousedown", close);
    return () => document.removeEventListener("mousedown", close);
  }, []);

  function handleChange(v: string) {
    onChange(v);
    if (timer.current) clearTimeout(timer.current);
    timer.current = setTimeout(async () => {
      if (v.trim().length < 3) {
        setSuggestions([]);
        setOpen(false);
        return;
      }
      try {
        const res = await fetch(
          `${API_URL}/assistant/places?q=${encodeURIComponent(v)}`,
        );
        const data = (await res.json()) as {
          suggestions?: PlaceSuggestion[];
        };
        setSuggestions(data.suggestions ?? []);
        setOpen((data.suggestions ?? []).length > 0);
      } catch {
        setSuggestions([]);
      }
    }, 450);
  }

  return (
    <div ref={boxRef} className={`relative ${className}`}>
      <input
        value={value}
        onChange={(e) => handleChange(e.target.value)}
        onFocus={() => suggestions.length > 0 && setOpen(true)}
        placeholder={placeholder}
        className="w-full bg-slate-800/80 border border-slate-700 rounded-xl px-4 py-2.5 text-sm text-white placeholder:text-slate-500 outline-none focus:border-amber-500"
      />
      {open && suggestions.length > 0 && (
        <div className="absolute z-40 mt-1 w-full rounded-xl border border-slate-700 bg-slate-900 shadow-xl overflow-hidden max-h-56 overflow-y-auto">
          {suggestions.map((s, i) => (
            <button
              key={i}
              type="button"
              onClick={() => {
                onChange(s.label);
                onSelect?.(s);
                setOpen(false);
              }}
              className="w-full text-left px-3 py-2 text-xs text-slate-200 hover:bg-slate-800 border-b border-slate-800 last:border-0 flex gap-2 items-start"
            >
              <span className="text-amber-500 shrink-0">📍</span>
              <span className="line-clamp-2">{s.label}</span>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
