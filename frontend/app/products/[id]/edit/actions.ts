"use server";

import { apiFetch } from "@/lib/api";
import { redirect } from "next/navigation";

type VariantPayload = {
  id: number | null;
  size: string | null;
  color: string | null;
  price: number;
};

export async function updateProduct(
  productId: number,
  formData: { name: string; description: string | null; variants: VariantPayload[] }
) {
  const res = await apiFetch(`/api/v1/products/${productId}`, {
    method: "PATCH",
    body: JSON.stringify(formData),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.errors?.join(", ") ?? data.error ?? "商品の更新に失敗しました");
  redirect(`/products/${productId}`);
}
