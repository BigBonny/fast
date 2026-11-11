"use client";

import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Sparkles, TrendingUp, Flame, ChefHat, Send, Bot, ArrowRight } from "lucide-react";
import { statsApi, menuApi, restaurantApi } from "@/api/fastBackend";

const TIPS = [
  "Ajoutez des options végétariennes pour attirer plus de clients.",
  "Pensez à activer le mode Rush lors des pics d'activité.",
  "Mettez à jour vos photos de plats pour augmenter les conversions.",
  "Suivez vos plats les plus vendus pour optimiser votre menu.",
];

export default function AIPage() {
  const [input, setInput] = useState("");
  const [messages, setMessages] = useState<{ role: "user" | "bot"; text: string }[]>([
    { role: "bot", text: "Bonjour ! Je suis votre assistant FAST. Comment puis-je vous aider aujourd'hui ?" },
  ]);

  const { data: stats } = useQuery({ queryKey: ["stats"], queryFn: () => statsApi.get() });
  const { data: restaurant } = useQuery({ queryKey: ["my-restaurant"], queryFn: () => restaurantApi.mine() });
  const restaurantId = restaurant?.id;
  const { data: items = [] } = useQuery({
    queryKey: ["menu-items", restaurantId],
    queryFn: () => (restaurantId ? menuApi.byRestaurant(restaurantId) : Promise.resolve([])),
    enabled: !!restaurantId,
  });

  const suggestions = [
    { icon: TrendingUp, label: "Analyse des ventes", prompt: "Analyse mes ventes" },
    { icon: Flame, label: "Plats populaires", prompt: "Quels sont mes plats les plus populaires ?" },
    { icon: ChefHat, label: "Conseils menu", prompt: "Donne-moi des conseils pour améliorer mon menu" },
  ];

  const handleSend = (text: string) => {
    if (!text.trim()) return;
    setMessages((prev) => [...prev, { role: "user", text }]);
    setInput("");

    setTimeout(() => {
      let reply = "Je n'ai pas compris. Essayez une suggestion ci-dessus.";
      const lower = text.toLowerCase();
      if (lower.includes("vente") || lower.includes("chiffre") || lower.includes("commande")) {
        reply = `Vous avez ${stats?.totalOrders ?? 0} commandes au total, ${stats?.monthOrders ?? 0} ce mois-ci, et un chiffre d'affaires de ${(stats?.totalRevenue ?? 0).toFixed(2)} . Taux d'annulation : ${stats?.cancellationRate ?? 0}%.`;
      } else if (lower.includes("populaire") || lower.includes("plat")) {
        const top = stats?.popularItems?.slice(0, 3)?.map((i: any) => i.name).join(", ") || "pas assez de données";
        reply = `Vos plats les plus populaires : ${top}. Vous proposez ${items.length} articles au total.`;
      } else if (lower.includes("menu") || lower.includes("conseil")) {
        reply = TIPS[Math.floor(Math.random() * TIPS.length)];
      } else if (lower.includes("bonjour") || lower.includes("salut")) {
        reply = "Bonjour ! Prêt à booster votre restaurant ?";
      }
      setMessages((prev) => [...prev, { role: "bot", text: reply }]);
    }, 600);
  };

  return (
    <div className="space-y-4 h-[calc(100vh-180px)] flex flex-col">
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-xl bg-muted border border-border flex items-center justify-center"><Sparkles className="w-4 h-4 text-fast-teal" /></div>
        <h1 className="font-display text-2xl font-bold text-foreground">Assistant IA</h1>
      </div>

      <div className="flex-1 overflow-y-auto bg-card border border-border rounded-2xl p-4 space-y-3">
        {messages.map((m, i) => (
          <div key={i} className={`flex ${m.role === "user" ? "justify-end" : "justify-start"}`}>
            <div className={`max-w-[80%] rounded-2xl px-3.5 py-2.5 text-sm ${m.role === "user" ? "bg-fast-teal text-fast-ink font-medium" : "bg-muted text-foreground"}`}>
              {m.role === "bot" && <Bot className="w-3.5 h-3.5 inline mr-1.5 text-fast-teal" />}
              {m.text}
            </div>
          </div>
        ))}
      </div>

      <div className="flex gap-2 overflow-x-auto pb-1 scrollbar-hide">
        {suggestions.map((s) => {
          const Icon = s.icon;
          return (
            <button key={s.label} onClick={() => handleSend(s.prompt)} className="flex-shrink-0 inline-flex items-center gap-1.5 px-4 h-11 rounded-full bg-card border border-border text-xs font-bold text-muted-foreground hover:border-fast-teal hover:text-foreground transition-colors focus-visible:outline-fast-teal">
              <Icon className="w-3.5 h-3.5" /> {s.label}
            </button>
          );
        })}
      </div>

      <form
        onSubmit={(e) => { e.preventDefault(); handleSend(input); }}
        className="flex items-center gap-2 bg-card border border-border rounded-full pl-4 pr-1.5 py-1.5 focus-within:border-fast-teal focus-within:ring-2 focus-within:ring-fast-teal/30"
      >
        <input
          type="text"
          value={input}
          onChange={(e) => setInput(e.target.value)}
          placeholder="Posez une question..."
          className="flex-1 min-w-0 h-11 bg-transparent text-sm text-foreground placeholder:text-muted-foreground focus:outline-none"
        />
        <button type="submit" aria-label="Envoyer" className="w-11 h-11 rounded-full bg-fast-teal text-fast-ink flex items-center justify-center flex-shrink-0 transition-transform active:scale-95"><Send className="w-4 h-4" /></button>
      </form>
    </div>
  );
}
