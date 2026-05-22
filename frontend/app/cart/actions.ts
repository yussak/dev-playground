"use server";

import { apiFetch } from "@/lib/api";
import { revalidatePath } from "next/cache";

export async function addToCart(productVariantId: number) {
  const res = await apiFetch("/api/v1/cart/items", {
    method: "POST",
    body: JSON.stringify({ product_variant_id: productVariantId }),
  });
  if (!res.ok) {
    const data = await res.json();
    throw new Error(data.error ?? "カートへの追加に失敗しました");
  }
  revalidatePath("/cart");
}

export async function updateCartItemQuantity(itemId: number, quantity: number) {
  const res = await apiFetch(`/api/v1/cart/items/${itemId}`, {
    method: "PATCH",
    body: JSON.stringify({ quantity }),
  });
  if (!res.ok) {
    const data = await res.json();
    throw new Error(data.error ?? "数量の変更に失敗しました");
  }
  revalidatePath("/cart");
}

export async function removeCartItem(itemId: number) {
  const res = await apiFetch(`/api/v1/cart/items/${itemId}`, {
    method: "DELETE",
  });
  if (!res.ok) {
    const data = await res.json();
    throw new Error(data.error ?? "カートからの削除に失敗しました");
  }
  revalidatePath("/cart");
}
