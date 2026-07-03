"use client";

import React from "react";
import { motion, AnimatePresence } from "framer-motion";

export default function RushBar({ active }: { active: boolean }) {
  return (
    <AnimatePresence>
      {active && (
        <motion.div
          initial={{ height: 0, opacity: 0, y: -10 }}
          animate={{ height: "auto", opacity: 1, y: 0 }}
          exit={{ height: 0, opacity: 0, y: -10 }}
          transition={{ type: "spring", damping: 25, stiffness: 300 }}
          className="text-center py-2 px-4 text-[12px] font-black text-white sticky top-[52px] z-[997] overflow-hidden"
          style={{
            background: "linear-gradient(90deg, #ff0066, #ff4d94, #ff0066)",
            backgroundSize: "200% 200%",
            animation: "rushPulse 2s infinite, gradientMove 3s linear infinite",
            textShadow: "0 1px 4px rgba(0,0,0,0.3)",
            boxShadow: "0 4px 20px rgba(255,0,102,0.35)",
          }}
        >
          <motion.span
            animate={{ scale: [1, 1.2, 1] }}
            transition={{ repeat: Infinity, duration: 1.2 }}
            className="inline-block mr-1"
          >
            🔥
          </motion.span>
          MODE RUSH ACTIF — Clients alertés des délais allongés
        </motion.div>
      )}
    </AnimatePresence>
  );
}
