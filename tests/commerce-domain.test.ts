import {describe,expect,it} from "vitest";
import {bankTransferSchema,checkoutSchema,formatMoney} from "@/modules/commerce/domain";
describe("commerce domain validation",()=>{
  it("accepts a bounded checkout",()=>expect(checkoutSchema.safeParse({productSlug:"lesson-pack",quantity:2,idempotencyKey:"11111111-1111-4111-8111-111111111111"}).success).toBe(true));
  it("rejects zero quantity",()=>expect(checkoutSchema.safeParse({productSlug:"lesson-pack",quantity:0,idempotencyKey:"11111111-1111-4111-8111-111111111111"}).success).toBe(false));
  it("rejects malformed slugs",()=>expect(checkoutSchema.safeParse({productSlug:"../private",quantity:1,idempotencyKey:"11111111-1111-4111-8111-111111111111"}).success).toBe(false));
  it("requires exactly five transfer digits",()=>expect(bankTransferSchema.safeParse({orderId:"11111111-1111-4111-8111-111111111111",idempotencyKey:"22222222-2222-4222-8222-222222222222",payerName:"Buyer",transferLast5:"1234",note:""}).success).toBe(false));
  it("formats integer TWD",()=>expect(formatMoney(3200,"TWD")).toContain("3,200"));
});
