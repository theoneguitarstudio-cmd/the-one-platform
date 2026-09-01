import "server-only";
export function getBankTransferInstructions(){return process.env.MANUAL_BANK_TRANSFER_INSTRUCTIONS?.trim()||"請聯絡客服取得本次訂單的轉帳資訊。";}
