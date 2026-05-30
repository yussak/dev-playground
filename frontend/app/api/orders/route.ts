import { apiFetch } from "@/lib/api";
import { revalidatePath } from "next/cache";
import { NextRequest, NextResponse } from "next/server";

export async function POST(request: NextRequest) {
  const body = await request.json();
  const res = await apiFetch("/api/v1/orders", {
    method: "POST",
    body: JSON.stringify(body),
  });
  const data = await res.json();
  if (!res.ok) {
    return NextResponse.json(data, { status: res.status });
  }
  revalidatePath("/orders");
  if (!data.partially_unavailable) {
    revalidatePath("/cart");
  }
  return NextResponse.json(data, { status: 201 });
}
