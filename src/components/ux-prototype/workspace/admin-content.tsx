"use client";

import Link from "@/components/platform-experience/link";
import { useRouter } from "@/components/platform-experience/link";
import { useEffect, useState, type ReactNode } from "react";
import { canOperate, type Article, type ArticleContent, type Command, type Course, type CourseContent, type CoursePolicy, type OfferContent, type Proposal, type TeacherProfile } from "@/modules/ux-prototype/model";
import { usePrototype } from "@/modules/ux-prototype/store";
import { Area, base, Btn, Check, Empty, Field, Flag, Foot, Go, Header, Icon, Modal, money, Select, statusName, Table, useWorkspaceActions } from "./shared";
import "./admin-content.css";

const kindName = (kind: string) => kind === "system" ? "系統課程" : "單品課";
function Note({ children }: { children: ReactNode }) { return <div className="x-note"><Icon name="shield"/><p>{children}</p></div>; }
function ContentPreview({ content }: { content: CourseContent }) { return <div className="ux-content-preview"><h2>{content.title}</h2><p>{content.summary}</p><p><b>學習目標</b><br/>{content.objective}</p><p className="t-prewrap">{content.outline}</p><p>{kindName(content.kind)} · {content.billing === "membership" ? "平台會員目錄" : `單次購買 ${money(content.price)}`}</p><p>教材來源：{content.resourceName || "尚未填寫"}</p></div>; }
function ArticlePreview({ content }: { content: ArticleContent }) { return <article className="x-article-preview"><Flag>{content.category}</Flag><h1>{content.title}</h1><p className="x-copy">{content.summary}</p><div className="x-article-cover">THE ONE / LEARNING JOURNAL</div><div className="x-article-body">{content.body}</div></article>; }

export function AdminContentPage({ segments }: { segments: string[] }) {
  const { actor } = usePrototype();
  if (!canOperate(actor)) return <div className="v4-locked"><Icon name="shield"/><h1>這個視角只處理財務</h1><p>發布課程、文章與師資展示需要平台負責人或營運管理員權限。財務能力不包含教學內容管理。</p></div>;
  if (segments[0] === "courses") return segments[1] ? <CourseEditor key={segments[1]} id={segments[1]}/> : <Courses/>;
  if (segments[0] === "review") return <ReviewDesk/>;
  if (segments[0] === "articles") return segments[1] ? <ArticleEditor key={segments[1]} id={segments[1]}/> : <Articles/>;
  return <Empty title="請選擇內容工作區"><Go to="admin/courses">課程管理</Go></Empty>;
}

function Courses() {
  const { state, dispatch } = usePrototype();
  const { notify } = useWorkspaceActions();
  const router = useRouter();
  const [createdId, setCreatedId] = useState<string | null>(null);
  useEffect(() => { if (createdId) router.push(`${base}/admin/courses/${createdId}`); }, [createdId, router]);
  const create = () => { const result = dispatch({ type: "createCourse" }); if (result.ok && result.id) setCreatedId(result.id); else notify(result.error!); };
  return <><Header eyebrow="COURSE MANAGEMENT / 平台掌握正式版本" title="課程管理" sub="管理員新增、編輯及發布正式課程。老師提案是另一個工作區。" tools={<Btn primary onClick={create}>＋ 新增正式課程草稿</Btn>}/><div className="v4-toolbar"><p className="muted small">草稿修改不影響已發布版本。</p><Go to="admin/review">審核老師提案</Go></div><Table headers={["課程", "內容類型／收費方式", "草稿與公開版", "操作"]}>{state.courses.map(course => <tr key={course.id}><td><strong>{course.draft.title}</strong><small>{state.teachers.find(teacher => teacher.id === course.teacherId)?.draft.name || "平台內容"} · 作者不等於收入所有人</small></td><td>{kindName(course.draft.kind)}<small>{course.draft.billing === "membership" ? "會員目錄" : "單次購買"}</small></td><td>{course.published ? `公開 v${course.revision}` : "尚未發布"}<small>{course.status === "published" ? "與目前公開版一致" : "另有編輯草稿"}</small></td><td><Go primary to={`admin/courses/${course.id}`}>編輯課程</Go></td></tr>)}</Table><Note>平台管理課程不等於可以不留記錄地改錢。內容版本、商品價格、會員權益與創作者結算分開；這裡沒有訂閱升級、授權或金流操作。</Note><Foot/></>;
}

function CourseEditor({ id }: { id: string }) {
  const { state } = usePrototype();
  const course = state.courses.find(item => item.id === id);
  return course ? <CourseForm key={course.id} course={course}/> : <Empty title="尚未選擇課程">請從<Go to="admin/courses">課程管理</Go>選擇一個草稿。</Empty>;
}
function CourseForm({ course }: { course: Course }) {
  const { state, dispatch } = usePrototype();
  const { notify, confirm } = useWorkspaceActions();
  const router = useRouter();
  const [content, setContent] = useState(course.draft);
  const [policy, setPolicy] = useState<CoursePolicy>(course.draftPolicy);
  const [reason, setReason] = useState("");
  const [error, setError] = useState("");
  const update = <K extends keyof CourseContent>(key: K, value: CourseContent[K]) => setContent(previous => ({ ...previous, [key]: value }));
  const save = (preview: boolean) => {
    const result = dispatch({ type: "saveCourse", id: course.id, content, policy, reason });
    if (!result.ok) { setError(result.error!); return; }
    setError("");
    if (!preview) { notify("已保存本頁草稿；訪客仍看原本的公開版本。"); return; }
    const expectedRevision = course.draftRevision + 1;
    const snapshot = structuredClone(content), proposedPolicy = structuredClone(policy);
    confirm("發布前，確認這次版本", <><ContentPreview content={snapshot}/><div className="v4-alert">將發布為 v{course.revision + 1} · 工作草稿 {expectedRevision}<br/>納入會員目錄：{proposedPolicy.included ? "是" : "否"} · Plus 存取：{proposedPolicy.plusAccess ? "是" : "否"} · Pro 指導：{proposedPolicy.proReview ? "是" : "否"}</div><p>原因：{reason}</p><p>不更新既有交易、已購價格或學生進度。只更新本機示意公開頁。</p></>, () => {
      const result = dispatch({ type: "publishCourse", id: course.id, expectedRevision, reason, confirmed: true });
      notify(result.ok ? "本機公開版本已更新；沒有發布到正式網站。" : result.error!);
      if (result.ok) router.push(`${base}/admin/courses`);
      return result.ok;
    });
  };
  return <><Header eyebrow="OFFICIAL COURSE STUDIO / 只有平台能發布" title="編輯課程草稿" sub="保存只改草稿，發布需要另行預覽與確認。" tools={<Go to="admin/courses">回課程管理</Go>}/><div className="v4-editor"><section>{course.proposalId && <div className="v4-alert">由提案 {course.proposalId} 匯入。請核對內容再發布，審核通過不等於已上架。</div>}<div className="v4-steps"><span>公開版本 {course.published ? `v${course.revision}` : "尚無"}</span><span className="now">工作草稿 {course.draftRevision}</span></div><Field label="正式課程名稱" value={content.title} onChange={value => update("title", value)}/><Select label="內容類型" value={content.kind} options={[["system", "系統課程"], ["standalone", "單品課"]]} onChange={value => update("kind", value as CourseContent["kind"])}/><Area label="課程介紹" value={content.summary} onChange={value => update("summary", value)}/><Area label="學習目標" value={content.objective} onChange={value => update("objective", value)}/><div className="ux-content-long"><Area label="章節與單元・一行一個" value={content.outline} onChange={value => update("outline", value)}/></div><Field label="課程作者・不變更收入所有人" value={state.teachers.find(teacher => teacher.id === course.teacherId)?.draft.name || "平台內容"}/><Field label="教材版本或來源參照" value={content.resourceName} onChange={value => update("resourceName", value)}/><Area label="編輯原因（必填）" value={reason} onChange={setReason}/>{error && <p role="alert" className="v4-alert">{error}</p>}<div className="v4-inline-actions"><Btn onClick={() => save(false)}>儲存草稿</Btn><Btn primary onClick={() => save(true)}>預覽待發布版本</Btn></div></section><aside className="v4-guide"><h3>上架與存取設定</h3><p>收費方式與課程類型分開；更動此處不會直接授予學生資格。</p><Select label="收費／存取方式" value={content.billing} options={[["membership", "平台會員目錄"], ["one_time", "單次購買"]]} onChange={value => update("billing", value as CourseContent["billing"])}/><Field label="單品展示售價・不是會員費" type="number" value={content.price ?? ""} onChange={value => update("price", value === "" ? null : Number(value))}/><Check label="納入會員目錄" checked={policy.included} onChange={value => setPolicy({ ...policy, included: value })}/><Check label="合格 Plus 可學習" checked={policy.plusAccess} onChange={value => setPolicy({ ...policy, plusAccess: value })}/><Check label="本課支援 Pro 影片指導" checked={policy.proReview} onChange={value => setPolicy({ ...policy, proReview: value })}/><p>若改變已銷售的存取承諾，正式實作須另做影響檢查。此處只更新示意目錄，不追溯撤銷舊生權益。</p>{course.published && <Link className="btn secondary" href={`${base}/courses/${course.id === "c1" ? "guitar-roadmap" : course.id}`}>檢查目前公開版本</Link>}</aside></div><Foot/></>;
}

type ReviewTarget = { kind: "proposal" | "profile" | "offer" | "article"; id: string };
function ReviewDesk() {
  const { state } = usePrototype();
  const [selected, setSelected] = useState<ReviewTarget | null>(null);
  const [featuredTeacher, setFeaturedTeacher] = useState<string | null>(null);
  const proposals = state.proposals.filter(proposal => proposal.status === "review");
  const other = [
    ...state.teachers.filter(teacher => teacher.reviewSnapshot).map(teacher => ({ kind: "profile" as const, id: teacher.id, title: teacher.reviewSnapshot!.name, label: "老師展示頁" })),
    ...state.offers.filter(offer => offer.reviewSnapshot).map(offer => ({ kind: "offer" as const, id: offer.id, title: offer.reviewSnapshot!.title, label: "一對一課程包" })),
    ...state.articles.filter(article => article.status === "review" && article.reviewSnapshot).map(article => ({ kind: "article" as const, id: article.id, title: article.reviewSnapshot!.title, label: "文章" })),
  ];
  return <><Header eyebrow="REVIEW DESK / 先審核，再交給平台編輯" title="提案與上架審核" sub="課程提案核准後只匯入草稿，不會直接對學生發布。" tools={<Go to="admin/courses">前往正式課程管理</Go>}/><section><div className="section-head"><h2>老師課程提案</h2><span className="micro">{proposals.length} 筆等待審核</span></div>{proposals.length ? <div className="v4-list">{proposals.map(proposal => <article key={proposal.id}><Flag active>提案 v{proposal.revision}</Flag><div className="grow"><h3>{proposal.snapshot!.content.title}</h3><p>{proposal.baseCourseId ? `更新既有課程，原版 v${proposal.baseRevision}` : "新課程建議"} · {proposal.snapshot!.content.objective}</p></div><Btn primary onClick={() => setSelected({ kind: "proposal", id: proposal.id })}>審核提案</Btn></article>)}</div> : <Empty title="沒有新的課程提案">老師完成守則確認與送審後才會出現在這裡。</Empty>}</section><section className="section"><h2>其他上架申請</h2><p className="subtitle">展示頁、課程包與文章沿用原本的草稿審核流程。</p>{other.length ? <div className="v4-list">{other.map(item => <article key={`${item.kind}-${item.id}`}><Flag>{item.label}</Flag><div className="grow"><h3>{item.title}</h3></div><Btn onClick={() => setSelected(item)}>檢視並審核</Btn></article>)}</div> : <Empty title="沒有其他待審內容">原本的公開版本不受待審草稿影響。</Empty>}</section>{state.teachers.filter(teacher => teacher.published).map(teacher => <section key={teacher.id} className="section v4-box"><div className="row between wrap"><div><h3>{teacher.published!.name} · 訪客首頁展示</h3><p>只推薦已審核且有公開一對一課程包的老師介紹頁。</p></div><Btn onClick={() => setFeaturedTeacher(teacher.id)}>{teacher.featured ? "移出首頁推薦" : "放入首頁推薦"}</Btn></div></section>)}<Foot/>{selected && <ReviewDialog key={`${selected.kind}-${selected.id}`} target={selected} onClose={() => setSelected(null)}/>} {featuredTeacher && <FeaturedDialog id={featuredTeacher} onClose={() => setFeaturedTeacher(null)}/>}</>;
}

function ReviewDialog({ target, onClose }: { target: ReviewTarget; onClose: () => void }) {
  const { state, dispatch } = usePrototype();
  const { notify, confirm } = useWorkspaceActions();
  const router = useRouter();
  const [reason, setReason] = useState("");
  const teacher = target.kind === "profile" ? state.teachers.find(item => item.id === target.id) : null;
  const proposal = target.kind === "proposal" ? state.proposals.find(item => item.id === target.id) : null;
  const offer = target.kind === "offer" ? state.offers.find(item => item.id === target.id) : null;
  const article = target.kind === "article" ? state.articles.find(item => item.id === target.id) : null;
  const [featured, setFeatured] = useState(teacher?.featured ?? false);
  const [error, setError] = useState("");
  const snapshot = proposal?.snapshot || teacher?.reviewSnapshot || offer?.reviewSnapshot || article?.reviewSnapshot;
  const title = proposal ? "平台審核課程提案" : teacher ? "審核老師展示頁" : offer ? "審核一對一課程包" : "審核文章";
  if (!snapshot) return <Modal title="送審內容已更新" onClose={onClose}><p>這筆快照已處理或不再有效，請回審核清單重新選擇。</p><Btn onClick={onClose}>回審核清單</Btn></Modal>;
  const preview = proposal ? <ProposalPreview proposal={proposal}/> : teacher ? <ProfilePreview profile={teacher.reviewSnapshot!}/> : offer ? <OfferPreview offer={offer.reviewSnapshot!}/> : <ArticlePreview content={article!.reviewSnapshot!}/>;
  const proceed = (approve: boolean) => {
    if (reason.trim().length < 3) { setError("請填至少 3 個字的審核原因。"); return; }
    const expectedSnapshot = JSON.stringify(snapshot);
    const command: Command = proposal ? { type: "reviewProposal", id: target.id, decision: approve ? "import" : "return", reason, confirmed: true, expectedSnapshot } : approve ? teacher ? { type: "publishProfile", teacherId: target.id, featured, reason, confirmed: true, expectedSnapshot } : offer ? { type: "publishOffer", id: target.id, reason, confirmed: true, expectedSnapshot } : { type: "publishArticle", id: target.id, reason, confirmed: true, expectedSnapshot } : { type: "rejectContent", kind: target.kind as "profile" | "offer" | "article", id: target.id, reason, confirmed: true, expectedSnapshot };
    onClose();
    confirm(approve ? proposal ? "把提案匯入平台課程草稿" : "確認本機上架這次送審快照" : "確認退回補充說明", <>{preview}<p>審核原因：{reason}</p><div className="v4-alert">{approve ? proposal ? "只匯入本次送審快照；公開版本不變，還要由管理員檢查並發布。" : "只處理已預覽的送審快照；保留既有課程包、交易與學生權益。" : "送審內容回到草稿，原本的公開版本保持不變。"}</div></>, () => {
      const result = dispatch(command);
      notify(result.ok ? approve ? proposal ? "已匯入平台草稿，尚未對外公開。" : "已更新本機公開版本。" : "已退回草稿，請補充後重新送審。" : result.error!);
      if (result.ok && proposal && approve) router.push(`${base}/admin/courses/${result.id}`);
      return result.ok;
    });
  };
  return <Modal title={title} onClose={onClose}>{preview}{teacher && <Check label="放入首頁師資推薦" checked={featured} onChange={setFeatured}/>}<Area label="核准或退回原因（必填）" value={reason} onChange={setReason}/>{error && <p role="alert" className="v4-alert">{error}</p>}<div className="x-actions"><Btn onClick={() => proceed(false)}>退回補充說明</Btn><Btn primary onClick={() => proceed(true)}>{proposal ? "預覽匯入平台草稿" : "預覽核准結果"}</Btn></div><p className="dialog-note">只處理這筆送審快照。老師之後修改草稿，不會偷偷更動這次審核內容。</p></Modal>;
}
function ProposalPreview({ proposal }: { proposal: Proposal }) { const snapshot = proposal.snapshot!; return <><Flag>提案 v{proposal.revision}</Flag><ContentPreview content={snapshot.content}/><p><b>適合對象</b>：{snapshot.audience}</p><div className="v4-alert">素材與備註：{snapshot.rightsNote}<br/>本課 Pro 影片指導申請：{snapshot.proRequested ? "提出申請" : "未申請"}<br/>這一步只接受進編輯流程，不會直接成為公開課程。</div></>; }
function ProfilePreview({ profile }: { profile: TeacherProfile }) { return <div className="x-approval-snapshot"><h3>{profile.name}</h3><p>{profile.headline}</p><p>{profile.specialties}</p><p className="t-prewrap">{profile.about}</p><p>公開分類：{[profile.showSystem && "系統課程", profile.showStandalone && "單品課", profile.showPrivate && "一對一"].filter(Boolean).join("、") || "目前不公開分類"}</p></div>; }
function OfferPreview({ offer }: { offer: OfferContent }) { const { state } = usePrototype(); return <div className="x-approval-snapshot"><h3>{offer.title}</h3><p>{offer.count} 堂 × {money(offer.unitPrice)} = {money(offer.unitPrice === null ? null : offer.count * offer.unitPrice)}</p><p>{offer.mode === "both" ? "固定制／預約制" : offer.mode === "fixed" ? "固定制" : "預約制"} · 每堂 {offer.duration} 分鐘</p><p>{offer.expiryLabel}</p><p>{offer.targetStudentId ? `只給 ${state.students.find(student => student.id === offer.targetStudentId)?.name || offer.targetStudentId}，不在公開首頁列出` : "公開課程包"}</p><p>{offer.note}</p></div>; }

function FeaturedDialog({ id, onClose }: { id: string; onClose: () => void }) {
  const { state, dispatch } = usePrototype();
  const { confirm, notify } = useWorkspaceActions();
  const [reason, setReason] = useState("");
  const [error, setError] = useState("");
  const teacher = state.teachers.find(item => item.id === id)!;
  const title = teacher.featured ? "移出首頁推薦" : "放入首頁推薦";
  return <Modal title={title} onClose={onClose}><h3>{teacher.published!.name}</h3><p>只調整已核准介紹頁的首頁推薦；公開老師圖卡仍必須有公開一對一課程包。</p><Area label="調整原因（必填）" value={reason} onChange={setReason}/>{error && <p role="alert" className="v4-alert">{error}</p>}<Btn primary onClick={() => { if (reason.trim().length < 3) { setError("請填調整原因。"); return; } onClose(); confirm(title, <><p>{teacher.published!.name}</p><p>原因：{reason}</p></>, () => { const result = dispatch({ type: "setTeacherFeatured", teacherId: teacher.id, featured: !teacher.featured, reason, confirmed: true }); notify(result.ok ? "已更新本機首頁推薦。" : result.error!); return result.ok; }); }}>預覽調整</Btn></Modal>;
}

function Articles() {
  const { state, dispatch } = usePrototype();
  const { notify } = useWorkspaceActions();
  const router = useRouter();
  const [filter, setFilter] = useState("all");
  const [preview, setPreview] = useState<ArticleContent | null>(null);
  const [createdId, setCreatedId] = useState<string | null>(null);
  useEffect(() => { if (createdId) router.push(`${base}/admin/articles/${createdId}`); }, [createdId, router]);
  const rows = state.articles.filter(article => filter === "all" || article.status === filter);
  const create = () => { const result = dispatch({ type: "createArticle" }); if (result.ok && result.id) setCreatedId(result.id); else notify(result.error!); };
  return <><Header eyebrow="EDITORIAL STUDIO / 把你的教學帶給更多人" title="文章管理" sub="先把內容寫清楚，預覽閱讀感，再決定發布。" tools={<Btn primary onClick={create}>＋ 新增文章</Btn>}/><div className="x-subtabs">{[["all", "全部"], ["draft", "草稿"], ["review", "待審核"], ["published", "已發布"]].map(([value, name]) => <button key={value} aria-pressed={filter === value} onClick={() => setFilter(value)}>{name}</button>)}</div><Table headers={["文章", "分類", "編輯狀態", "公開版本", "操作"]}>{rows.length ? rows.map(article => <tr key={article.id}><td><strong>{article.draft.title}</strong><small>{article.draft.slug}</small></td><td>{article.draft.category}</td><td><Flag active={article.status === "review"}>{statusName(article.status)}</Flag></td><td>{article.published ? `已有公開版本 v${article.revision}` : "尚未發布"}</td><td><div className="x-actions"><Go to={`admin/articles/${article.id}`}>編輯</Go><Btn onClick={() => setPreview(article.draft)}>預覽</Btn></div></td></tr>) : <tr><td colSpan={5}>沒有符合的文章</td></tr>}</Table><Foot/>{preview && <Modal title="文章草稿預覽" onClose={() => setPreview(null)}><ArticlePreview content={preview}/><Btn onClick={() => setPreview(null)}>回文章管理</Btn></Modal>}</>;
}
function ArticleEditor({ id }: { id: string }) { const { state } = usePrototype(); const article = state.articles.find(item => item.id === id); return article ? <ArticleForm key={id} article={article}/> : <Empty title="尚未選擇文章"><Go to="admin/articles">回文章管理</Go></Empty>; }
function ArticleForm({ article }: { article: Article }) {
  const { dispatch } = usePrototype();
  const { notify } = useWorkspaceActions();
  const router = useRouter();
  const [content, setContent] = useState(article.draft);
  const [preview, setPreview] = useState(false);
  const [error, setError] = useState("");
  const update = <K extends keyof ArticleContent>(key: K, value: ArticleContent[K]) => setContent(previous => ({ ...previous, [key]: value }));
  const save = (submit: boolean) => {
    const result = dispatch({ type: "saveArticle", id: article.id, content });
    if (!result.ok) { setError(result.error!); return; }
    if (submit) { const result = dispatch({ type: "submitArticle", id: article.id }); if (!result.ok) { setError(result.error!); return; } notify("文章快照已送入審核，公開版本尚未更新。"); router.push(`${base}/admin/review`); } else notify("已儲存文章草稿，公開版本保持不變。");
    setError("");
  };
  return <><Header eyebrow="ARTICLE EDITOR / 用內容陪學生往前" title="編輯文章" sub="儲存草稿不會更新公開版本。發布前先預覽一次。" tools={<Go to="admin/articles">回文章列表</Go>}/><div className="x-editor"><section><Field label="文章標題" value={content.title} onChange={value => update("title", value)}/><Area label="文章摘要" value={content.summary} onChange={value => update("summary", value)}/><div className="ux-content-long"><Area label="文章內容・段落以空行分開" value={content.body} onChange={value => update("body", value)}/></div><div className="x-field"><label className="x-label" htmlFor="article-local-cover">文章封面・本地圖片檔名示意</label><input id="article-local-cover" type="file" accept="image/jpeg,image/png,image/webp" onChange={event => { const file = event.currentTarget.files?.[0]; if (file && file.size > 5 * 1024 * 1024) { setError("封面示意檔案請小於 5 MB。"); event.currentTarget.value = ""; return; } update("coverName", file?.name || ""); setError(""); }}/><small>{content.coverName || "尚未選擇"} · 只保留檔名，不讀取、不儲存或上傳圖片內容。</small></div>{error && <p role="alert" className="v4-alert">{error}</p>}<div className="x-bottom-actions"><Btn onClick={() => save(false)}>儲存草稿</Btn><Btn onClick={() => setPreview(true)}>預覽文章</Btn><Btn primary onClick={() => save(true)}>送入發布審核</Btn></div></section><aside className="x-summary"><div className="x-panel"><h3>發布資訊</h3><div className="x-course-meta"><Flag active={article.status === "review"}>{statusName(article.status)}</Flag></div><Field label="網址代稱" value={content.slug} placeholder="例如：guitar-practice" onChange={value => update("slug", value)}/><Field label="分類" value={content.category} onChange={value => update("category", value)}/><Field label="搜尋標題" value={content.seoTitle || ""} onChange={value => update("seoTitle", value)}/><Area label="搜尋摘要" value={content.seoDescription || ""} onChange={value => update("seoDescription", value)}/><p>文章內容目前以純文字段落示範，不執行貼入的 HTML 或程式碼。</p></div><Note>正式 SEO、圖片儲存、預約發布、網址轉址與搜尋索引尚未接線。此處只展示編輯、審核與本機發布流程。</Note></aside></div><Foot/>{preview && <Modal title="文章草稿預覽" onClose={() => setPreview(false)}><ArticlePreview content={content}/><Btn onClick={() => setPreview(false)}>回到編輯</Btn></Modal>}</>;
}

