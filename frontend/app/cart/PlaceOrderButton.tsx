"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";

type UnavailableItem = {
  product_name: string;
  size: string | null;
  color: string | null;
};

type OrderResult = {
  id: number;
  partially_unavailable: boolean;
  unavailable_items?: UnavailableItem[];
};

export default function PlaceOrderButton() {
  const [loading, setLoading] = useState(false);
  const [couponCode, setCouponCode] = useState("");
  const [result, setResult] = useState<OrderResult | null>(null);
  const router = useRouter();

  async function handleClick() {
    if (!confirm("注文を確定しますか？")) return;
    setLoading(true);
    try {
      const body = couponCode.trim() ? { coupon_code: couponCode.trim() } : {};
      const res = await fetch("/api/orders", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error ?? "注文に失敗しました");
      if (data.partially_unavailable) {
        setResult(data);
      } else {
        router.push(`/orders/${data.id}`);
      }
    } catch (e) {
      alert(e instanceof Error ? e.message : "注文に失敗しました");
    }
    setLoading(false);
  }

  function variantLabel(item: UnavailableItem): string {
    const parts = [item.size, item.color].filter(Boolean);
    return parts.length > 0 ? `（${parts.join(" / ")}）` : "";
  }

  return (
    <>
      <div style={{ marginTop: "1rem" }}>
        <div style={{ marginBottom: "0.5rem" }}>
          <label>
            クーポンコード:{" "}
            <input
              type="text"
              value={couponCode}
              onChange={(e) => setCouponCode(e.target.value)}
              disabled={loading}
              style={{ padding: "0.25rem 0.5rem", fontSize: "1rem" }}
            />
          </label>
        </div>
        <button
          onClick={handleClick}
          disabled={loading}
          style={{ padding: "0.5rem 1rem", fontSize: "1rem" }}
        >
          {loading ? "処理中..." : "注文を確定する"}
        </button>
      </div>
      {result && (
        <div style={{
          position: "fixed", inset: 0, background: "rgba(0,0,0,0.5)",
          display: "flex", alignItems: "center", justifyContent: "center", zIndex: 100
        }}>
          <div style={{ background: "#fff", padding: "2rem", borderRadius: "8px", maxWidth: "480px", width: "100%" }}>
            <h2 style={{ marginTop: 0 }}>購入完了しました</h2>
            <p>以下の商品は在庫切れのため購入できませんでした</p>
            <ul>
              {(result.unavailable_items ?? []).map((item, i) => (
                <li key={i}>{item.product_name}{variantLabel(item)}</li>
              ))}
            </ul>
            <button
              onClick={() => {
                router.push(`/orders/${result.id}`);
                router.refresh();
              }}
              style={{ padding: "0.5rem 1rem", fontSize: "1rem" }}
            >
              注文詳細を見る
            </button>
          </div>
        </div>
      )}
    </>
  );
}
