"use client";

import { useState, useEffect } from "react";
import { X } from "lucide-react";
import { authApi } from "@/api/fastBackend";

const GROUP_NAMES = ["Alex", "Sofia", "Liam", "Emma", "Noah"];
const OFFSETS = [0, -8, -15, -22, -28];

interface GPSTrackerProps {
  order: any;
  onClose?: () => void;
}

export default function GPSTracker({ order, onClose }: GPSTrackerProps) {
  const [progress, setProgress] = useState(0);
  const [timeLeft, setTimeLeft] = useState("--:--");
  const [userName, setUserName] = useState<string | null>(null);
  const [step, setStep] = useState(0);

  const isGroup = order?.is_group_order;
  const groupCount = isGroup ? Math.min(4, 2 + Math.floor((order?.id?.charCodeAt(0) || 0) % 3)) : 1;

  useEffect(() => {
    authApi.me().then((u: any) => {
      if (u?.name) setUserName(u.name.split(" ")[0]);
    }).catch(() => {});
  }, []);

  useEffect(() => {
    const t = setInterval(() => setStep((s) => (s + 1) % 2), 400);
    return () => clearInterval(t);
  }, []);

  useEffect(() => {
    if (!order) return;
    const interval = setInterval(() => {
      setProgress((p) => Math.min(p + 0.5, 100));
    }, 1000);
    return () => clearInterval(interval);
  }, [order]);

  useEffect(() => {
    const mins = Math.max(0, Math.round((100 - progress) / 10));
    const secs = Math.round(((100 - progress) % 10) * 6);
    setTimeLeft(`${mins}:${secs.toString().padStart(2, "0")}`);
  }, [progress]);

  if (!order) return null;

  return (
    <div className="mx-5 mb-4 rounded-2xl p-4 relative" style={{ background: "#1a1f2e" }}>
      <div className="flex items-center justify-between mb-3">
        <div className="flex items-center gap-2">
          <div className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
          <span className="text-white text-sm font-bold">📍 Suivi GPS en direct</span>
        </div>
        <div className="flex items-center gap-2">
          <span className="text-gray-400 text-xs">#{order.id?.slice(-5)}</span>
          {onClose && (
            <button onClick={onClose} className="w-5 h-5 rounded-full bg-gray-600 flex items-center justify-center">
              <X className="w-3 h-3 text-white" />
            </button>
          )}
        </div>
      </div>

      <div className="flex items-center gap-3 mb-3">
        <span className="text-2xl">🍽️</span>

        <div className="flex-1 relative" style={{ height: groupCount > 1 ? 52 : 36 }}>
          <div
            className="absolute bottom-0 left-0 right-0 h-2 rounded-full"
            style={{ background: "#2a2f3e" }}
          />
          <div
            className="absolute bottom-0 left-0 h-2 rounded-full transition-all duration-1000"
            style={{
              width: `${Math.max(0, progress)}%`,
              background: "linear-gradient(90deg, #14b8a6, #06b6d4)",
            }}
          />
          {Array.from({ length: groupCount }).map((_, i) => {
            const memberProgress = Math.max(0, Math.min(100, progress + OFFSETS[i]));
            const name = i === 0 ? (userName || `#${order.id?.slice(-4)}`) : GROUP_NAMES[i];
            const bottomOffset = groupCount > 1 ? 6 + i * 16 : 6;
            return (
              <div
                key={i}
                className="absolute flex flex-col items-center"
                style={{
                  left: `calc(${memberProgress}% - 12px)`,
                  bottom: bottomOffset,
                  transition: "left 1s linear",
                  zIndex: groupCount - i,
                }}
              >
                <span
                  className="text-white font-bold whitespace-nowrap"
                  style={{ fontSize: 7, marginBottom: 0, opacity: 0.8, letterSpacing: "0.02em" }}
                >
                  {name}
                </span>
                <span
                  style={{
                    fontSize: groupCount > 2 ? 14 : 16,
                    lineHeight: 1,
                    transform: step === i % 2 ? "translateY(0px)" : "translateY(-2px)",
                    transition: "transform 0.4s ease",
                    display: "inline-block",
                  }}
                >
                  🚶
                </span>
              </div>
            );
          })}
        </div>

        <span className="text-2xl">🏁</span>
      </div>

      <div className="flex items-center justify-between mb-3">
        <div>
          <span className="text-2xl font-black text-emerald-400">
            {((100 - progress) * 0.02).toFixed(2)} KM
          </span>
          <p className="text-xs text-gray-500">📍 GPS simulé</p>
        </div>
        <div className="text-right">
          <p className="text-xs text-gray-500 uppercase tracking-wider">PRÊT DANS</p>
          <span className="text-lg font-black text-yellow-400">{timeLeft}</span>
        </div>
      </div>

      <div className="flex gap-2">
        {["10 min", "5 min", "2 min", "Arrivée"].map((label, i) => (
          <div
            key={label}
            className="flex-1 text-center py-1 rounded-full text-[10px] font-bold"
            style={{
              background: progress > i * 25 ? "#14b8a6" : "#2a2f3e",
              color: progress > i * 25 ? "white" : "#6b7280",
            }}
          >
            {label}
          </div>
        ))}
      </div>
    </div>
  );
}
