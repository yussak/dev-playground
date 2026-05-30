"use server";

import { apiFetch } from "@/lib/api";
import { revalidatePath } from "next/cache";

export async function placeOrder(couponCode?: string) {
  const res = await apiFetch("/api/v1/orders", {
    method: "POST",
    body: JSON.stringify(couponCode ? { coupon_code: couponCode } : {}),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.error ?? "注文に失敗しました");
  revalidatePath("/orders");
  if (!data.partially_unavailable) {
    revalidatePath("/cart");
  }
  return data;
}

export async function cancelOrder(orderId: number) {
  const res = await apiFetch(`/api/v1/orders/${orderId}/cancel`, {
    method: "PATCH",
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.error ?? "キャンセルに失敗しました");
  revalidatePath("/orders");
  revalidatePath(`/orders/${orderId}`);
  return data;
}
