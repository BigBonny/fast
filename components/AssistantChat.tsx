"use client";

import { useState, useRef, useEffect } from "react";

const API_URL =
  process.env.NEXT_PUBLIC_API_URL ||
  "https://backend-six-iota-69.vercel.app/api";

type Msg = { role: "user" | "model"; text: string };

export default function AssistantChat() {
  const [open, setOpen] = useState(false);
  const [input, setInput] = useState("");
  const [messages, setMessages] = useState<Msg[]>([
    {
      role: "model",
      text: "Salut ! Je suis l’assistant FAST — demandez-moi un plat, un resto ou de l’aide sur votre commande.",
    },
  ]);
  const [sending, setSending] = useState(false);
  const bottomRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages, sending]);

  async function send() {
    const text = input.trim();
    if (!text || sending) return;
    setInput("");
    setSending(true);
    const next = [...messages, { role: "user" as const, text }];
    setMessages(next);
    try {
      const res = await fetch(`${API_URL}/assistant/chat`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          message: text,
          history: next.slice(-10).map((m) => ({ role: m.role, text: m.text })),
        }),
      });
      const data = (await res.json()) as { reply?: string };
      setMessages((m) => [
        ...m,
        { role: "model", text: data.reply || "Désolé, je n’ai pas de réponse." },
      ]);
    } catch {
      setMessages((m) => [
        ...m,
        { role: "model", text: "Désolé, je n’arrive pas à répondre pour le moment." },
      ]);
    } finally {
      setSending(false);
    }
  }

  return (
    <>
      <button
        onClick={() => setOpen(!open)}
        aria-label="Assistant FAST"
        className="fixed bottom-5 right-5 z-50 w-14 h-14 rounded-full bg-gradient-to-br from-amber-400 to-amber-600 shadow-lg shadow-amber-500/30 flex items-center justify-center text-2xl hover:scale-105 transition-transform"
      >
        ⚡
      </button>
      {open && (
        <div className="fixed bottom-24 right-5 z-50 w-[min(92vw,360px)] h-[min(70vh,480px)] rounded-2xl border border-slate-700 bg-slate-900/95 backdrop-blur-xl shadow-2xl flex flex-col overflow-hidden">
          <div className="flex items-center justify-between px-4 py-3 border-b border-slate-700/60">
            <div className="flex items-center gap-2">
              <div className="w-7 h-7 rounded-lg bg-gradient-to-br from-amber-400 to-amber-600 flex items-center justify-center text-sm font-black text-slate-900">
                ⚡
              </div>
              <span className="font-black text-white text-sm notranslate">
                Assistant FAST
              </span>
            </div>
            <button
              onClick={() => setOpen(false)}
              className="text-slate-400 hover:text-white text-lg leading-none"
              aria-label="Fermer"
            >
              ×
            </button>
          </div>
          <div className="flex-1 overflow-y-auto p-3 space-y-2">
            {messages.map((m, i) => (
              <div
                key={i}
                className={`max-w-[80%] px-3 py-2 rounded-2xl text-[13px] leading-relaxed ${
                  m.role === "user"
                    ? "ml-auto bg-gradient-to-br from-amber-400 to-amber-600 text-slate-900 font-medium rounded-br-md"
                    : "bg-slate-800 text-slate-100 rounded-bl-md border border-slate-700/60"
                }`}
              >
                {m.text}
              </div>
            ))}
            {sending && (
              <div className="bg-slate-800 border border-slate-700/60 rounded-2xl rounded-bl-md px-3 py-2 w-16">
                <span className="inline-block animate-pulse text-slate-400">
                  •••
                </span>
              </div>
            )}
            <div ref={bottomRef} />
          </div>
          <div className="p-3 border-t border-slate-700/60 flex gap-2">
            <input
              value={input}
              onChange={(e) => setInput(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && send()}
              placeholder="Posez votre question…"
              className="flex-1 bg-slate-800 border border-slate-700 rounded-full px-4 py-2 text-sm text-white placeholder:text-slate-500 outline-none focus:border-amber-500"
            />
            <button
              onClick={send}
              disabled={sending}
              className="w-10 h-10 rounded-full bg-gradient-to-br from-amber-400 to-amber-600 text-slate-900 font-black disabled:opacity-50"
              aria-label="Envoyer"
            >
              ➤
            </button>
          </div>
        </div>
      )}
    </>
  );
}
