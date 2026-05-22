"use client";

import { useState, FormEvent } from "react";
import { updateProduct } from "./actions";

type Variant = {
  id: number;
  size: string | null;
  color: string | null;
  price: number;
};

type VariantInput = { id: number | null; size: string; color: string; price: string };

type Props = {
  product: {
    id: number;
    name: string;
    description: string | null;
    variants: Variant[];
  };
};

export default function EditForm({ product }: Props) {
  const [name, setName] = useState(product.name);
  const [description, setDescription] = useState(product.description ?? "");
  const [variants, setVariants] = useState<VariantInput[]>(
    product.variants.map((v) => ({
      id: v.id,
      size: v.size ?? "",
      color: v.color ?? "",
      price: String(v.price),
    }))
  );
  const [error, setError] = useState<string | null>(null);

  function updateVariant(index: number, key: keyof Omit<VariantInput, "id">, value: string) {
    setVariants((prev) => prev.map((v, i) => (i === index ? { ...v, [key]: value } : v)));
  }

  function addVariant() {
    setVariants((prev) => [...prev, { id: null, size: "", color: "", price: "" }]);
  }

  function removeVariant(index: number) {
    setVariants((prev) => prev.filter((_, i) => i !== index));
  }

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    try {
      await updateProduct(product.id, {
        name,
        description: description || null,
        variants: variants.map((v) => ({
          id: v.id,
          size: v.size || null,
          color: v.color || null,
          price: Number(v.price),
        })),
      });
    } catch (e) {
      setError(e instanceof Error ? e.message : "商品の更新に失敗しました");
    }
  }

  return (
    <form onSubmit={handleSubmit}>
      <div>
        <label htmlFor="name">商品名</label>
        <br />
        <input
          id="name"
          type="text"
          value={name}
          onChange={(e) => setName(e.target.value)}
          required
          style={{ width: "100%", marginBottom: "1rem" }}
        />
      </div>
      <div>
        <label htmlFor="description">説明（任意）</label>
        <br />
        <textarea
          id="description"
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          style={{ width: "100%", marginBottom: "1rem" }}
        />
      </div>

      <h2 style={{ fontSize: "1.1rem" }}>商品オプション</h2>
      <p style={{ fontSize: "0.85rem", color: "#666" }}>
        ここから外した商品オプションは削除されます。サイズ・カラーの有無は全オプションで揃える必要があります。
      </p>
      {variants.map((v, i) => (
        <div key={i} style={{ display: "flex", gap: "0.5rem", marginBottom: "0.5rem", alignItems: "center" }}>
          <input
            type="text"
            placeholder="サイズ（任意）"
            value={v.size}
            onChange={(e) => updateVariant(i, "size", e.target.value)}
            style={{ flex: 1 }}
          />
          <input
            type="text"
            placeholder="カラー（任意）"
            value={v.color}
            onChange={(e) => updateVariant(i, "color", e.target.value)}
            style={{ flex: 1 }}
          />
          <input
            type="text"
            inputMode="numeric"
            placeholder="価格"
            value={v.price}
            onChange={(e) => updateVariant(i, "price", e.target.value)}
            required
            style={{ flex: 1 }}
          />
          {variants.length > 1 && (
            <button type="button" onClick={() => removeVariant(i)}>
              削除
            </button>
          )}
        </div>
      ))}
      <button type="button" onClick={addVariant} style={{ marginBottom: "1rem" }}>
        商品オプションを追加
      </button>

      {error && <p style={{ color: "red" }}>{error}</p>}
      <div>
        <button type="submit">更新する</button>
      </div>
    </form>
  );
}
