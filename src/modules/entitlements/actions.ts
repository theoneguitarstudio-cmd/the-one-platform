"use server";

import "server-only";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { createServerSupabaseClient } from "@/lib/supabase/server";
import { requireAreaAccess } from "@/modules/auth/server-authorization";
import { adjustmentSchema, extensionSchema, fulfillmentRetrySchema } from "@/modules/entitlements/domain";

const read = (formData: FormData, key: string) => String(formData.get(key) ?? "");

export async function extendLessonPackage(formData: FormData) {
  const area = read(formData, "area") === "admin" ? "admin" : "teacher";
  await requireAreaAccess(area);
  const parsed = extensionSchema.safeParse({
    entitlementId: read(formData, "entitlementId"),
    idempotencyKey: read(formData, "idempotencyKey"),
    newExpiresAt: read(formData, "newExpiresAt"),
    reason: read(formData, "reason"),
  });
  if (!parsed.success) redirect(`/${area}/packages?error=invalid_extension`);
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("extend_lesson_package_entitlement", {
    p_entitlement_id: parsed.data.entitlementId,
    p_idempotency_key: parsed.data.idempotencyKey,
    p_new_expires_at: parsed.data.newExpiresAt,
    p_reason: parsed.data.reason,
  });
  if (error) redirect(`/${area}/packages?error=extension_failed`);
  revalidatePath(`/${area}/packages`);
  redirect(`/${area}/packages?status=extended`);
}

export async function adminAdjustLessonCredits(formData: FormData) {
  await requireAreaAccess("admin");
  const parsed = adjustmentSchema.safeParse({
    entitlementId: read(formData, "entitlementId"),
    idempotencyKey: read(formData, "idempotencyKey"),
    quantityDelta: read(formData, "quantityDelta"),
    reason: read(formData, "reason"),
  });
  if (!parsed.success) redirect("/admin/packages?error=invalid_adjustment");
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("admin_adjust_lesson_credits", {
    p_entitlement_id: parsed.data.entitlementId,
    p_idempotency_key: parsed.data.idempotencyKey,
    p_quantity_delta: parsed.data.quantityDelta,
    p_reason: parsed.data.reason,
  });
  if (error) redirect("/admin/packages?error=adjustment_failed");
  revalidatePath("/admin/packages");
  redirect("/admin/packages?status=adjusted");
}

export async function adminRetryFulfillment(formData: FormData) {
  await requireAreaAccess("admin");
  const parsed = fulfillmentRetrySchema.safeParse({ eventId: read(formData, "eventId") });
  if (!parsed.success) redirect("/admin/packages?error=invalid_event");
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.rpc("admin_process_order_fulfillment_event", {
    p_event_id: parsed.data.eventId,
  });
  if (error || data !== "processed") redirect("/admin/packages?error=fulfillment_failed");
  revalidatePath("/admin/packages");
  redirect("/admin/packages?status=processed");
}
