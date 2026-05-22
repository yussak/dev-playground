"use client";

import { useState, FormEvent } from "react";
import Link from "next/link";
import { createProduct } from "./actions";

type VariantInput = { size: string; color: string; price: string };

export default function NewProductPage() {
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [variants, setVariants] = useState<VariantInput[]>([{ size: "", color: "", price: "" }]);
  const [error, setError] = useState<string | null>(null);

  function updateVariant(index: number, key: keyof VariantInput, value: string) {
    setVariants((prev) => prev.map((v, i) => (i === index ? { ...v, [key]: value } : v)));
  }

  function addVariant() {
    setVariants((prev) => [...prev, { size: "", color: "", price: "" }]);
  }

  function removeVariant(index: number) {
    setVariants((prev) => prev.filter((_, i) => i !== index));
  }

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    try {
      await createProduct({
        name,
        description: description || null,
        variants: variants.map((v) => ({
          size: v.size || null,
          color: v.color || null,
          price: Number(v.price),
        })),
      });
    } catch (e) {
      setError(e instanceof Error ? e.message : "商品の作成に失敗しました");
    }
  }

  return (
    <main style={{ padding: "2rem", fontFamily: "sans-serif", maxWidth: "600px" }}>
      <h1>商品を登録</h1>
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

        <h2 style={{ fontSize: "1.1rem" }}>バリアント</h2>
        <p style={{ fontSize: "0.85rem", color: "#666" }}>
          サイズ・カラーは任意（バリアントなしの商品は両方空欄で1件登録）。サイズ・カラーの有無は全バリアントで揃える必要があります。
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
              type="number"
              min="0"
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
          バリアントを追加
        </button>

        {error && <p style={{ color: "red" }}>{error}</p>}
        <div>
          <button type="submit">登録する</button>
        </div>
      </form>
      <p>
        <Link href="/products">商品一覧に戻る</Link>
      </p>
    </main>
  );
}
