"use client";

import { useState } from "react";
import { updateStock } from "./actions";

type Variant = {
  id: number;
  size: string | null;
  color: string | null;
  price: number;
  stock: number;
};

function variantLabel(v: Variant): string {
  const parts = [v.size, v.color].filter(Boolean);
  return parts.length > 0 ? parts.join(" / ") : "標準";
}

export default function StockForm({ variants }: { variants: Variant[] }) {
  const [quantities, setQuantities] = useState<Record<number, string>>(
    Object.fromEntries(variants.map((v) => [v.id, String(v.stock)]))
  );
  const [savingId, setSavingId] = useState<number | null>(null);
  const [messages, setMessages] = useState<Record<number, string>>({});

  async function handleSave(variantId: number) {
    setSavingId(variantId);
    setMessages((prev) => ({ ...prev, [variantId]: "" }));
    try {
      const result = await updateStock(variantId, Number(quantities[variantId]));
      setQuantities((prev) => ({ ...prev, [variantId]: String(result.quantity) }));
      setMessages((prev) => ({ ...prev, [variantId]: "保存しました" }));
    } catch (e) {
      setMessages((prev) => ({
        ...prev,
        [variantId]: e instanceof Error ? e.message : "保存に失敗しました",
      }));
    }
    setSavingId(null);
  }

  return (
    <ul style={{ listStyle: "none", paddingLeft: 0 }}>
      {variants.map((v) => (
        <li key={v.id} style={{ display: "flex", gap: "0.5rem", marginBottom: "0.5rem", alignItems: "center" }}>
          <span style={{ flex: 1 }}>{variantLabel(v)}</span>
          <input
            type="text"
            inputMode="numeric"
            value={quantities[v.id]}
            onChange={(e) => setQuantities((prev) => ({ ...prev, [v.id]: e.target.value }))}
            style={{ width: "6rem" }}
          />
          <button type="button" onClick={() => handleSave(v.id)} disabled={savingId === v.id}>
            {savingId === v.id ? "保存中..." : "保存"}
          </button>
          {messages[v.id] && (
            <span style={{ color: messages[v.id].includes("失敗") ? "red" : "green" }}>{messages[v.id]}</span>
          )}
        </li>
      ))}
    </ul>
  );
}
