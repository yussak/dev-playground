"use server";

import { apiFetch } from "@/lib/api";

export async function updateStock(productVariantId: number, quantity: number) {
  const res = await apiFetch(`/api/v1/product_variants/${productVariantId}/stock`, {
    method: "PATCH",
    body: JSON.stringify({ quantity }),
  });
  const data = await res.json();
  if (!res.ok) {
    throw new Error(data.errors?.join(", ") ?? data.error ?? "在庫の更新に失敗しました");
  }
  return data as { product_variant_id: number; quantity: number };
}

export async function adjustStock(productVariantId: number, adjustment: number) {
  const res = await apiFetch(`/api/v1/product_variants/${productVariantId}/stock/adjust`, {
    method: "PATCH",
    body: JSON.stringify({ adjustment }),
  });
  const data = await res.json();
  if (!res.ok) {
    throw new Error(data.errors?.join(", ") ?? data.error ?? "在庫の更新に失敗しました");
  }
  return data as { product_variant_id: number; quantity: number };
}
