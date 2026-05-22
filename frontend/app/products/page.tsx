import Link from "next/link";
import { auth } from "@/auth";
import { apiFetch } from "@/lib/api";
import DeleteButton from "./[id]/DeleteButton";
import NewProductButton from "./NewProductButton";
import AddToCartButton from "../cart/AddToCartButton";

type Product = {
  id: number;
  name: string;
  description: string | null;
  min_price: number;
  max_price: number;
  user_id: number;
};

function formatPrice(product: Product): string {
  if (product.min_price === product.max_price) {
    return `${product.min_price}円`;
  }
  return `${product.min_price}円 〜 ${product.max_price}円`;
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
          {products.map((product) => (
            <li key={product.id} style={{ marginBottom: "1rem" }}>
              <Link href={`/products/${product.id}`} style={{ color: "blue", textDecoration: "underline" }}>
                <strong>{product.name}</strong>
              </Link>{" "}
              — {formatPrice(product)}
              {product.description && <p>{product.description}</p>}
              <AddToCartButton productId={product.id} />
              {currentUserId === String(product.user_id) && <DeleteButton productId={product.id} />}
              <span>デバッグ用：user_id={product.user_id}</span>
            </li>
          ))}
        </ul>
      )}
    </main>
  );
}
