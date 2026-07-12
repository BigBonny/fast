"use client";

import React, { useEffect, useState } from "react";
import { m, AnimatePresence } from "framer-motion";

let toastListeners: Array<(toast: { id: number; message: string }) => void> = [];
let toastId = 0;

export function showToast(message: string) {
  toastId++;
  toastListeners.forEach((fn) => fn({ id: toastId, message }));
}

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
    <div className="fixed top-[70px] left-1/2 -translate-x-1/2 z-[9000] flex flex-col gap-2">
      <AnimatePresence>
        {toasts.map((t) => (
          <m.div
            key={t.id}
            initial={{ opacity: 0, y: -20 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -20 }}
            className="bg-slate-900 text-white px-5 py-2.5 rounded-full text-[13px] font-semibold shadow-[0_12px_30px_rgba(0,0,0,0.4)] whitespace-nowrap"
          >
            {t.message}
          </m.div>
        ))}
      </AnimatePresence>
    </div>
  );
}
