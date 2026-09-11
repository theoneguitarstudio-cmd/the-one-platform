import type { CourseContent, CoursePolicy, OfferContent, PrototypeState, TeacherProfile } from "./model";

/** Adapted from the supplied v1.6 REFERENCE_STATE.json, never from live data.
 * Source yu/an/qing map once to s1/s2/s3. Slots retain source s1–s5 IDs.
 */
export const fixtureStudentIds = { yu: "s1", an: "s2", qing: "s3" } as const;
export const levelOutcomes = [
  "我可以把一首歌完整彈完", "我的伴奏不再只有一種", "我開始知道自己在彈什麼",
  "我可以慢慢離開樂譜", "我可以自己改歌、加旋律、加 Solo", "我可以自己處理一首陌生歌曲",
] as const;
const profile: TeacherProfile = {
  name: "The One 老師", headline: "把練習變簡單，讓音樂慢慢成為你的日常。",
  about: "從一個順手的和弦開始，陪你把一首喜歡的歌彈完整。\n課程從目標出發，依照你的程度調整練習的步伐。",
  specialties: "木吉他伴奏、節奏訓練、音樂理解", photo: "", showSystem: true, showStandalone: true, showPrivate: true,
};
const courseContent: CourseContent = {
  title: "The One Guitar Roadmap 2.0", summary: "從基礎開始，透過階段路線與有方向的練習，慢慢建立自己的吉他能力。",
  kind: "system", billing: "membership", price: null, objective: "讓伴奏不再只有一種。",
  outline: "右手節奏與切音\n把切音放進伴奏\n單元最後一步：上傳本次練習", resourceName: "",
};
const coursePolicy: CoursePolicy = { included: true, plusAccess: true, proReview: true };
const offer = (count: number): OfferContent => ({ title: `${count} 堂一對一`, count, unitPrice: 1000, mode: "both", duration: 50, expiryLabel: "依正式課程包規則", targetStudentId: null, note: "依學生目標調整內容，固定制或預約制須依可用時段安排。" });
const progress = (done: string[]) => [{ courseId: "c1", stage: 2, moduleId: "m1", lessonId: "l3", activity: "learn", selfCompleted: done, practiced: [], verified: [] }];

export function createFixtures(): PrototypeState {
  return {
    clock: "2026-09-08T00:00:00Z", counter: 100, appliedRequestIds: [],
    teachers: [
      { id: "t1", draft: { ...profile }, published: { ...profile }, status: "published", featured: true, canReview: true },
      { id: "t2", draft: { ...profile, name: "合作老師 B（示意）" }, published: null, status: "draft", featured: false, canReview: false },
    ],
    students: [
      { id: "s1", sourceId: "yu", name: "小宇", initial: "宇", relation: "private", teacherId: "t1", membership: "Pro", joinedCourseIds: ["c1"], accessCourseIds: ["c1"], serviceEligibility: "available", focus: "把切音放進伴奏", note: "上次練習切音後容易停頓，今天先用慢速連起來。", progress: progress(["l1", "l2"]) },
      { id: "s2", sourceId: "an", name: "小安", initial: "安", relation: "private", teacherId: "t1", membership: "Free", joinedCourseIds: [], accessCourseIds: [], serviceEligibility: "unknown", focus: "把一首歌從頭彈完", note: "先確認和弦轉換是否順手，再安排右手節奏。", progress: [] },
      { id: "s3", sourceId: "qing", name: "小晴", initial: "晴", relation: "platform", teacherId: null, membership: "Pro", joinedCourseIds: ["c1"], accessCourseIds: ["c1"], serviceEligibility: "available", focus: "練習不同的伴奏表情", note: "本次指派：檢視切音練習影片。", progress: progress(["l1", "l2", "l3"]) },
    ],
    courses: [
      { id: "c1", teacherId: "t1", draft: { ...courseContent }, published: { ...courseContent }, status: "published", revision: 1, draftRevision: 1, policy: { ...coursePolicy }, draftPolicy: { ...coursePolicy } },
      { id: "c2", teacherId: "t1", draft: { ...courseContent, title: "伴奏編曲練習｜單品課示範", summary: "這是一個待上架的虛構課程，用來試看單次購買、課程送審與老師展示頁。", kind: "standalone", billing: "one_time", price: 1800 }, published: null, status: "draft", revision: 0, draftRevision: 1, policy: { included: false, plusAccess: false, proReview: false }, draftPolicy: { included: false, plusAccess: false, proReview: false } },
    ],
    proposals: [],
    offers: [4, 12, 24, 48].map((count) => ({ id: `p${count}`, teacherId: "t1", draft: offer(count), published: offer(count), version: 1, status: "published" })),
    packages: [
      { id: "e-yu", studentId: "s1", teacherId: "t1", offerId: "p4", offerVersion: 1, snapshot: { ...offer(4), title: "4 堂一對一・既有固定制" }, mode: "fixed", expiry: "2027-01-01", source: "既有課程包 fixture", status: "active" },
      { id: "e-an", studentId: "s2", teacherId: "t1", offerId: "p4", offerVersion: 1, snapshot: { ...offer(4), title: "4 堂一對一・既有預約制" }, mode: "flexible", expiry: "2027-01-01", source: "既有課程包 fixture", status: "active" },
    ],
    ledger: [
      { id: "credit-1", packageId: "e-yu", kind: "allocate", quantity: 4, label: "既有購課權益・示意" },
      { id: "credit-2", packageId: "e-yu", kind: "consume", quantity: 1, label: "既有已上課・示意" },
      { id: "credit-3", packageId: "e-yu", kind: "reserve", quantity: 1, bookingId: "ab1", label: "已預留 9/9 課程" },
      { id: "credit-4", packageId: "e-an", kind: "allocate", quantity: 4, label: "既有購課權益・示意" },
      { id: "credit-5", packageId: "e-an", kind: "reserve", quantity: 1, bookingId: "ab2", label: "已預留 9/9 課程" },
    ],
    bookings: [
      { id: "ab1", studentId: "s1", teacherId: "t1", packageId: "e-yu", start: "2026-09-09T12:00:00Z", end: "2026-09-09T12:50:00Z", mode: "fixed", format: "online", status: "reserved", createdBy: "fixture", consent: "既有固定制示意安排", reason: "來源原稿固定預約" },
      { id: "ab2", studentId: "s2", teacherId: "t1", packageId: "e-an", start: "2026-09-09T13:00:00Z", end: "2026-09-09T13:50:00Z", mode: "flexible", format: "online", status: "reserved", createdBy: "fixture", consent: "既有預約制示意安排", reason: "來源原稿預留預約" },
    ],
    availability: [
      { id: "s1", teacherId: "t1", start: "2026-09-10T12:00:00Z", end: "2026-09-10T12:50:00Z", mode: "flexible" },
      { id: "s2", teacherId: "t1", start: "2026-09-10T13:00:00Z", end: "2026-09-10T13:50:00Z", mode: "flexible" },
      { id: "s3", teacherId: "t1", start: "2026-09-12T12:00:00Z", end: "2026-09-12T12:50:00Z", mode: "flexible" },
      { id: "s4", teacherId: "t1", start: "2026-09-16T12:00:00Z", end: "2026-09-16T12:50:00Z", mode: "fixed", priorityStudentId: "s1" },
      { id: "s5", teacherId: "t2", start: "2026-09-10T12:00:00Z", end: "2026-09-10T12:50:00Z", mode: "flexible" },
    ],
    submissions: [
      { id: "r1", studentId: "s1", teacherId: "t1", kind: "private", courseId: "c1", lessonId: "l3", title: "切音後的下一拍，還是接不順", question: "老師，我把速度放慢了，但切音之後常常會停一下。這是我這次的練習。", submittedAt: "2026-09-08T13:10:00Z", duration: "0:48", mediaName: "本地示意練習影片", status: "assigned" },
      { id: "r2", studentId: "s3", teacherId: "t1", kind: "pro", courseId: "c1", lessonId: "l4", title: "同一段伴奏，換兩種表情", question: "這次試了兩種切音位置，想請老師幫我聽聽哪裡可以更自然。", submittedAt: "2026-09-09T01:30:00Z", duration: "1:12", mediaName: "本地示意練習影片", status: "assigned" },
    ],
    feedback: [],
    lessonRecords: [{ id: "record-1", bookingId: "ab1", teacherId: "t1", studentId: "s1", publicNote: "先讓右手持續擺動，切音後不要停下來。", privateNote: "老師課前提醒：先看上一堂的右手節奏。", practice: "用 60 BPM 練習四小節，再回到歌曲裡。" }],
    articles: [{ id: "a1", draft: { title: "和弦會按了，為什麼換和弦還是卡？", slug: "smoother-chord-changes", category: "練習方法", summary: "不用一直從頭彈。先找出手指最容易停住的地方。", body: "先把速度放慢，觀察手指離開上一個和弦的時刻。\n\n一次只練兩個和弦，維持右手的拍點，不急著把整首歌彈完。\n\n這是文章編輯器的示意內容，不是已發布的正式文章。" }, published: null, status: "draft", revision: 0, reviewSnapshot: null }],
    policies: [
      { id: "student-online", audience: "student", title: "上課與預約", body: "目前只提供線上教學，暫不開放實體課或教室據點。\n固定制與預約制是不同排課方式。購買課程包不代表已預約；請以已確認的課次、時間與時區為準。\n老師代約前須取得你對該次時段的同意，並留下確認記錄。老師不能直接以「代約」當成已上課。\n取消、改期、遲到、未出席、包期效期與退款的具體期限及費用尚待平台確認；正式購買及預約前須完整揭露適用版本。", version: "0.1", usedVersions: ["0.1"], draft: null },
      { id: "student-services", audience: "student", title: "會員、練習與個人資料", body: "Free／Plus／Pro 是平台會員方案，不等於加入一套課程，也不自動包含所有單品課及私人課。\nPro 影片指導須符合課程支援、服務資格及可用額度；提交、老師回饋、正式驗證與證書是不同流程。\n請只提交你有權使用的練習內容；學生影片僅供必要教學人員與受控平台協助使用，公開展示需另取得適當同意。\n本地診斷問卷只是學習方向建議，不是實力考試。此 Demo 不索取真實帳號或收集聯絡資料。正式資料保存與隱私政策仍需定稿。", version: "0.1", usedVersions: ["0.1"], draft: null },
      { id: "teacher-proposals", audience: "teacher", title: "課程提案與平台審核", body: "老師只能建立、修改及提交自己的提案，不得直接新增正式課程、改動已上架內容或按下發布。\n提案應說明教學成果、適合對象、章節、所需素材授權及建議收費方式；教材、圖片、音樂與影片須具備必要使用權利。\n平台審核通過後，由管理員匯入正式課程草稿，編輯、確認後發布；老師的後續修改另開提案版本，不覆蓋正式課程。\n課程類型與收費方式分開。是否加入會員目錄、提供 Pro 指導及公開展示，均由平台確認。", version: "0.1", usedVersions: ["0.1"], draft: null },
      { id: "teacher-booking", audience: "teacher", title: "線上教學與代學生預約", body: "本階段只提供線上課程，不新增實體上課選項。\n老師僅能替與自己有教學關係、持有自己的有效預約制課程包且有可用堂數的學生代約。\n每次代約須記下學生已同意的時段與依據，檢查雙方衝突、課程包效期及已公開可用時段。\n代約成功只預留堂數，不直接完成上課、不立即取得報酬；不可代約其他老師的學生或變更固定制系列。異常情況交由平台協助。", version: "0.1", usedVersions: ["0.1"], draft: null },
      { id: "teacher-earnings", audience: "teacher", title: "報酬、分潤與教學資料", body: "老師只查看自己的收入與對應服務記錄，不取得其他老師的報酬或全站收款資料。\n一對一、會員內容創作、Pro 指導、單品課等報酬分開記錄。訂閱創作歸屬不按老師人數平均，也不只看觀看次數。\n定價提案、服務完成、報酬核對與撥款分開；已確認紀錄保留原合約快照。新版本不追溯覆寫已確認報酬。\n撥款週期、最低撥款額、退款調整、爭議與稅務處理尚待平台商業與專業確認，不在本雛形承諾。學生資訊僅用於授權範圍內的教學。", version: "0.1", usedVersions: ["0.1"], draft: null },
    ],
    acknowledgements: [],
    earnings: [
      { id: "E-901", teacherId: "t1", kind: "private", title: "一對一已完成課次", reference: "LESSON-DEMO-01", month: "2026-09", amount: 1500, status: "ready", rule: "合約快照 D-A（示意）" },
      { id: "E-902", teacherId: "t1", kind: "private", title: "一對一已完成課次", reference: "LESSON-DEMO-02", month: "2026-09", amount: 1500, status: "paid", rule: "合約快照 D-A（示意）", paidAt: "2026-09-08", proof: "DEMO-PAYOUT-001" },
      { id: "E-903", teacherId: "t1", kind: "review", title: "Pro 影片指導服務", reference: "REVIEW-DEMO-01", month: "2026-09", amount: 450, status: "ready", rule: "服務報酬快照 D-R（示意）" },
      { id: "E-904", teacherId: "t1", kind: "standalone", title: "單品課創作者報酬", reference: "ORDER-DEMO-S1", month: "2026-09", amount: 1200, status: "ready", rule: "商品合約快照 D-S（示意）" },
      { id: "E-905", teacherId: "t1", kind: "creator", title: "會員內容創作歸屬", reference: "ATTR-DEMO-C1", month: "2026-09", amount: null, status: "unconfigured", rule: "分潤規則尚未核准" },
      { id: "E-906", teacherId: "t2", kind: "private", title: "合作老師 B 一對一服務", reference: "LESSON-DEMO-B1", month: "2026-09", amount: 2400, status: "ready", rule: "合約快照 D-B（示意）" },
      { id: "E-907", teacherId: "t2", kind: "review", title: "待核對指導紀錄", reference: "REVIEW-DEMO-B2", month: "2026-09", amount: 300, status: "review", rule: "尚待服務核對" },
      { id: "E-801", teacherId: "t1", kind: "private", title: "八月一對一已核對", reference: "LESSON-DEMO-AUG", month: "2026-08", amount: 2800, status: "paid", rule: "歷史合約快照 D-OLD（示意）", paidAt: "2026-08-28", proof: "DEMO-PAYOUT-AUG" },
    ],
    cashEvents: [
      { id: "C-901", date: "2026-09-03", kind: "receipt", title: "平台會員訂閱收款彙總・示意", amount: 12000, reference: "PAY-DEMO-M1" },
      { id: "C-902", date: "2026-09-04", kind: "receipt", title: "一對一課程包收款・示意", amount: 12000, reference: "PAY-DEMO-L1" },
      { id: "C-903", date: "2026-09-06", kind: "receipt", title: "單品課收款・示意", amount: 3000, reference: "PAY-DEMO-S1" },
      { id: "C-904", date: "2026-09-08", kind: "refund", title: "已完成退款・示意", amount: 1000, reference: "REFUND-DEMO-L1" },
      { id: "C-905", date: "2026-09-09", kind: "fee", title: "本期已確認金流費用・示意", amount: 650, reference: "FEE-DEMO-SEP" },
      { id: "C-801", date: "2026-08-05", kind: "receipt", title: "八月課程包收款・示意", amount: 8000, reference: "PAY-DEMO-AUG" },
      { id: "C-802", date: "2026-08-28", kind: "fee", title: "八月已確認費用・示意", amount: 200, reference: "FEE-DEMO-AUG" },
    ],
    settlements: [], financeDrafts: [], audit: [], oversightAccess: [], platformReplies: [], discussionComments: [], privateNotes: [], teachingDrafts: [],
  };
}
