import { apiFetch } from "@/lib/api";
import { auth } from "@/auth";
import { redirect } from "next/navigation";
import CartItemRow from "./CartItemRow";
import PlaceOrderButton from "./PlaceOrderButton";

type CartItem = {
  id: number;
  product_id: number;
  product_variant_id: number;
  product_name: string;
  size: string | null;
  color: string | null;
  unit_price: number;
  quantity: number;
  subtotal: number;
  product_deleted: boolean;
  stock: number;
};

type CartResponse = {
  items: CartItem[];
  total: number;
};

async function fetchCart(): Promise<CartResponse> {
  const res = await apiFetch("/api/v1/cart", { cache: "no-store" });
  if (!res.ok) throw new Error("カートの取得に失敗しました");
  return res.json();
}

export default async function CartPage() {
  const session = await auth();
  if (!session) redirect("/auth/login");

  const cart = await fetchCart();

  return (
    <main style={{ padding: "2rem", fontFamily: "sans-serif" }}>
      <h1>カート</h1>
      {cart.items.length === 0 ? (
        <p>カートは空です</p>
      ) : (
        <>
          <table style={{ borderCollapse: "collapse", width: "100%" }}>
            <thead>
              <tr>
                <th style={{ textAlign: "left", borderBottom: "1px solid #ccc", padding: "0.5rem" }}>商品名</th>
                <th style={{ textAlign: "right", borderBottom: "1px solid #ccc", padding: "0.5rem" }}>単価</th>
                <th style={{ textAlign: "center", borderBottom: "1px solid #ccc", padding: "0.5rem" }}>数量</th>
                <th style={{ textAlign: "right", borderBottom: "1px solid #ccc", padding: "0.5rem" }}>小計</th>
                <th style={{ borderBottom: "1px solid #ccc", padding: "0.5rem" }}></th>
              </tr>
            </thead>
            <tbody>
              {cart.items.map((item) => (
                <CartItemRow key={item.id} item={item} />
              ))}
            </tbody>
          </table>
          <p style={{ fontSize: "1.2rem", fontWeight: "bold", marginTop: "1rem" }}>
            合計: {cart.total}円
          </p>
          <PlaceOrderButton />
        </>
      )}
    </main>
  );
}
