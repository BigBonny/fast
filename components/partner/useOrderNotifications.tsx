"use client";

import { useEffect, useRef } from "react";
import { orderApi } from "@/api/fastBackend";
import { showToast } from "./Toast";
import { QueryClient } from "@tanstack/react-query";

function playNotificationSound() {
  try {
    const ctx = new (window.AudioContext || (window as any).webkitAudioContext)();

    const osc1 = ctx.createOscillator();
    const gain1 = ctx.createGain();
    osc1.connect(gain1);
    gain1.connect(ctx.destination);
    osc1.type = "sine";
    osc1.frequency.setValueAtTime(880, ctx.currentTime);
    gain1.gain.setValueAtTime(0.4, ctx.currentTime);
    gain1.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.2);
    osc1.start(ctx.currentTime);
    osc1.stop(ctx.currentTime + 0.2);

    const osc2 = ctx.createOscillator();
    const gain2 = ctx.createGain();
    osc2.connect(gain2);
    gain2.connect(ctx.destination);
    osc2.type = "sine";
    osc2.frequency.setValueAtTime(1100, ctx.currentTime + 0.25);
    gain2.gain.setValueAtTime(0.5, ctx.currentTime + 0.25);
    gain2.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.5);
    osc2.start(ctx.currentTime + 0.25);
    osc2.stop(ctx.currentTime + 0.5);
  } catch (e) {
    // Silently fail if audio not supported
  }
}

export default function useOrderNotifications(queryClient: QueryClient) {
  const knownIds = useRef<Set<string>>(new Set());
  const initialized = useRef(false);

  useEffect(() => {
    orderApi.restaurantOrders().then((orders: any[]) => {
      orders.forEach((o) => knownIds.current.add(o.id));
      initialized.current = true;
    });

    const interval = setInterval(async () => {
      try {
        const orders = await orderApi.restaurantOrders();
        queryClient.setQueryData(["orders"], orders);
        orders.forEach((o: any) => {
          if (knownIds.current.has(o.id)) return;
          knownIds.current.add(o.id);
          if (!initialized.current) return;
          playNotificationSound();
          showToast(`Nouvelle commande ${o?.orderNumber || ""} !`);
          if (navigator.vibrate) navigator.vibrate([300, 100, 300, 100, 300]);
        });
      } catch (e) {
        // Silently fail when backend is unreachable
      }
    }, 15000);

    return () => clearInterval(interval);
  }, [queryClient]);
}
