import Link from "next/link";
import { isMockDataMode } from "@/lib/preview/mode";
export function PreviewNotice() {
 if(!isMockDataMode()) return null;
 return <aside className="preview-notice" aria-label="Preview 說明"><span>PREVIEW · 示範資料，不收款、不儲存變更</span><Link href="/auth/sign-in">切換示範角色 ↗</Link></aside>;
}
