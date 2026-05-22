"use server";

import { apiFetch } from "@/lib/api";
import { redirect } from "next/navigation";

type VariantPayload = { size: string | null; color: string | null; price: number };

export async function createProduct(formData: {
  name: string;
  description: string | null;
  variants: VariantPayload[];
}) {
  const res = await apiFetch("/api/v1/products", {
    method: "POST",
    body: JSON.stringify(formData),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.errors?.join(", ") ?? "商品の作成に失敗しました");
  redirect(`/products/${data.id}`);
}
