"use client";

import { useState, useRef, useEffect } from "react";
import { Sparkles, X, ArrowUp } from "lucide-react";

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
        className="btn-neon fixed bottom-28 md:bottom-5 right-4 md:right-5 z-50 !w-12 !h-12 md:!w-14 md:!h-14 !min-h-0 !p-0"
      >
        <Sparkles className="w-6 h-6" strokeWidth={2.2} />
      </button>
      {open && (
        <div className="fixed bottom-44 md:bottom-24 right-4 md:right-5 z-50 w-[min(92vw,360px)] h-[min(70vh,480px)] rounded-2xl border border-border bg-card text-foreground shadow-2xl flex flex-col overflow-hidden">
          <div className="flex items-center justify-between pl-4 pr-2 py-2 border-b border-border">
            <div className="flex items-center gap-2">
              <div className="w-8 h-8 rounded-full bg-neon flex items-center justify-center text-fast-ink">
                <Sparkles className="w-4 h-4" strokeWidth={2.4} />
              </div>
              <span className="font-display font-bold text-foreground text-base notranslate">
                Assistant FAST
              </span>
            </div>
            <button
              onClick={() => setOpen(false)}
              className="w-11 h-11 rounded-full flex items-center justify-center text-muted-foreground hover:text-foreground hover:bg-muted transition-colors"
              aria-label="Fermer"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
          <div className="flex-1 overflow-y-auto p-3 space-y-2">
            {messages.map((m, i) => (
              <div
                key={i}
                className={`w-fit max-w-[80%] px-3.5 py-2 rounded-2xl text-sm leading-relaxed ${
                  m.role === "user"
                    ? "ml-auto bg-primary text-primary-foreground font-medium rounded-br-md"
                    : "bg-muted text-foreground rounded-bl-md"
                }`}
              >
                {m.text}
              </div>
            ))}
            {sending && (
              <div className="bg-muted rounded-2xl rounded-bl-md px-3 py-2 w-16">
                <span className="inline-block animate-pulse text-muted-foreground">
                  •••
                </span>
              </div>
            )}
            <div ref={bottomRef} />
          </div>
          <div className="p-3 border-t border-border flex items-center gap-2">
            <input
              value={input}
              onChange={(e) => setInput(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && send()}
              placeholder="Posez votre question…"
              className="flex-1 min-w-0 h-11 bg-muted border border-border rounded-full px-4 text-sm text-foreground placeholder:text-muted-foreground outline-none focus:border-fast-rose"
            />
            <button
              onClick={send}
              disabled={sending}
              className="w-11 h-11 shrink-0 rounded-full bg-primary text-primary-foreground flex items-center justify-center transition-transform active:scale-95 disabled:opacity-50"
              aria-label="Envoyer"
            >
              <ArrowUp className="w-5 h-5" strokeWidth={2.6} />
            </button>
          </div>
        </div>
      )}
    </>
  );
}
