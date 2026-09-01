import "server-only";
import type {PaymentProvider,PaymentRequest} from "@/modules/payments/provider";
abstract class ManualProvider implements PaymentProvider {abstract readonly name:string;async createPayment(request:PaymentRequest){return {providerPaymentId:`${this.name}:${request.idempotencyKey}`};}async verifyCallback():Promise<never>{throw new Error("Manual payment providers do not accept webhooks.");}async queryPayment():Promise<never>{throw new Error("Manual payment status is controlled by an authorized review RPC.");}}
export class ManualBankTransferProvider extends ManualProvider {readonly name="manual_bank_transfer";}
export class ManualCashProvider extends ManualProvider {readonly name="manual_cash";}
