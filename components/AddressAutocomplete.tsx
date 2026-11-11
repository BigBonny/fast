"use client";

import { useEffect, useRef, useState } from "react";
import { MapPin } from "lucide-react";

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
        className="w-full bg-background border border-border rounded-xl px-4 py-3 text-sm text-foreground placeholder:text-muted-foreground outline-none focus:border-fast-rose focus:ring-2 focus:ring-fast-rose/25"
      />
      {open && suggestions.length > 0 && (
        <div className="absolute z-40 mt-1 w-full rounded-xl border border-border bg-card shadow-xl overflow-hidden max-h-56 overflow-y-auto">
          {suggestions.map((s, i) => (
            <button
              key={i}
              type="button"
              onClick={() => {
                onChange(s.label);
                onSelect?.(s);
                setOpen(false);
              }}
              className="w-full text-left px-4 py-3 min-h-[44px] text-sm text-foreground hover:bg-muted border-b border-border last:border-0 flex gap-2.5 items-start"
            >
              <MapPin className="w-4 h-4 mt-0.5 text-fast-rose shrink-0" aria-hidden="true" />
              <span className="line-clamp-2">{s.label}</span>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
