"use client";

import { useState } from "react";
import { usePrototype } from "@/modules/ux-prototype/store";
import { canOperate, type Policy } from "@/modules/ux-prototype/model";
import { Area, Btn, Field, Foot, Header, Icon, Modal, useWorkspaceActions } from "./shared";
import "./finance-policy.css";

export function PoliciesPage({ role }: { role: "teacher" | "admin" | "student" }) {
  const { state, actor, dispatch } = usePrototype();
  const { notify } = useWorkspaceActions();
  const [editingId, setEditingId] = useState<string | null>(null);
  const admin = role === "admin";
  if (actor.role !== role || (admin && !canOperate(actor))) return <div className="v4-locked"><Icon name="shield"/><h1>這個視角不能編輯平台守則</h1><p>規章編輯需由平台負責人或營運管理員處理；財務權限不包含內容發布。</p></div>;
  const policies = state.policies.filter((policy) => admin || policy.audience === role);
  const editing = state.policies.find((policy) => policy.id === editingId);
  return <div className="ux-policies"><Header eyebrow="LEARN TOGETHER / 讓雙方都知道怎麼合作" title={admin ? "平台守則管理" : role === "teacher" ? "老師合作守則" : "學生學習守則"} sub="內容是待確認的規章提案，不是已生效的法律條款或退款承諾。"/>
    <p className="t-boundary">{admin ? "管理員編輯草稿、預覽再做「本頁發布」。更新版號後，先前的已讀不自動算成讀過新版本。正式契約需另行審核。" : "這裡會清楚告訴你上課方式、權益與需要注意的事。未核准的金額、期限及隱私條文不自行補成正式規定。"}</p>
    {policies.map((policy, index) => {
      const read = state.acknowledgements.some((ack) => ack.actorId === actor.id && ack.policyId === policy.id && ack.version === policy.version);
      return <section className="v4-policy" key={policy.id}><div className="v4-policy-head"><span className="v4-policy-number">{String(index + 1).padStart(2, "0")}</span><h2 style={{ margin: 0 }}>{policy.title}</h2><span className="v4-hold">{policy.audience === "student" ? "學生" : "老師"} · 示意 v{policy.version}</span></div><p>{policy.body}</p><div className="v4-inline-actions">{admin ? <><Btn onClick={() => setEditingId(policy.id)}>編輯規章草稿</Btn>{policy.draft && <span className="v4-hold">另有未發布草稿 v{policy.draft.version}</span>}</> : read ? <span className="v4-flag">本頁已讀 · 版本 {policy.version}</span> : <Btn onClick={() => { const result = dispatch({ type: "ackPolicy", policyId: policy.id }); notify(result.ok ? "已閱讀標記只留在本頁，並非正式簽署。" : result.error!); }}>我已閱讀這份示意守則</Btn>}</div></section>;
    })}
    {!admin && <p className="v4-light-note">本頁已讀紀錄只用來試走流程，不構成正式簽署；重新整理清除。</p>}<Foot/>
    {editing && <PolicyEditor key={editing.id} policy={editing} onClose={() => setEditingId(null)}/>}
  </div>;
}
function PolicyEditor({ policy, onClose }: { policy: Policy; onClose: () => void }) {
  const { dispatch } = usePrototype(); const { notify, confirm } = useWorkspaceActions();
  const draft = policy.draft ?? policy;
  const [title, setTitle] = useState(draft.title), [body, setBody] = useState(draft.body), [version, setVersion] = useState(draft.version === policy.version ? `0.${Number(policy.version.split(".")[1] || 1) + 1}` : draft.version), [reason, setReason] = useState("");
  const save = (publish: boolean) => {
    const result = dispatch({ type: "savePolicy", id: policy.id, title, body, version, reason });
    if (!result.ok) { notify(result.error!); return; }
    onClose();
    if (!publish) { notify("只保存規章草稿，學生與老師仍讀原版本。"); return; }
    confirm("預覽本頁規章更新", <><h3>{title}</h3><p style={{ whiteSpace: "pre-line" }}>{body}</p><p>版本 {policy.version} → {version}。既有已讀不會自動沿用；不是正式條款發布。</p><p>修訂理由：{reason}</p></>, () => { const published = dispatch({ type: "publishPolicy", id: policy.id, reason, confirmed: true }); notify(published.ok ? "本頁守則版本已更新，需重新閱讀。不構成正式契約。" : published.error!); return published.ok; });
  };
  return <Modal title="編輯守則草稿" onClose={onClose}><div className="ux-policy-editor"><Field label="標題" value={title} onChange={setTitle}/><Field label="新版本代稱" value={version} onChange={setVersion}/><Area label="條文草稿・未核准的期限與金額不要代填" value={body} onChange={setBody}/><Area label="修訂理由" value={reason} onChange={setReason}/><div className="v4-inline-actions"><Btn onClick={() => save(false)}>保存草稿</Btn><Btn primary onClick={() => save(true)}>預覽本頁發布</Btn></div><p className="dialog-note">正式法律／隱私／交易條款需另行專業審核。這裡只示範版本流程。</p></div></Modal>;
}
