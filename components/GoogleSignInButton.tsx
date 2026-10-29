"use client";

import { useEffect, useRef, useState } from "react";
import { useI18n } from "@/lib/i18n";

declare global {
  interface Window {
    google?: {
      accounts: {
        id: {
          initialize: (cfg: {
            client_id: string;
            callback: (resp: { credential?: string }) => void;
          }) => void;
          renderButton: (
            el: HTMLElement,
            opts: Record<string, string | number>
          ) => void;
        };
      };
    };
  }
}

const CLIENT_ID = process.env.NEXT_PUBLIC_GOOGLE_CLIENT_ID;
const SCRIPT_ID = "google-identity-services";

function loadGis(): Promise<void> {
  return new Promise((resolve, reject) => {
    if (typeof window === "undefined") return reject(new Error("ssr"));
    if (window.google?.accounts?.id) return resolve();
    const existing = document.getElementById(SCRIPT_ID) as HTMLScriptElement | null;
    if (existing) {
      existing.addEventListener("load", () => resolve(), { once: true });
      existing.addEventListener("error", () => reject(new Error("gis load failed")), { once: true });
      return;
    }
    const s = document.createElement("script");
    s.id = SCRIPT_ID;
    s.src = "https://accounts.google.com/gsi/client";
    s.async = true;
    s.defer = true;
    s.onload = () => resolve();
    s.onerror = () => reject(new Error("gis load failed"));
    document.head.appendChild(s);
  });
}

export default function GoogleSignInButton({
  onCredential,
  onError,
  disabled,
}: {
  onCredential: (idToken: string) => void;
  onError?: () => void;
  disabled?: boolean;
}) {
  const hostRef = useRef<HTMLDivElement>(null);
  const [failed, setFailed] = useState(false);
  const { lang, t } = useI18n();
  const cbRef = useRef(onCredential);
  cbRef.current = onCredential;
  const errRef = useRef(onError);
  errRef.current = onError;

  useEffect(() => {
    if (!CLIENT_ID) {
      setFailed(true);
      return;
    }
    let cancelled = false;
    loadGis()
      .then(() => {
        if (cancelled || !hostRef.current || !window.google) return;
        hostRef.current.innerHTML = "";
        window.google.accounts.id.initialize({
          client_id: CLIENT_ID,
          callback: (resp) => {
            if (resp?.credential) cbRef.current(resp.credential);
            else errRef.current?.();
          },
        });
        window.google.accounts.id.renderButton(hostRef.current, {
          theme: "filled_black",
          size: "large",
          shape: "pill",
          text: "continue_with",
          width: hostRef.current.offsetWidth || 320,
          locale: lang,
        });
      })
      .catch(() => setFailed(true));
    return () => {
      cancelled = true;
    };
  }, [lang]);

  if (!CLIENT_ID || failed) return null;

  return (
    <div
      ref={hostRef}
      aria-label={t("google_continue")}
      className={`w-full flex justify-center transition-opacity ${
        disabled ? "opacity-50 pointer-events-none" : ""
      }`}
    />
  );
}
