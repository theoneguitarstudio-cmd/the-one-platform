import { z } from "zod";

export const checkoutSchema = z.object({
  idempotencyKey: z.uuid(),
  productSlug: z.string().regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/).max(100),
  quantity: z.coerce.number().int().min(1).max(100),
});
export const orderIdSchema = z.uuid();
export const bankTransferSchema = z.object({
  idempotencyKey: z.uuid(), orderId: z.uuid(), payerName: z.string().trim().min(1).max(100),
  transferLast5: z.string().regex(/^\d{5}$/), note: z.string().trim().max(500),
});
export const adminPaymentSchema = z.object({orderId:z.uuid(),paymentId:z.uuid(),reason:z.string().trim().min(3).max(1000)});
export const adminOrderSchema = z.object({orderId:z.uuid(),reason:z.string().trim().min(3).max(1000)});
export const cashPaymentSchema = z.object({orderId:z.uuid(),idempotencyKey:z.uuid(),reason:z.string().trim().min(3).max(1000)});

export function formatMoney(amount: number, currency: string) {
  return new Intl.NumberFormat("zh-TW", { style: "currency", currency, maximumFractionDigits: 0 }).format(amount);
}
