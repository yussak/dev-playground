import { apiFetch } from "@/lib/api";
import { auth } from "@/auth";
import { redirect, notFound } from "next/navigation";
import Link from "next/link";
import CancelOrderButton from "./CancelOrderButton";

type OrderItem = {
  id: number;
  product_id: number | null;
  product_variant_id: number | null;
  product_name: string;
  size: string | null;
  color: string | null;
  unit_price: number;
  quantity: number;
  subtotal: number;
};

function variantLabel(item: OrderItem): string {
  const parts = [item.size, item.color].filter(Boolean);
  return parts.length > 0 ? `（${parts.join(" / ")}）` : "";
}

type OrderDetail = {
  id: number;
  order_number: string;
  status: string;
  items: OrderItem[];
  subtotal: number;
  discount_amount: number;
  total: number;
  created_at: string;
};

async function fetchOrder(id: string): Promise<OrderDetail | null> {
  const res = await apiFetch(`/api/v1/orders/${id}`, { cache: "no-store" });
  if (res.status === 404) return null;
  if (!res.ok) throw new Error("注文の取得に失敗しました");
  return res.json();
}

function statusLabel(status: string): string {
  switch (status) {
    case "confirmed": return "確定済み";
    case "cancelled": return "キャンセル済み";
    default: return status;
  }
}

export default async function OrderDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const session = await auth();
  if (!session) redirect("/auth/login");

  const { id } = await params;
  const order = await fetchOrder(id);
  if (!order) notFound();

  return (
    <main style={{ padding: "2rem", fontFamily: "sans-serif" }}>
      <h1>注文詳細</h1>
      <p>注文番号: {order.order_number}</p>
      <p>日時: {new Date(order.created_at).toLocaleString("ja-JP")}</p>
      <p>ステータス: {statusLabel(order.status)}</p>

      <table style={{ borderCollapse: "collapse", width: "100%", marginTop: "1rem" }}>
        <thead>
          <tr>
            <th style={{ textAlign: "left", borderBottom: "1px solid #ccc", padding: "0.5rem" }}>商品名</th>
            <th style={{ textAlign: "right", borderBottom: "1px solid #ccc", padding: "0.5rem" }}>単価</th>
            <th style={{ textAlign: "center", borderBottom: "1px solid #ccc", padding: "0.5rem" }}>数量</th>
            <th style={{ textAlign: "right", borderBottom: "1px solid #ccc", padding: "0.5rem" }}>小計</th>
          </tr>
        </thead>
        <tbody>
          {order.items.map((item) => (
            <tr key={item.id}>
              <td style={{ padding: "0.5rem" }}>
                {item.product_id ? (
                  <Link href={`/products/${item.product_id}`} style={{ color: "blue", textDecoration: "underline" }}>
                    {item.product_name}
                  </Link>
                ) : (
                  item.product_name
                )}
                {variantLabel(item) && (
                  <span style={{ color: "#666", marginLeft: "0.25rem" }}>{variantLabel(item)}</span>
                )}
              </td>
              <td style={{ textAlign: "right", padding: "0.5rem" }}>{item.unit_price}円</td>
              <td style={{ textAlign: "center", padding: "0.5rem" }}>{item.quantity}</td>
              <td style={{ textAlign: "right", padding: "0.5rem" }}>{item.subtotal}円</td>
            </tr>
          ))}
        </tbody>
      </table>

      <div style={{ marginTop: "1rem", textAlign: "right" }}>
        <p>小計: {order.subtotal}円</p>
        {order.discount_amount > 0 && (
          <p>クーポン割引: -{order.discount_amount}円</p>
        )}
        <p style={{ fontSize: "1.2rem", fontWeight: "bold" }}>
          合計: {order.total}円
        </p>
      </div>

      {order.status === "confirmed" && <CancelOrderButton orderId={order.id} />}

      <p style={{ marginTop: "1rem" }}>
        <Link href="/orders" style={{ color: "blue", textDecoration: "underline" }}>注文履歴に戻る</Link>
      </p>
    </main>
  );
}
