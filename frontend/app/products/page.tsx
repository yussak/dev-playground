import Link from "next/link";
import { auth } from "@/auth";
import { apiFetch } from "@/lib/api";
import DeleteButton from "./[id]/DeleteButton";
import NewProductButton from "./NewProductButton";

type Product = {
  id: number;
  name: string;
  description: string | null;
  min_price: number;
  max_price: number;
  user_id: number;
  total_stock: number;
};

function formatPrice(product: Product): string {
  if (product.min_price === product.max_price) {
    return `${product.min_price}円`;
  }
  return `${product.min_price}円 〜 ${product.max_price}円`;
}

function stockLabel(totalStock: number): { text: string; color: string } | null {
  if (totalStock === 0) return { text: "在庫切れ", color: "#999" };
  if (totalStock <= 5) return { text: "残りわずか", color: "#d97706" };
  return null;
}

async function fetchProducts(): Promise<Product[]> {
  const res = await apiFetch("/api/v1/products", { cache: "no-store" });
  if (!res.ok) throw new Error("商品の取得に失敗しました");
  return res.json();
}

export default async function ProductsPage() {
  const [products, session] = await Promise.all([fetchProducts(), auth()]);
  const currentUserId = (session?.user as { id?: string } | undefined)?.id;

  return (
    <main style={{ padding: "2rem", fontFamily: "sans-serif" }}>
      <h1>商品一覧</h1>
      <NewProductButton />
      {products.length === 0 ? (
        <p>商品がありません</p>
      ) : (
        <ul>
          {products.map((product) => {
            const label = stockLabel(product.total_stock);
            return (
              <li key={product.id} style={{ marginBottom: "1rem" }}>
                <Link href={`/products/${product.id}`} style={{ color: "blue", textDecoration: "underline" }}>
                  <strong>{product.name}</strong>
                </Link>{" "}
                — {formatPrice(product)}
                {label && (
                  <span style={{ marginLeft: "0.5rem", color: label.color }}>{label.text}</span>
                )}
                {product.description && <p>{product.description}</p>}
                {currentUserId === String(product.user_id) && <DeleteButton productId={product.id} />}
              </li>
            );
          })}
        </ul>
      )}
    </main>
  );
}
