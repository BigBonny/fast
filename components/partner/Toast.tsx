"use client";

import React, { useEffect, useState } from "react";
import { m, AnimatePresence } from "framer-motion";
import { AlertCircle } from "lucide-react";

let toastListeners: Array<(toast: { id: number; message: string }) => void> = [];
let toastId = 0;

export function showToast(message: string) {
  toastId++;
  toastListeners.forEach((fn) => fn({ id: toastId, message }));
}

// Presentation only: messages that read as a failure get the red error icon.
// Everything else gets a neutral teal dot: server error texts are free-form, so
// a toast never claims success on its own.
const isErrorMessage = (message: string) => /erreur|error|échec|echec|impossible|requis|invalide/i.test(message);

export default function Toast() {
  const [toasts, setToasts] = useState<{ id: number; message: string }[]>([]);

  useEffect(() => {
    const listener = (toast: { id: number; message: string }) => {
      setToasts((prev) => [...prev, toast]);
      setTimeout(() => {
        setToasts((prev) => prev.filter((t) => t.id !== toast.id));
      }, 2500);
    };
    toastListeners.push(listener);
    return () => {
      toastListeners = toastListeners.filter((l) => l !== listener);
    };
  }, []);

  return (
    <div className="fixed top-[70px] left-1/2 -translate-x-1/2 z-[9000] flex flex-col items-center gap-2 w-[calc(100vw-2rem)] max-w-sm pointer-events-none" role="status" aria-live="polite">
      <AnimatePresence>
        {toasts.map((t) => {
          const isError = isErrorMessage(t.message);
          return (
            <m.div
              key={t.id}
              initial={{ opacity: 0, y: -20 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -20 }}
              className="pointer-events-auto max-w-full bg-card text-foreground border border-border px-4 py-3 rounded-2xl text-sm font-semibold shadow-[0_12px_30px_rgba(0,0,0,0.25)] flex items-center gap-2.5"
            >
              {isError ? (
                <AlertCircle className="w-4 h-4 flex-shrink-0 text-[color:var(--red)]" aria-hidden="true" />
              ) : (
                <span className="w-2 h-2 rounded-full flex-shrink-0 bg-fast-teal" aria-hidden="true" />
              )}
              <span>{t.message.trim()}</span>
            </m.div>
          );
        })}
      </AnimatePresence>
    </div>
  );
}
