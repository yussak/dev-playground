import { notFound } from "next/navigation";
import { auth } from "@/auth";
import { apiFetch } from "@/lib/api";
import DeleteButton from "./DeleteButton";
import DeleteCouponButton from "./coupons/DeleteCouponButton";
import CopyCouponCodeButton from "./coupons/CopyCouponCodeButton";
import AddToCartButton from "../../cart/AddToCartButton";

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

function variantLabel(v: Variant): string {
  const parts = [v.size, v.color].filter(Boolean);
  return parts.length > 0 ? parts.join(" / ") : "標準";
}

type Coupon = {
  id: number;
  code: string;
  discount_type: "fixed" | "percentage";
  discount_value: number;
  expires_at: string;
};

// データ取得・認証判定はサーバー側で行うべき by claude（ブラウザに機密情報を渡さない、APIキーを隠蔽する）。
// onClickなどのイベントハンドラもhooksも使わないためClient Componentにする理由がない。
async function fetchProduct(id: string): Promise<Product | null> {
  const res = await apiFetch(`/api/v1/products/${id}`, { cache: "no-store" });
  if (res.status === 404) return null;
  if (!res.ok) throw new Error("商品の取得に失敗しました");
  return res.json();
}

async function fetchCoupons(productId: number): Promise<Coupon[]> {
  const res = await apiFetch(`/api/v1/products/${productId}/coupons`, { cache: "no-store" });
  if (!res.ok) return [];
  return res.json();
}

export default async function ProductPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const [product, session] = await Promise.all([fetchProduct(id), auth()]);

  if (!product) notFound();

  const currentUserId = (session?.user as { id?: string } | undefined)?.id;
  const isOwner = currentUserId === String(product.user_id);

  const coupons = isOwner ? await fetchCoupons(product.id) : [];

  return (
    <main style={{ padding: "2rem", fontFamily: "sans-serif" }}>
      <h1>{product.name}</h1>
      {product.description && <p>説明: {product.description}</p>}
      <section>
        <h2 style={{ fontSize: "1.1rem" }}>バリアント</h2>
        <ul>
          {product.variants.map((v) => (
            <li key={v.id}>
              {variantLabel(v)} — {v.price}円
            </li>
          ))}
        </ul>
      </section>
      <AddToCartButton productId={product.id} />
      {isOwner && <a href={`/products/${product.id}/edit`}>編集</a>}
      {isOwner && coupons.length === 0 && (
        <a href={`/products/${product.id}/coupons/new`}>クーポン作成</a>
      )}
      {isOwner && <DeleteButton productId={product.id} />}
      {isOwner && coupons.length > 0 && (
        <section style={{ marginTop: "2rem" }}>
          <h2>クーポン</h2>
          {coupons.map((coupon) => (
            <div key={coupon.id} style={{ border: "1px solid #ccc", padding: "1rem", marginBottom: "0.5rem" }}>
              <p>
                コード: {coupon.code}
                <CopyCouponCodeButton code={coupon.code} />
              </p>
              <p>
                割引: {coupon.discount_value}
                {coupon.discount_type === "fixed" ? "円" : "%"}
              </p>
              <p>有効期限: {new Date(coupon.expires_at).toLocaleString()}</p>
              <a href={`/products/${product.id}/coupons/${coupon.id}/edit`}>編集</a>
              <DeleteCouponButton productId={product.id} couponId={coupon.id} />
            </div>
          ))}
        </section>
      )}
    </main>
  );
}
