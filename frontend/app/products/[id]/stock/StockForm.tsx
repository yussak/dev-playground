"use client";

import { useState } from "react";
import { updateStock, adjustStock } from "./actions";

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
  const [adjustments, setAdjustments] = useState<Record<number, string>>(
    Object.fromEntries(variants.map((v) => [v.id, ""]))
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

  async function handleAdjust(variantId: number) {
    const adj = Number(adjustments[variantId]);
    if (isNaN(adj) || adj === 0) return;
    setSavingId(variantId);
    setMessages((prev) => ({ ...prev, [variantId]: "" }));
    try {
      const result = await adjustStock(variantId, adj);
      setQuantities((prev) => ({ ...prev, [variantId]: String(result.quantity) }));
      setAdjustments((prev) => ({ ...prev, [variantId]: "" }));
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
    <table style={{ borderCollapse: "collapse", width: "100%" }}>
      <thead>
        <tr>
          <th style={{ textAlign: "left", padding: "0.5rem", borderBottom: "1px solid #ccc" }}>商品オプション</th>
          <th style={{ textAlign: "center", padding: "0.5rem", borderBottom: "1px solid #ccc" }}>在庫数（絶対値）</th>
          <th style={{ textAlign: "center", padding: "0.5rem", borderBottom: "1px solid #ccc" }}>増減（+N / -N）</th>
          <th style={{ padding: "0.5rem", borderBottom: "1px solid #ccc" }}></th>
        </tr>
      </thead>
      <tbody>
        {variants.map((v) => (
          <tr key={v.id}>
            <td style={{ padding: "0.5rem" }}>{variantLabel(v)}</td>
            <td style={{ textAlign: "center", padding: "0.5rem" }}>
              <input
                type="text"
                inputMode="numeric"
                value={quantities[v.id]}
                onChange={(e) => setQuantities((prev) => ({ ...prev, [v.id]: e.target.value }))}
                style={{ width: "6rem", textAlign: "center" }}
                disabled={savingId === v.id}
              />
              <button
                type="button"
                onClick={() => handleSave(v.id)}
                disabled={savingId === v.id}
                style={{ marginLeft: "0.5rem" }}
              >
                {savingId === v.id ? "保存中..." : "保存"}
              </button>
            </td>
            <td style={{ textAlign: "center", padding: "0.5rem" }}>
              <input
                type="text"
                inputMode="numeric"
                placeholder="+5 または -3"
                value={adjustments[v.id]}
                onChange={(e) => setAdjustments((prev) => ({ ...prev, [v.id]: e.target.value }))}
                style={{ width: "8rem", textAlign: "center" }}
                disabled={savingId === v.id}
              />
              <button
                type="button"
                onClick={() => handleAdjust(v.id)}
                disabled={savingId === v.id || !adjustments[v.id]}
                style={{ marginLeft: "0.5rem" }}
              >
                反映
              </button>
            </td>
            <td style={{ padding: "0.5rem" }}>
              {messages[v.id] && (
                <span style={{ color: messages[v.id].includes("失敗") ? "red" : "green" }}>
                  {messages[v.id]}
                </span>
              )}
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
