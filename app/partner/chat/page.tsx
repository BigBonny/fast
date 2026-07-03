"use client";

import { useEffect, useState } from "react";
import { Send, MessageSquare, User, CheckCheck, Clock } from "lucide-react";
import { showToast } from "@/components/partner/Toast";

const MOCK_CLIENTS = [
  { id: "c1", name: "Sophie Martin", lastMessage: "Ma commande est-elle prête ?", time: "14:32", unread: true },
  { id: "c2", name: "Thomas Dubois", lastMessage: "Merci, c'était excellent !", time: "Hier", unread: false },
  { id: "c3", name: "Léa Bernard", lastMessage: "Je vais arriver dans 5 min", time: "Hier", unread: false },
];

export default function ChatPage() {
  const [activeClient, setActiveClient] = useState(MOCK_CLIENTS[0]);
  const [messages, setMessages] = useState<Record<string, { text: string; me: boolean; time: string }[]>>({});
  const [input, setInput] = useState("");

  useEffect(() => {
    const saved = localStorage.getItem("fast_chat");
    if (saved) setMessages(JSON.parse(saved));
  }, []);

  useEffect(() => {
    localStorage.setItem("fast_chat", JSON.stringify(messages));
  }, [messages]);

  const handleSend = (e: React.FormEvent) => {
    e.preventDefault();
    if (!input.trim()) return;
    const now = new Date().toLocaleTimeString("fr-FR", { hour: "2-digit", minute: "2-digit" });
    setMessages((prev) => ({
      ...prev,
      [activeClient.id]: [...(prev[activeClient.id] || []), { text: input, me: true, time: now }],
    }));
    setInput("");
    setTimeout(() => {
      setMessages((prev) => ({
        ...prev,
        [activeClient.id]: [...(prev[activeClient.id] || []), { text: "Merci pour votre message, nous vous répondons au plus vite !", me: false, time: now }],
      }));
      showToast(" Réponse automatique envoyée");
    }, 800);
  };

  const currentMessages = messages[activeClient.id] || [];

  return (
    <div className="space-y-4 h-[calc(100vh-140px)] flex flex-col">
      <div className="flex items-center gap-2">
        <MessageSquare className="w-5 h-5 text-[#00c8b3]" />
        <h1 className="text-lg font-black text-white">Messages clients</h1>
      </div>

      <div className="flex flex-1 gap-3 overflow-hidden">
        <div className="w-1/3 bg-[#0B1120] border border-white/[0.08] rounded-2xl overflow-y-auto hidden sm:block">
          {MOCK_CLIENTS.map((c) => (
            <button
              key={c.id}
              onClick={() => setActiveClient(c)}
              className={`w-full text-left px-3 py-3 border-b border-white/[0.06] transition-colors ${activeClient.id === c.id ? "bg-[#00c8b3]/10" : "hover:bg-white/[0.02]"}`}
            >
              <div className="flex items-center gap-2">
                <div className="w-8 h-8 rounded-full bg-white/[0.08] flex items-center justify-center text-xs"></div>
                <div className="flex-1 min-w-0">
                  <p className="text-xs font-bold text-white truncate">{c.name}</p>
                  <p className="text-[10px] text-slate-400 truncate">{c.lastMessage}</p>
                </div>
                {c.unread && <span className="w-2 h-2 rounded-full bg-[#00c8b3]" />}
              </div>
            </button>
          ))}
        </div>

        <div className="flex-1 bg-[#0B1120] border border-white/[0.08] rounded-2xl flex flex-col overflow-hidden">
          <div className="px-4 py-3 border-b border-white/[0.06] flex items-center gap-2">
            <User className="w-4 h-4 text-slate-400" />
            <span className="text-sm font-bold text-white">{activeClient.name}</span>
            <span className="text-[10px] text-slate-500 flex items-center gap-1 ml-auto"><Clock className="w-3 h-3" /> {activeClient.time}</span>
          </div>
          <div className="flex-1 overflow-y-auto p-3 space-y-2">
            {currentMessages.length === 0 ? (
              <p className="text-center text-slate-500 text-xs mt-8">Début de la conversation avec {activeClient.name}.</p>
            ) : (
              currentMessages.map((m, i) => (
                <div key={i} className={`flex ${m.me ? "justify-end" : "justify-start"}`}>
                  <div className={`max-w-[80%] rounded-2xl px-3 py-2 text-xs ${m.me ? "bg-[#00c8b3] text-[#020617]" : "bg-white/[0.06] text-slate-200"}`}>
                    {m.text}
                    <div className={`text-[9px] mt-1 flex items-center gap-1 ${m.me ? "text-[#020617]/70" : "text-slate-500"}`}>
                      {m.time} {m.me && <CheckCheck className="w-3 h-3" />}
                    </div>
                  </div>
                </div>
              ))
            )}
          </div>
          <form onSubmit={handleSend} className="p-3 border-t border-white/[0.06] flex gap-2">
            <input type="text" value={input} onChange={(e) => setInput(e.target.value)} placeholder="Votre message..." className="flex-1 bg-[#020617] border border-white/[0.08] rounded-xl px-3 py-2 text-sm text-white placeholder:text-slate-500 outline-none focus:border-[#00c8b3]/50" />
            <button type="submit" className="w-9 h-9 rounded-lg bg-[#00c8b3] text-[#020617] flex items-center justify-center"><Send className="w-4 h-4" /></button>
          </form>
        </div>
      </div>
    </div>
  );
}
