import { notFound } from "next/navigation";
import { auth } from "@/auth";
import { apiFetch } from "@/lib/api";
import EditForm from "./EditForm";

type Variant = {
  id: number;
  size: string | null;
  color: string | null;
  price: number;
};

type Product = {
  id: number;
  name: string;
  description: string | null;
  user_id: number;
  variants: Variant[];
};

async function fetchProduct(id: string): Promise<Product | null> {
  const res = await apiFetch(`/api/v1/products/${id}`, { cache: "no-store" });
  if (res.status === 404) return null;
  if (!res.ok) throw new Error("商品の取得に失敗しました");
  return res.json();
}

export default async function EditProductPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const [product, session] = await Promise.all([fetchProduct(id), auth()]);

  if (!product) notFound();

  const currentUserId = (session?.user as { id?: string } | undefined)?.id;
  if (currentUserId !== String(product.user_id)) notFound();

  return (
    <main style={{ padding: "2rem", fontFamily: "sans-serif", maxWidth: "600px" }}>
      <h1>商品を編集</h1>
      <EditForm product={product} />
      <p>
        <a href={`/products/${product.id}`}>詳細に戻る</a>
      </p>
    </main>
  );
}
