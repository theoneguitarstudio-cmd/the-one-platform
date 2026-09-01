import "server-only";
export type PaymentRequest={orderId:string;amount:number;currency:string;idempotencyKey:string};
export type VerifiedPaymentCallback={providerEventId:string;providerPaymentId:string;orderId:string;amount:number;currency:string;status:"paid"|"failed"};
export interface PaymentProvider {readonly name:string;createPayment(request:PaymentRequest):Promise<{providerPaymentId:string}>;verifyCallback(rawBody:string,headers:Headers):Promise<VerifiedPaymentCallback>;queryPayment(providerPaymentId:string):Promise<VerifiedPaymentCallback>;refund?(providerPaymentId:string,amount:number,idempotencyKey:string):Promise<{refundId:string}>;}
export function getWebhookProvider(name:string):PaymentProvider|null {void name;return null;}
