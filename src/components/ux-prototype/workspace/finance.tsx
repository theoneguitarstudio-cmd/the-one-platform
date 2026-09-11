"use client";

import { useState, type ReactNode } from "react";
import { usePrototype } from "@/modules/ux-prototype/store";
import { canFinance, visibleEarnings, type Command, type Earning, type FinanceDraft } from "@/modules/ux-prototype/model";
import { Area, Btn, Check, Empty, Field, Foot, Go, Header, Icon, Modal, Table, Tabs, money, statusName, useWorkspaceActions } from "./shared";
import "./finance-policy.css";

const kindLabels: Record<Earning["kind"], string> = { private: "一對一教學", creator: "會員內容創作", review: "Pro 影片指導", assessment: "正式評核", standalone: "單品課銷售", mentor: "陪跑／導師服務" };
const kindCopy: Record<Earning["kind"], string> = {
  private: "按已完成／合約允許計費的課次，對照購課時的分潤版本。", creator: "平台訂閱淨額 → 可配置池 → 合格內容與創作者歸屬 → 結算。",
  review: "依已核對指導服務與報酬版本，不併進內容創作池。", assessment: "獨立評核服務與補償；目前只是未來類別。",
  standalone: "對應單品訂單、退款及受益人合約，不自動平均分帳。", mentor: "未來陪跑服務單獨設定，不混入 Pro 批改。",
};
const isConfirmed = (earning: Earning) => ["ready", "approved", "paid"].includes(earning.status);
const sum = (rows: { amount: number | null }[]) => rows.reduce((total, row) => total + (row.amount ?? 0), 0);
type FinanceDialog = { kind: "detail" | "inquiry"; id: string } | { kind: "settlement"; teacherId: string } | { kind: "rule"; category: Earning["kind"] } | { kind: "draft"; id: string };

function Fact({ label, value, description }: { label: string; value: ReactNode; description?: string }) {
  return <div className="v4-fact"><span>{label}{description && <small>{description}</small>}</span><b>{value}</b></div>;
}
function Stat({ label, amount, description }: { label: string; amount: number | null; description: string }) {
  return <div className="v4-stat"><label>{label}</label><strong>{amount === null ? <span className="v4-empty-amount">待確認</span> : <><span className="currency">NT$</span>{amount.toLocaleString("en-US")}</>}</strong><small>{description}</small></div>;
}
function EarningRows({ rows, admin, onDetail }: { rows: Earning[]; admin: boolean; onDetail: (id: string) => void }) {
  const { state } = usePrototype();
  return <Table headers={[admin ? "來源／老師" : "收入來源", "對應紀錄／規則版本", admin ? "金額" : "我的金額", "處理狀態", "操作"]}>{rows.length ? rows.map((earning) => <tr key={earning.id}>
    <td><strong>{kindLabels[earning.kind]}</strong><small>{earning.title}</small>{admin && <small>{state.teachers.find((teacher) => teacher.id === earning.teacherId)?.draft.name ?? "老師"}</small>}</td>
    <td>{earning.reference}<small>{earning.rule}</small></td><td className="num">{earning.amount === null ? "待核准" : money(earning.amount)}{earning.status === "review" && <small>不列入已確認應付</small>}</td>
    <td><span className={isConfirmed(earning) ? "v4-flag" : "v4-hold"}>{statusName(earning.status)}</span>{earning.paidAt && <small>{earning.paidAt}</small>}</td><td><Btn onClick={() => onDetail(earning.id)}>看明細</Btn></td>
  </tr>) : <tr><td colSpan={5}>目前沒有這個條件的紀錄。</td></tr>}</Table>;
}

export function FinancePage({ role }: { role: "teacher" | "admin" }) {
  const { state, actor, dispatch } = usePrototype();
  const { notify } = useWorkspaceActions();
  const [month, setMonth] = useState("2026-09");
  const [tab, setTab] = useState("overview");
  const [kind, setKind] = useState("all");
  const [dialog, setDialog] = useState<FinanceDialog | null>(null);
  if (role === "admin" ? !canFinance(actor) : actor.role !== "teacher") return <div className="v4-locked"><Icon name="shield"/><h1>這個帳號沒有財務檢視權限</h1><p>營運管理員可以協助排課與處理內容，但不預設看全站收款、老師報酬或撥款資料。平台負責人與財務視角才能查看。</p><p className="micro">這是本機權限介面示意，不是正式登入；頁面內都是虛構資料。</p></div>;
  const own = visibleEarnings(state, actor), rows = own.filter((earning) => earning.month === month), confirmed = rows.filter(isConfirmed);
  const events = state.cashEvents.filter((event) => event.date.startsWith(month));
  const gross = sum(events.filter((event) => event.kind === "receipt")), refunded = sum(events.filter((event) => event.kind === "refund")), fees = sum(events.filter((event) => event.kind === "fee"));
  const paid = sum(own.filter((earning) => earning.status === "paid" && earning.paidAt?.startsWith(month))), pending = sum(confirmed.filter((earning) => earning.status !== "paid"));
  const openDetail = (id: string) => setDialog({ kind: "detail", id });
  const run = (command: Command, message: string) => { const result = dispatch(command); notify(result.ok ? message : result.error ?? "未變更資料。"); return result.ok; };
  const period = <select aria-label="檢視月份" value={month} onChange={(event) => setMonth(event.target.value)}><option value="2026-09">2026 年 9 月 · 示意</option><option value="2026-08">2026 年 8 月 · 示意</option></select>;
  return <div className="ux-finance">
    <Header eyebrow={role === "teacher" ? "YOUR EARNINGS / 每一份教學，都有清楚的紀錄" : "MONEY, WITH CONTEXT / 看得到錢，也看得到去向"} title={role === "teacher" ? "我的收入" : "平台財務"} sub={role === "teacher" ? "只顯示自己的報酬；學生先買了幾堂，不等於老師已賺到幾堂。" : "先看收款，再看已交付、應付老師與尚未分配的部分。不要把現金餘額當成淨利。"}/>
    <div className="v4-toolbar">{role === "teacher" ? <p className="muted small">教學期間與實際撥款日期分開記錄</p> : <Tabs items={[["overview", "收支總覽"], ["settlements", "老師結算"], ["rules", "分潤設定"]]} value={tab} onChange={setTab}/>} {period}</div>
    {role === "teacher" ? <>
      <div className="v4-stats"><Stat label="本期已確認報酬" amount={sum(confirmed)} description="依已核對的合約快照與服務紀錄；示意，不是既定分潤公式。"/><Stat label="本期報酬尚待撥款" amount={pending} description="已確認但還沒有付款憑證的金額。"/><Stat label="本月實際撥款記錄" amount={paid} description="依撥款日期統計；不等於當月新賺的報酬。"/></div>
      <div className="v4-toolbar"><h2>收入明細</h2><select aria-label="收入分類" value={kind} onChange={(event) => setKind(event.target.value)}><option value="all">全部收入來源</option>{Object.entries(kindLabels).map(([key, label]) => <option key={key} value={key}>{label}</option>)}</select></div>
      <EarningRows rows={rows.filter((earning) => kind === "all" || earning.kind === kind)} admin={false} onDetail={openDetail}/>
      <section className="section v4-grid"><div className="v4-box"><h3>會員內容分潤，先保留待確認。</h3><p>平台訂閱不是某位老師的方案。內容創作與 Pro 批改分開計算，未核准的歸屬規則不先填成 0 元，也不平均分給老師。</p></div><div className="v4-box"><h3>對金額有疑問？</h3><p>從每一筆明細提出查詢，讓平台對照課次、合約版本與調整原因。不讓老師直接修改已結算報酬。</p><div className="v4-inline-actions"><Go to="teacher/policies">查看合作與收入守則</Go></div></div></section>
      <p className="t-boundary">評核、導師等報酬類別保留未來擴充；此處不代表服務已上架。剩餘堂數、已預約、完成上課、已確認報酬與已撥款都是不同狀態。</p>
    </> : tab === "overview" ? <>
      <div className="v4-stats"><Stat label="本月已收款" amount={gross} description="依已收款日期；不含待付款訂單，也不含人工贈課。"/><Stat label="扣除已退款後收款" amount={gross - refunded} description="只扣已完成退款；尚待退款的申請不重複扣款。"/><Stat label="已確認待撥老師款" amount={pending} description="與未完成課程包、待核對報酬及內容池分開。"/></div>
      <div className="v4-grid"><section className="v4-box"><h2>這筆錢，現在在哪裡？</h2><Fact label="已收款" value={money(gross)}/><Fact label="已完成退款" value={`− ${money(refunded)}`}/><Fact label="已確認金流費用" value={`− ${money(fees)}`} description="不是固定手續費比例；此處為已入帳示意費用。"/><Fact label="本月已撥老師款" value={`− ${money(paid)}`}/><Fact label="以上示意交易現金差額" value={money(gross - refunded - fees - paid)} description="未含期初餘額、稅金及其他成本，不是銀行餘額，也不是可全部提走的利潤。"/></section>
      <section className="v4-box"><h2>不是每一元都已經賺到。</h2><Fact label="平台正式收入／淨利" value="待核對" description="尚未確認履約認列、代理或自營呈現、創作分潤與完整營運成本。"/><Fact label="尚有未完成服務的款項" value="獨立追蹤" description="一對一未上堂數、訂閱剩餘服務期與退款保留，不能直接併進利潤。"/><Fact label="未核准／待核對的報酬" value={`${rows.filter((earning) => !isConfirmed(earning)).length} 筆`} description="含會員創作歸屬與待核對指導，不列為 0 元。"/><p style={{ marginTop: 15 }}>看現金流與看獲利，是兩個問題。正式報表的認列方法需另由會計專業核對，本頁只示範管理資訊怎麼分開。</p></section></div>
      <section className="section"><div className="section-head"><h2>收支來源</h2><span className="micro">單位：新台幣 · 全部為 fixture 示意紀錄</span></div><Table headers={["日期", "來源", "狀態", "金額"]}>{events.length ? events.map((event) => <tr key={event.id}><td>{event.date}</td><td><strong>{event.title}</strong><small>{event.reference}</small></td><td>{event.kind === "receipt" ? "已收款" : event.kind === "refund" ? "已退款" : "費用已確認"}</td><td className="num">{event.kind === "receipt" ? "" : "− "}{money(event.amount)}</td></tr>) : <tr><td colSpan={4}>本期沒有示意收支紀錄。</td></tr>}</Table></section>
      <section className="section"><div className="section-head"><h2>已確認的老師報酬</h2><Btn onClick={() => setTab("settlements")}>處理結算</Btn></div><EarningRows rows={confirmed} admin onDetail={openDetail}/></section>
    </> : tab === "settlements" ? <>
      <div className="v4-alert">先核對服務 → 財務準備 → 負責人覆核 → 另行轉帳 → 登記憑證。本 Demo 不連銀行；「已撥款」必須用明確的示意憑證標記，不是一按就假裝匯出。</div>
      <div className="v4-grid">{state.teachers.filter((teacher) => own.some((earning) => earning.teacherId === teacher.id)).map((teacher) => {
        const list = confirmed.filter((earning) => earning.teacherId === teacher.id), unpaid = list.filter((earning) => earning.status !== "paid"), batch = state.settlements.find((settlement) => settlement.teacherId === teacher.id && settlement.month === month && settlement.status !== "paid");
        return <section className="v4-box" key={teacher.id}><span className="eyebrow">{month} / TEACHER STATEMENT</span><h2 style={{ margin: "12px 0" }}>{teacher.draft.name}</h2><Fact label="已確認報酬" value={money(sum(list))}/><Fact label="本期尚待撥款" value={money(sum(unpaid))}/><Fact label="狀態" value={batch ? statusName(batch.status) : unpaid.length ? "待核對" : "已完成／無待辦"}/><div className="v4-inline-actions">{unpaid.length > 0 && <Btn primary onClick={() => setDialog({ kind: "settlement", teacherId: teacher.id })}>核對結算單</Btn>}</div></section>;
      })}</div><section className="section"><h2>全部報酬狀態</h2><p className="subtitle" style={{ marginBottom: 18 }}>待核對及未定規則不會混入可撥款金額。</p><EarningRows rows={rows} admin onDetail={openDetail}/></section>
    </> : <>
      <div className="v4-band"><div><span className="eyebrow">POLICY IS NOT A GUESS</span><h2>報酬分開設定，不用一條公式算全部。</h2><p>以下是設計提案與草稿試算，正式百分比、扣費基礎、歸屬權重及生效條件尚未核准。</p></div><span className="v4-flag">未啟用正式結算規則</span></div>
      <div className="v4-grid three">{(Object.keys(kindLabels) as Earning["kind"][]).map((category) => <section className="v4-box" key={category}><h3>{kindLabels[category]}</h3><p>{kindCopy[category]}</p><div className="v4-inline-actions"><Btn onClick={() => setDialog({ kind: "rule", category })}>查看設定提案</Btn></div></section>)}</div>
      <section className="section"><h2>本頁保存的規則草稿</h2>{state.financeDrafts.length ? <div className="v4-list">{state.financeDrafts.map((draft, index) => <article key={draft.id}><span className="v4-hold">草稿 {index + 1}</span><div className="grow"><h3>{kindLabels[draft.kind]} · {draft.name}</h3><p>適用：{draft.scope} · 預計生效：{draft.effective}<br/>尚未啟用、不追溯既有報酬。</p></div><Btn onClick={() => setDialog({ kind: "draft", id: draft.id })}>查看草稿</Btn></article>)}</div> : <Empty title="還沒有設定草稿">沒有預填分潤比例，不會以老師數量或純觀看量直接算錢。</Empty>}</section>
    </>}
    <Foot/>
    {dialog?.kind === "detail" && (() => { const earning = own.find((item) => item.id === dialog.id); return earning ? <Modal key={`detail-${earning.id}`} title={`報酬明細 · ${earning.id}`} onClose={() => setDialog(null)}><div className="v4-rule-state"><span className="v4-flag">{statusName(earning.status)}</span></div><h3>{earning.title}</h3><Fact label="我的／該老師的金額" value={earning.amount === null ? "規則待核准" : money(earning.amount)}/><Fact label="教學／歸屬期間" value={earning.month}/><Fact label="對應原始紀錄" value={earning.reference}/><Fact label="採用的規則版本" value={earning.rule}/><Fact label="撥款日期" value={earning.paidAt ?? "尚未撥款"}/><Fact label="憑證" value={earning.proof ?? "尚無"}/><p className="dialog-note">金額為人工匯入的示意結算行，不是從售價反推的正式分潤比。不能直接改歷史金額；有疑問可提出查詢。</p><Btn onClick={() => setDialog({ kind: "inquiry", id: earning.id })}>對這筆金額提出查詢</Btn></Modal> : null; })()}
    {dialog?.kind === "inquiry" && <InquiryDialog earningId={dialog.id} onClose={() => setDialog(null)} run={run}/>}
    {dialog?.kind === "settlement" && <SettlementDialog teacherId={dialog.teacherId} month={month} onClose={() => setDialog(null)}/>}
    {dialog?.kind === "rule" && <RuleDialog category={dialog.category} onClose={() => setDialog(null)} run={run}/>}
    {dialog?.kind === "draft" && (() => { const draft = state.financeDrafts.find((item) => item.id === dialog.id); return draft ? <DraftDialog draft={draft} onClose={() => setDialog(null)}/> : null; })()}
  </div>;
}

function InquiryDialog({ earningId, onClose, run }: { earningId: string; onClose: () => void; run: (command: Command, message: string) => boolean }) {
  const [reason, setReason] = useState("");
  return <Modal title="報酬查詢" onClose={onClose}><p className="x-copy">指定紀錄：{earningId}。這不會直接改金額或取消撥款。</p><Area label="想請平台核對什麼？" value={reason} onChange={setReason}/><Btn primary onClick={() => { if (run({ type: "earningInquiry", earningId, reason }, "查詢已留在本頁操作紀錄。沒有寄信或修改金額。")) onClose(); }}>儲存本頁查詢</Btn></Modal>;
}
function SettlementDialog({ teacherId, month, onClose }: { teacherId: string; month: string; onClose: () => void }) {
  const { state, actor, dispatch } = usePrototype(); const { notify, confirm } = useWorkspaceActions();
  const [reason, setReason] = useState(""), [proof, setProof] = useState(""), [checked, setChecked] = useState(false);
  const teacher = state.teachers.find((item) => item.id === teacherId);
  const batch = state.settlements.find((item) => item.teacherId === teacherId && item.month === month && item.status !== "paid");
  const rows = visibleEarnings(state, actor).filter((earning) => earning.teacherId === teacherId && earning.month === month && isConfirmed(earning) && earning.status !== "paid");
  const approved = batch?.status === "approved";
  const submit = () => {
    if (!checked || reason.trim().length < 3) { notify("請填原因並確認已核對紀錄。"); return; }
    if (approved) {
      if (!/^DEMO-[A-Za-z0-9-]{3,60}$/.test(proof)) { notify("請使用 DEMO- 開頭的虛構憑證。"); return; }
      onClose(); confirm("登記本頁的示意已撥款", <><p>金額：{money(batch.total)}</p><p>憑證：{proof}</p><p>沒有連銀行，也不會真的轉帳。只示範人工對帳後登記。</p></>, () => { const result = dispatch({ type: "recordPayout", id: batch.id, proof, reason, confirmed: true }); notify(result.ok ? "只更新本頁撥款記錄；沒有移動真實資金。" : result.error!); return result.ok; }); return;
    }
    let settlementId = batch?.id;
    if (!settlementId) { const result = dispatch({ type: "prepareSettlement", teacherId, month, reason }); if (!result.ok) { notify(result.error!); return; } settlementId = result.id!; }
    if (actor.capability !== "owner") { notify("已記下準備工作，請由平台負責人覆核；尚未撥款。"); onClose(); return; }
    const id = settlementId;
    onClose(); confirm("負責人覆核結算", <><p>{teacher?.draft.name} · {money(sum(rows))}</p><p>這一步只標記覆核完成，不等於匯款。</p><p>原因：{reason}</p></>, () => { const result = dispatch({ type: "approveSettlement", id, reason, confirmed: true }); notify(result.ok ? "示意覆核完成。仍需另行登記撥款憑證。" : result.error!); return result.ok; });
  };
  return <Modal title="核對老師結算單" onClose={onClose}><h3>{teacher?.draft.name}</h3><Fact label="本期結算期間" value={month}/><Fact label="本次待撥總額" value={money(sum(rows))}/>{rows.map((earning) => <Fact key={earning.id} label={`${kindLabels[earning.kind]} · ${earning.id}`} value={money(earning.amount)}/>)}<p className="dialog-note">只包含已確認的待付款報酬。待核對與未定歸屬不會塞進本次結算。正式銀行帳號與憑證不在 Demo 收集。</p>{approved && <Field label="示意轉帳憑證代稱（請用 DEMO- 開頭）" value={proof} onChange={setProof} placeholder="DEMO-TRANSFER-009"/>}<Area label="核對／記錄原因（必填）" value={reason} onChange={setReason}/><Check label={approved ? "確認本次只登記虛構憑證，不執行真實轉帳" : "已核對本次服務紀錄及合約版本"} checked={checked} onChange={setChecked}/><div className="v4-inline-actions"><Btn primary onClick={submit}>{approved ? "登記示意已撥款" : actor.capability === "owner" ? "負責人覆核這份結算" : "準備並交負責人覆核"}</Btn></div></Modal>;
}
function RuleDialog({ category, onClose, run }: { category: Earning["kind"]; onClose: () => void; run: (command: Command, message: string) => boolean }) {
  const [name, setName] = useState(""), [scope, setScope] = useState(""), [effective, setEffective] = useState("2026-10-01"), [base, setBase] = useState(""), [reason, setReason] = useState("");
  const [allocationStrings, setAllocations] = useState<string[]>(category === "creator" ? ["", "", ""] : ["", ""]);
  const { notify } = useWorkspaceActions();
  const labels = category === "creator" ? ["內容創作池假設", "指導服務池假設", "其他保留假設"] : ["老師報酬假設・不是已核准標準", "此例平台負擔費用假設"];
  const full = base.trim() !== "" && allocationStrings.every((value) => value.trim() !== "");
  const remaining = Number(base) - allocationStrings.reduce((total, value) => total + Number(value), 0);
  return <Modal title={`報酬規則草稿 · ${kindLabels[category]}`} onClose={onClose}><p className="x-copy">不預填正式比例。填入假設後才能試算；保存仍是待核准草稿，不會改現有金額。</p><Field label="草稿名稱／版本" value={name} onChange={setName} placeholder="例如：秋季合作條件提案"/><Field label="適用合約／商品範圍" value={scope} onChange={setScope} placeholder="指定老師、課程或合約版本，不自動套用全站"/><Field label="預計生效日" value={effective} onChange={setEffective} type="date"/><Field label={category === "creator" ? "本期可分配淨額假設" : "這筆服務／商品的可分配基礎假設"} value={base} onChange={setBase} type="number"/>{labels.map((label, index) => <Field key={label} label={label} value={allocationStrings[index]} onChange={(value) => setAllocations(allocationStrings.map((old, itemIndex) => itemIndex === index ? value : old))} type="number"/>)}<div className="v4-alert" aria-live="polite">{full ? remaining < 0 ? "分配已超過基礎，請調整假設。" : `未分配餘額：${money(remaining)}（不稱為淨利）` : "填完這組假設後，會顯示未分配餘額；不叫淨利。"}</div><Area label="理由／歸屬依據" value={reason} onChange={setReason}/><Btn primary onClick={() => { if (!full) { notify("請填完本組假設，不能用空值代表 0。"); return; } if (run({ type: "saveFinanceDraft", name, scope, kind: category, effective, base: Number(base), allocations: allocationStrings.map(Number), reason }, "已保存待核准草稿；沒有啟用或重算任何收入。")) onClose(); }}>保存待核准草稿</Btn><p className="dialog-note">舊合約、舊課程包與已結算報酬不改。不得按老師人數平均或純觀看量分配。稅與正式會計處理另外確認。</p></Modal>;
}
function DraftDialog({ draft, onClose }: { draft: FinanceDraft; onClose: () => void }) {
  return <Modal title="待核准規則草稿" onClose={onClose}><h3>{draft.name}</h3><p className="x-copy">適用：{draft.scope}<br/>預計：{draft.effective}<br/>理由：{draft.reason}</p><Fact label="可分配基礎假設" value={money(draft.base)}/>{draft.allocations.map((amount, index) => <Fact key={index} label={`分配假設 ${index + 1}`} value={money(amount)}/>)}<Fact label="未分配餘額" value={money(draft.unallocated)}/><p className="dialog-note">未啟用，舊資料不受影響。</p></Modal>;
}
