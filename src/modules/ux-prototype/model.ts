/** Isolated, in-memory UX fixtures. This is not a production authorization layer.
 * Fixture IDs are deliberately not database UUIDs. No command calls a backend.
 */
export type Actor = { role: "student" | "teacher" | "admin"; id: string; capability?: "ops" | "finance" | "owner" };
export type Theme = "dark" | "light" | "system";
export type Membership = "Free" | "Plus" | "Pro";
export type BookingMode = "fixed" | "flexible";
export type ContentStatus = "draft" | "review" | "published";
export type TeacherProfile = { name: string; headline: string; about: string; specialties: string; photo: string; showSystem: boolean; showStandalone: boolean; showPrivate: boolean };
export type Teacher = { id: string; draft: TeacherProfile; published: TeacherProfile | null; reviewSnapshot?: TeacherProfile | null; status: ContentStatus; featured: boolean; canReview: boolean };
export type LearningProgress = { courseId: string; stage: number; moduleId: string; lessonId: string; activity: string; selfCompleted: string[]; practiced: string[]; verified: string[] };
export type Student = { id: string; sourceId: string; name: string; initial: string; relation: "private" | "platform" | "none"; teacherId: string | null; membership: Membership; joinedCourseIds: string[]; accessCourseIds: string[]; serviceEligibility: "available" | "unavailable" | "unknown"; focus: string; note: string; progress: LearningProgress[]; privatePracticed?: string[] };
export type CourseContent = { title: string; summary: string; kind: "system" | "standalone"; billing: "membership" | "one_time"; price: number | null; objective: string; outline: string; resourceName: string };
export type CoursePolicy = { included: boolean; plusAccess: boolean; proReview: boolean };
export type Course = { id: string; teacherId: string; draft: CourseContent; published: CourseContent | null; status: ContentStatus; revision: number; draftRevision: number; policy: CoursePolicy; draftPolicy: CoursePolicy; proposalId?: string };
export type Proposal = { id: string; teacherId: string; baseCourseId: string | null; baseRevision: number; revision: number; status: "draft" | "review" | "changes" | "imported" | "published" | "superseded"; content: CourseContent; audience: string; rightsNote: string; proRequested: boolean; snapshot: { content: CourseContent; audience: string; rightsNote: string; proRequested: boolean } | null; reviewNote: string; importedCourseId: string | null };
export type OfferContent = { title: string; count: number; unitPrice: number | null; mode: BookingMode | "both"; duration: number; expiryLabel: string; targetStudentId: string | null; note: string };
export type PackageOffer = { id: string; teacherId: string; draft: OfferContent; published: OfferContent | null; reviewSnapshot?: OfferContent | null; status: ContentStatus; version: number };
export type StudentPackage = { id: string; studentId: string; teacherId: string; offerId: string; offerVersion: number; snapshot: OfferContent; mode: BookingMode; expiry: string; source: string; status: "active" | "expired" };
export type CreditEntry = { id: string; packageId: string; kind: "allocate" | "reserve" | "release" | "consume"; quantity: number; bookingId?: string; label: string };
export type Booking = { id: string; studentId: string; teacherId: string; packageId: string; start: string; end: string; mode: BookingMode; format: "online"; status: "reserved" | "cancelled" | "completed"; createdBy: string; consent: string; reason: string };
export type Availability = { id: string; teacherId: string; start: string; end: string; mode: BookingMode; priorityStudentId?: string };
export type Submission = { id: string; studentId: string; teacherId: string | null; kind: "private" | "pro"; courseId: string; lessonId: string; title: string; question: string; submittedAt: string; duration: string; mediaName: string; status: "submitted" | "assigned" | "replied" };
export type Feedback = { id: string; submissionId: string; studentId: string; teacherId: string; observation: string; nextPractice: string; privateNote: string; createdAt: string };
export type ArticleContent = { title: string; slug: string; category: string; summary: string; body: string; seoTitle?: string; seoDescription?: string; coverName?: string };
export type Article = { id: string; draft: ArticleContent; published: ArticleContent | null; status: ContentStatus; revision: number; reviewSnapshot: ArticleContent | null };
export type Policy = { id: string; audience: "student" | "teacher"; title: string; body: string; version: string; usedVersions: string[]; draft: { title: string; body: string; version: string } | null };
export type Acknowledgement = { actorId: string; policyId: string; version: string };
export type Earning = { id: string; teacherId: string; month: string; kind: "private" | "creator" | "review" | "assessment" | "standalone" | "mentor"; title: string; reference: string; rule: string; amount: number | null; status: "ready" | "approved" | "paid" | "review" | "unconfigured"; paidAt?: string; proof?: string };
export type CashEvent = { id: string; date: string; kind: "receipt" | "refund" | "fee"; title: string; reference: string; amount: number };
export type Settlement = { id: string; teacherId: string; month: string; earningIds: string[]; total: number; status: "prepared" | "approved" | "paid"; reason: string; proof?: string };
export type FinanceDraft = { id: string; name: string; scope: string; kind: Earning["kind"]; effective: string; base: number; allocations: number[]; unallocated: number; reason: string; status: "draft" };
export type AuditEvent = { id: string; actor: Actor; action: string; target: string; reason: string; at: string; before: unknown; after: unknown; sensitive: boolean };
export type OversightAccess = { actorId: string; studentId: string; reason: string };
export type PlatformReply = { id: string; studentId: string; actorId: string; body: string; authorLabel: "平台協助" };
export type LessonRecord = { id: string; bookingId: string; teacherId: string; studentId: string; publicNote: string; privateNote: string; practice: string };
export type DiscussionComment = { id: string; studentId: string; courseId: string; lessonId: string; text: string };
export type PrivateNote = { id: string; teacherId: string; studentId: string; text: string };
export type TeachingDraft = { key: string; teacherId: string; kind: "review" | "lesson"; targetId: string; observation: string; nextPractice: string };
export type PrototypeState = {
  clock: string; counter: number; appliedRequestIds: string[];
  teachers: Teacher[]; students: Student[]; courses: Course[]; proposals: Proposal[];
  offers: PackageOffer[]; packages: StudentPackage[]; ledger: CreditEntry[]; bookings: Booking[]; availability: Availability[];
  submissions: Submission[]; feedback: Feedback[]; lessonRecords: LessonRecord[]; teachingDrafts: TeachingDraft[]; articles: Article[];
  policies: Policy[]; acknowledgements: Acknowledgement[]; earnings: Earning[]; cashEvents: CashEvent[];
  settlements: Settlement[]; financeDrafts: FinanceDraft[]; audit: AuditEvent[]; oversightAccess: OversightAccess[]; platformReplies: PlatformReply[]; discussionComments: DiscussionComment[]; privateNotes: PrivateNote[];
};
type Confirmed = { reason: string; confirmed: boolean; requestId?: string };
export type Command =
  | { type: "joinCourse"; studentId: string; courseId: string }
  | { type: "setStudentScenario"; studentId: string; membership?: Membership; joined?: boolean; access?: boolean; serviceEligibility?: Student["serviceEligibility"] }
  | { type: "progress"; studentId: string; courseId: string; lessonId: string; stage?: number; moduleId?: string; activity?: string; selfComplete?: boolean; practiceId?: string }
  | { type: "addDiscussionComment"; courseId: string; lessonId: string; text: string }
  | { type: "privatePractice"; studentId: string; practiceId: string }
  | { type: "setRosterScenario"; scenario: "empty" | "many" | "long" | "missing-image" | "no-public-offer" }
  | { type: "savePrivateNote"; studentId: string; text: string }
  | { type: "setAvailability"; slots: Array<Omit<Availability, "teacherId">> }
  | { type: "createProposal"; baseCourseId?: string }
  | { type: "saveProposal"; id: string; content: CourseContent; audience: string; rightsNote: string; proRequested: boolean }
  | { type: "submitProposal"; id: string; rightsConfirmed: boolean }
  | { type: "reviseProposal"; id: string }
  | ({ type: "reviewProposal"; id: string; decision: "return" | "import"; expectedSnapshot?: string } & Confirmed)
  | { type: "createCourse" }
  | { type: "saveCourse"; id: string; content: CourseContent; policy: CoursePolicy; reason: string }
  | ({ type: "publishCourse"; id: string; expectedRevision: number } & Confirmed)
  | { type: "saveOffer"; id?: string; content: OfferContent }
  | { type: "submitOffer"; id: string }
  | ({ type: "publishOffer"; id: string; expectedSnapshot?: string } & Confirmed)
  | { type: "saveProfile"; teacherId: string; profile: TeacherProfile }
  | { type: "submitProfile"; teacherId: string }
  | ({ type: "publishProfile"; teacherId: string; featured: boolean; expectedSnapshot?: string } & Confirmed)
  | ({ type: "rejectContent"; kind: "profile" | "offer" | "article"; id: string; expectedSnapshot?: string } & Confirmed)
  | ({ type: "setTeacherFeatured"; teacherId: string; featured: boolean } & Confirmed)
  | ({ type: "grantPackage"; studentId: string; offerId: string; mode: BookingMode; expiry: string; source: "manual-reissue" | "gift" | "offline-entitlement" } & Confirmed)
  | ({ type: "book"; packageId: string; slotId: string; consent: string; policyConfirmed: boolean } & Confirmed)
  | ({ type: "reschedule"; bookingId: string; slotId: string; consent: string } & Confirmed)
  | ({ type: "cancelBooking"; bookingId: string } & Confirmed)
  | { type: "submitGuidance"; studentId: string; courseId: string; lessonId: string; title: string; question: string; mediaName: string }
  | { type: "assignSubmission"; submissionId: string; teacherId: string; reason: string }
  | { type: "reply"; submissionId: string; observation: string; nextPractice: string; privateNote: string }
  | { type: "saveTeachingDraft"; kind: "review" | "lesson"; targetId: string; observation: string; nextPractice: string }
  | { type: "saveLessonRecord"; bookingId: string; publicNote: string; privateNote: string; practice: string }
  | { type: "createArticle" }
  | { type: "saveArticle"; id: string; content: ArticleContent }
  | { type: "submitArticle"; id: string }
  | ({ type: "publishArticle"; id: string; expectedSnapshot?: string } & Confirmed)
  | { type: "ackPolicy"; policyId: string }
  | { type: "savePolicy"; id: string; title: string; body: string; version: string; reason: string }
  | ({ type: "publishPolicy"; id: string } & Confirmed)
  | { type: "prepareSettlement"; teacherId: string; month: string; reason: string }
  | ({ type: "approveSettlement"; id: string } & Confirmed)
  | ({ type: "recordPayout"; id: string; proof: string } & Confirmed)
  | { type: "saveFinanceDraft"; name: string; scope: string; kind: Earning["kind"]; effective: string; base: number; allocations: number[]; reason: string }
  | { type: "earningInquiry"; earningId: string; reason: string }
  | { type: "openOversight"; studentId: string; reason: string }
  | { type: "closeOversight" }
  | { type: "platformReply"; studentId: string; body: string; reason: string };
export type CommandResult = { ok: boolean; error?: string; id?: string };

export const canOperate = (actor: Actor) => actor.role === "admin" && (actor.capability === "ops" || actor.capability === "owner");
export const canFinance = (actor: Actor) => actor.role === "admin" && (actor.capability === "finance" || actor.capability === "owner");
export function publicOffers(state: PrototypeState, teacherId: string) {
  return state.offers.filter((offer) => offer.teacherId === teacherId && offer.published && !offer.published.targetStudentId);
}
export function publicTeachers(state: PrototypeState) {
  return state.teachers.filter((teacher) => teacher.published?.showPrivate && teacher.featured && publicOffers(state, teacher.id).length > 0);
}
export function balance(state: PrototypeState, packageId: string) {
  const rows = state.ledger.filter((entry) => entry.packageId === packageId);
  const sum = (kind: CreditEntry["kind"]) => rows.filter((entry) => entry.kind === kind).reduce((total, entry) => total + entry.quantity, 0);
  const allocated = sum("allocate"), consumed = sum("consume"), reserved = sum("reserve") - sum("release");
  return { allocated, consumed, reserved, available: allocated - consumed - reserved };
}
export const studentBookings = (state: PrototypeState, studentId: string) => state.bookings.filter((booking) => booking.studentId === studentId);
export function visibleSubmissions(state: PrototypeState, actor: Actor) {
  return state.submissions.filter((submission) => actor.role === "student" ? submission.studentId === actor.id : actor.role === "teacher" ? submission.teacherId === actor.id : canOperate(actor));
}
export function visibleFeedback(state: PrototypeState, actor: Actor): Feedback[] {
  const ids = new Set(visibleSubmissions(state, actor).map((submission) => submission.id));
  return state.feedback.filter((feedback) => ids.has(feedback.submissionId)).map((feedback) => actor.role === "student" ? { ...feedback, privateNote: "" } : feedback);
}
export function visibleEarnings(state: PrototypeState, actor: Actor) {
  return state.earnings.filter((earning) => actor.role === "teacher" ? earning.teacherId === actor.id : canFinance(actor));
}
export function visibleTeachingDrafts(state: PrototypeState, actor: Actor) {
  return state.teachingDrafts.filter((draft) => actor.role === "teacher" && draft.teacherId === actor.id && (draft.kind === "review"
    ? state.submissions.some((submission) => submission.id === draft.targetId && submission.teacherId === actor.id && submission.status !== "replied")
    : state.bookings.some((booking) => booking.id === draft.targetId && booking.teacherId === actor.id)));
}
export const visibleAudit = (state: PrototypeState, actor: Actor) => state.audit.filter((event) => actor.role === "admin" && (actor.capability === "owner" || (actor.capability === "finance" ? event.sensitive : !event.sensitive)));
export function policiesAccepted(state: PrototypeState, actor: Actor) {
  if (actor.role === "admin") return true;
  return state.policies.filter((policy) => policy.audience === actor.role).every((policy) => state.acknowledgements.some((ack) => ack.actorId === actor.id && ack.policyId === policy.id && ack.version === policy.version));
}
export function guidanceEligibility(state: PrototypeState, studentId: string, courseId: string) {
  const student = state.students.find((item) => item.id === studentId), course = state.courses.find((item) => item.id === courseId);
  if (!student || !course?.published) return { allowed: false, reason: "課程或學生不存在。" };
  if (!student.joinedCourseIds.includes(courseId)) return { allowed: false, reason: "請先明確加入這套課程。" };
  if (student.membership !== "Pro") return { allowed: false, reason: "平台 Pro 才能使用符合資格的真人指導。" };
  if (!course.policy.proReview) return { allowed: false, reason: "這門課尚未支援 Pro 影片指導。" };
  if (!student.accessCourseIds.includes(courseId)) return { allowed: false, reason: "目前尚無這門課的存取資格。" };
  if (student.serviceEligibility !== "available") return { allowed: false, reason: student.serviceEligibility === "unknown" ? "本次服務資格待確認，未設定正式額度。" : "目前沒有可用的指導服務資格。" };
  return { allowed: true, reason: "符合本地示意提交資格；不扣正式額度。" };
}
export function availableSlots(state: PrototypeState, packageId: string, actor: Actor, exceptBookingId?: string) {
  const pack = state.packages.find((item) => item.id === packageId);
  if (!pack || pack.status !== "active" || new Date(pack.expiry + "T23:59:59Z") <= new Date(state.clock)) return [];
  if (!exceptBookingId && balance(state, pack.id).available < 1) return [];
  if (actor.role === "teacher" && (pack.teacherId !== actor.id || pack.mode !== "flexible" || !state.students.some((student) => student.id === pack.studentId && student.teacherId === actor.id && student.relation === "private"))) return [];
  if (actor.role === "student" && (pack.studentId !== actor.id || pack.mode !== "flexible")) return [];
  if (actor.role === "admin" && !canOperate(actor)) return [];
  return state.availability.filter((slot) => slot.teacherId === pack.teacherId && slot.mode === pack.mode && (!slot.priorityStudentId || slot.priorityStudentId === pack.studentId) && new Date(slot.start) > new Date(state.clock) && new Date(slot.end) <= new Date(pack.expiry + "T23:59:59Z") && !state.bookings.some((booking) => booking.id !== exceptBookingId && booking.status === "reserved" && (booking.teacherId === pack.teacherId || booking.studentId === pack.studentId) && slot.start < booking.end && slot.end > booking.start));
}
const clone = <T,>(value: T): T => structuredClone(value);
const reasonValid = (reason: string) => reason.trim().length >= 3;
const positive = (value: number | null) => value === null || (Number.isInteger(value) && value > 0);
const validDate = (value: string) => /^\d{4}-\d{2}-\d{2}$/.test(value) && Number.isFinite(Date.parse(value + "T00:00:00Z")) && new Date(value + "T00:00:00Z").toISOString().slice(0, 10) === value;
const emptyCourse = (): CourseContent => ({ title: "新的系統課程草稿", summary: "", kind: "system", billing: "membership", price: null, objective: "", outline: "", resourceName: "" });
const emptyPolicy = (): CoursePolicy => ({ included: false, plusAccess: false, proReview: false });

export function executeCommand(original: PrototypeState, actor: Actor, command: Command): { state: PrototypeState; result: CommandResult } {
  const reject = (error: string) => ({ state: original, result: { ok: false, error } });
  if (actor.role === "teacher" && !original.teachers.some((teacher) => teacher.id === actor.id)) return reject("未知的示意老師。");
  if (actor.role === "student" && !original.students.some((student) => student.id === actor.id)) return reject("未知的示意學生。");
  if ("requestId" in command && command.requestId && original.appliedRequestIds.includes(command.requestId)) return reject("這項確認已處理，沒有重複執行。");
  const state = clone(original);
  const id = (prefix: string) => `${prefix}-${++state.counter}`;
  const audit = (action: string, target: string, reason: string, before: unknown, after: unknown, sensitive = false) => state.audit.unshift({ id: id("audit"), actor: clone(actor), action, target, reason, at: state.clock, before: clone(before), after: clone(after), sensitive });
  const succeed = (resultId?: string) => {
    if ("requestId" in command && command.requestId) state.appliedRequestIds.push(command.requestId);
    return { state, result: { ok: true, ...(resultId ? { id: resultId } : {}) } };
  };
  const confirm = (value: Confirmed) => value.confirmed && reasonValid(value.reason);
  switch (command.type) {
    case "joinCourse": {
      const student = state.students.find((item) => item.id === command.studentId), course = state.courses.find((item) => item.id === command.courseId);
      if (actor.role !== "student" || actor.id !== student?.id || !course?.published) return reject("只能由學生明確加入已公開的課程。");
      if (student.joinedCourseIds.includes(course.id)) return reject("已加入這套課程。");
      student.joinedCourseIds.push(course.id);
      student.progress.push({ courseId: course.id, stage: 1, moduleId: "m1", lessonId: "l1", activity: "learn", selfCompleted: [], practiced: [], verified: [] });
      audit("加入示意課程", course.id, "學生明確選擇加入", false, true);
      return succeed(course.id);
    }
    case "setStudentScenario": {
      const student = state.students.find((item) => item.id === command.studentId);
      if (actor.role !== "student" || actor.id !== student?.id) return reject("情境只能調整目前的示意學生。");
      if (command.membership) student.membership = command.membership;
      if (command.serviceEligibility) student.serviceEligibility = command.serviceEligibility;
      if (command.joined !== undefined) {
        student.joinedCourseIds = command.joined ? ["c1"] : [];
        if (!command.joined) student.progress = [];
        else if (!student.progress.length) student.progress.push({ courseId: "c1", stage: 1, moduleId: "m1", lessonId: "l1", activity: "learn", selfCompleted: [], practiced: [], verified: [] });
      }
      if (command.access !== undefined) student.accessCourseIds = command.access ? ["c1"] : [];
      return succeed(student.id);
    }
    case "progress": {
      const student = state.students.find((item) => item.id === command.studentId);
      if (actor.role !== "student" || actor.id !== student?.id || !student.joinedCourseIds.includes(command.courseId)) return reject("尚未加入課程，不能產生個人進度。");
      const progress = student.progress.find((item) => item.courseId === command.courseId);
      if (!progress) return reject("尚無個人學習位置。");
      progress.lessonId = command.lessonId;
      if (command.stage) progress.stage = command.stage;
      if (command.moduleId) progress.moduleId = command.moduleId;
      if (command.activity) progress.activity = command.activity;
      if (command.selfComplete !== undefined) progress.selfCompleted = command.selfComplete ? [...new Set([...progress.selfCompleted, command.lessonId])] : progress.selfCompleted.filter((item) => item !== command.lessonId);
      if (command.practiceId) progress.practiced = progress.practiced.includes(command.practiceId) ? progress.practiced.filter((item) => item !== command.practiceId) : [...progress.practiced, command.practiceId];
      return succeed();
    }
    case "createProposal": {
      if (actor.role !== "teacher") return reject("老師才能建立自己的提案。");
      const base = state.courses.find((item) => item.id === command.baseCourseId);
      if (command.baseCourseId && (!base?.published || base.teacherId !== actor.id)) return reject("只能對自己參與的公開課程提案。");
      const proposal: Proposal = { id: id("proposal"), teacherId: actor.id, baseCourseId: base?.id ?? null, baseRevision: base?.revision ?? 0, revision: 1, status: "draft", content: clone(base?.published ?? emptyCourse()), audience: "", rightsNote: "", proRequested: false, snapshot: null, reviewNote: "", importedCourseId: null };
      state.proposals.push(proposal); return succeed(proposal.id);
    }
    case "saveProposal": {
      const proposal = state.proposals.find((item) => item.id === command.id);
      if (actor.role !== "teacher" || proposal?.teacherId !== actor.id || !["draft", "changes"].includes(proposal.status)) return reject("這份送審快照不可修改；請另開修訂版本。");
      if (!command.content.title.trim() || !positive(command.content.price)) return reject("請填名稱；價格可留空或填正整數。");
      Object.assign(proposal, { content: clone(command.content), audience: command.audience, rightsNote: command.rightsNote, proRequested: command.proRequested }); return succeed(proposal.id);
    }
    case "submitProposal": {
      const proposal = state.proposals.find((item) => item.id === command.id);
      if (actor.role !== "teacher" || proposal?.teacherId !== actor.id || !["draft", "changes"].includes(proposal.status)) return reject("只能送出自己的可編輯提案。");
      if (!proposal.content.title.trim() || !proposal.content.objective.trim() || !proposal.content.outline.trim() || !proposal.audience.trim() || !proposal.rightsNote.trim()) return reject("請補齊成果、對象、課綱與素材權利說明。");
      if (!command.rightsConfirmed || !policiesAccepted(state, actor)) return reject("請先閱讀目前老師守則，並確認素材權利。");
      proposal.snapshot = clone({ content: proposal.content, audience: proposal.audience, rightsNote: proposal.rightsNote, proRequested: proposal.proRequested }); proposal.status = "review";
      audit("送出課程提案", proposal.id, "確認目前守則與素材權利", "draft", proposal.snapshot); return succeed(proposal.id);
    }
    case "reviseProposal": {
      const proposal = state.proposals.find((item) => item.id === command.id);
      if (actor.role !== "teacher" || proposal?.teacherId !== actor.id) return reject("只能修訂自己的提案。");
      const next = { ...clone(proposal), id: id("proposal"), revision: proposal.revision + 1, status: "draft" as const, snapshot: null, reviewNote: "", importedCourseId: null };
      if (proposal.status === "review") proposal.status = "superseded";
      state.proposals.push(next); return succeed(next.id);
    }
    case "reviewProposal": {
      const proposal = state.proposals.find((item) => item.id === command.id);
      if (!canOperate(actor) || proposal?.status !== "review" || !proposal.snapshot || !confirm(command)) return reject("需營運權限、待審提案、原因與確認。");
      if (command.expectedSnapshot !== undefined && JSON.stringify(proposal.snapshot) !== command.expectedSnapshot) return reject("送審快照已改變，請重新檢視後再確認。");
      if (command.decision === "return") { proposal.status = "changes"; proposal.reviewNote = command.reason; proposal.revision++; audit("退回提案補充", proposal.id, command.reason, "review", "changes"); return succeed(proposal.id); }
      let course = state.courses.find((item) => item.id === proposal.baseCourseId);
      if (proposal.baseCourseId && (!course || course.revision !== proposal.baseRevision || course.status === "draft")) return reject("正式版本或平台草稿已變動，請先退回重新對照。");
      if (!course) { course = { id: id("course"), teacherId: proposal.teacherId, draft: emptyCourse(), published: null, status: "draft", revision: 0, draftRevision: 0, policy: emptyPolicy(), draftPolicy: emptyPolicy() }; state.courses.push(course); }
      course.draft = clone(proposal.snapshot.content); course.draftRevision++; course.status = "draft"; course.proposalId = proposal.id;
      proposal.status = "imported"; proposal.importedCourseId = course.id; proposal.reviewNote = command.reason;
      audit("接受提案並匯入草稿", proposal.id, command.reason, "review", { courseId: course.id, published: false }); return succeed(course.id);
    }
    case "createCourse": {
      if (!canOperate(actor)) return reject("正式課程僅由平台營運或負責人建立。");
      const course: Course = { id: id("course"), teacherId: "t1", draft: emptyCourse(), published: null, status: "draft", revision: 0, draftRevision: 1, policy: emptyPolicy(), draftPolicy: emptyPolicy() };
      state.courses.push(course); return succeed(course.id);
    }
    case "saveCourse": {
      const course = state.courses.find((item) => item.id === command.id);
      if (!canOperate(actor) || !course || !reasonValid(command.reason)) return reject("正式課程編輯需平台權限及原因。");
      if (!command.content.title.trim() || !command.content.outline.trim() || !positive(command.content.price)) return reject("請填名稱、課綱及有效價格；未定价格可留空。");
      if ((command.policy.plusAccess || command.policy.proReview) && !command.policy.included) return reject("會員存取或 Pro 指導需先納入會員目錄。");
      const before = clone(course.draft); course.draft = clone(command.content); course.draftPolicy = clone(command.policy); course.draftRevision++; course.status = "draft";
      audit("儲存課程草稿", course.id, command.reason, before, course.draft); return succeed(course.id);
    }
    case "publishCourse": {
      const course = state.courses.find((item) => item.id === command.id);
      if (!canOperate(actor) || !course || course.status !== "draft" || !confirm(command) || course.draftRevision !== command.expectedRevision) return reject("需平台權限與未發布草稿；草稿變更後必須重新預覽。");
      if (!course.draft.title.trim() || !course.draft.outline.trim()) return reject("課程名稱與課綱不可空白。");
      const proposal = state.proposals.find((item) => item.id === course.proposalId);
      if (proposal && !["imported", "published"].includes(proposal.status)) return reject("此提案已失效，不能發布。");
      const before = clone(course.published); course.published = clone(course.draft); course.policy = clone(course.draftPolicy); course.revision++; course.status = "published";
      if (proposal) proposal.status = "published";
      audit("發布示意課程版本", course.id, command.reason, before, course.published); return succeed(course.id);
    }
    default: return executeWorkflowCommand(original, state, actor, command, { id, audit, succeed, reject, confirm });
  }
}

type WorkflowCommand = Exclude<Command, { type: "joinCourse" | "setStudentScenario" | "progress" | "createProposal" | "saveProposal" | "submitProposal" | "reviseProposal" | "reviewProposal" | "createCourse" | "saveCourse" | "publishCourse" }>;
type Context = { id: (prefix: string) => string; audit: (action: string, target: string, reason: string, before: unknown, after: unknown, sensitive?: boolean) => number; succeed: (id?: string) => { state: PrototypeState; result: CommandResult }; reject: (error: string) => { state: PrototypeState; result: CommandResult }; confirm: (value: Confirmed) => boolean };
function executeWorkflowCommand(original: PrototypeState, state: PrototypeState, actor: Actor, command: WorkflowCommand, ctx: Context): { state: PrototypeState; result: CommandResult } {
  const { id, audit, succeed, reject, confirm } = ctx;
  switch (command.type) {
    case "saveOffer": {
      if (actor.role !== "teacher" || !command.content.title.trim() || !Number.isInteger(command.content.count) || command.content.count < 1 || command.content.count > 1000 || !positive(command.content.unitPrice)) return reject("請填有效的課程包名稱、堂數與單價。");
      if (command.content.targetStudentId && !state.students.some((student) => student.id === command.content.targetStudentId && student.teacherId === actor.id)) return reject("客製報價只能指定自己的學生。");
      let offer = state.offers.find((item) => item.id === command.id);
      if (command.id && offer?.teacherId !== actor.id) return reject("只能編輯自己的價格提案。");
      if (!offer) { offer = { id: id("offer"), teacherId: actor.id, draft: clone(command.content), published: null, status: "draft", version: 0 }; state.offers.push(offer); }
      offer.draft = clone(command.content); offer.status = offer.reviewSnapshot ? "review" : "draft"; return succeed(offer.id);
    }
    case "submitOffer": {
      const offer = state.offers.find((item) => item.id === command.id);
      if (actor.role !== "teacher" || offer?.teacherId !== actor.id || !policiesAccepted(state, actor)) return reject("請先閱讀老師守則，只送出自己的價格提案。");
      offer.reviewSnapshot = clone(offer.draft); offer.status = "review"; audit("送審課程包", offer.id, "老師提出新價格版本", null, offer.reviewSnapshot); return succeed(offer.id);
    }
    case "publishOffer": {
      const offer = state.offers.find((item) => item.id === command.id);
      if (!canOperate(actor) || !offer?.reviewSnapshot || !confirm(command)) return reject("需平台權限、待審版本、原因與確認。");
      if (command.expectedSnapshot !== undefined && JSON.stringify(offer.reviewSnapshot) !== command.expectedSnapshot) return reject("價格送審快照已改變，請重新檢視。");
      const before = clone(offer.published); offer.published = clone(offer.reviewSnapshot); offer.status = JSON.stringify(offer.draft) === JSON.stringify(offer.reviewSnapshot) ? "published" : "draft"; offer.reviewSnapshot = null; offer.version++;
      audit("發布示意課程包", offer.id, command.reason, before, offer.published); return succeed(offer.id);
    }
    case "saveProfile": {
      const teacher = state.teachers.find((item) => item.id === command.teacherId);
      if (actor.role !== "teacher" || teacher?.id !== actor.id || !command.profile.name.trim()) return reject("只能編輯自己的展示草稿，姓名不可空白。");
      teacher.draft = clone(command.profile); teacher.status = teacher.reviewSnapshot ? "review" : "draft"; return succeed(teacher.id);
    }
    case "submitProfile": {
      const teacher = state.teachers.find((item) => item.id === command.teacherId);
      if (actor.role !== "teacher" || teacher?.id !== actor.id) return reject("只能送審自己的展示頁。");
      teacher.reviewSnapshot = clone(teacher.draft); teacher.status = "review"; audit("送審老師展示頁", teacher.id, "老師確認草稿", null, teacher.reviewSnapshot); return succeed(teacher.id);
    }
    case "publishProfile": {
      const teacher = state.teachers.find((item) => item.id === command.teacherId);
      if (!canOperate(actor) || !teacher?.reviewSnapshot || !confirm(command)) return reject("需平台權限、待審展示頁、原因與確認。");
      if (command.expectedSnapshot !== undefined && JSON.stringify(teacher.reviewSnapshot) !== command.expectedSnapshot) return reject("老師展示送審快照已改變，請重新檢視。");
      const before = clone(teacher.published); teacher.published = clone(teacher.reviewSnapshot); teacher.featured = command.featured; teacher.status = JSON.stringify(teacher.draft) === JSON.stringify(teacher.reviewSnapshot) ? "published" : "draft"; teacher.reviewSnapshot = null;
      audit("發布示意展示頁", teacher.id, command.reason, before, teacher.published); return succeed(teacher.id);
    }
    case "rejectContent": {
      const content = command.kind === "profile" ? state.teachers.find((item) => item.id === command.id) : command.kind === "offer" ? state.offers.find((item) => item.id === command.id) : state.articles.find((item) => item.id === command.id);
      if (!canOperate(actor) || !content?.reviewSnapshot || !confirm(command)) return reject("退回需平台內容權限、待審快照、原因與確認。");
      if (command.expectedSnapshot !== undefined && JSON.stringify(content.reviewSnapshot) !== command.expectedSnapshot) return reject("送審快照已改變，請重新檢視再退回。");
      content.reviewSnapshot = null; content.status = "draft";
      audit("退回內容補充", command.id, command.reason, "review", { status: "draft", kind: command.kind }); return succeed(command.id);
    }
    case "setTeacherFeatured": {
      const teacher = state.teachers.find((item) => item.id === command.teacherId);
      if (!canOperate(actor) || !teacher?.published || !confirm(command)) return reject("首頁展示需已發布老師資料、平台權限、原因與確認。");
      const before = teacher.featured; teacher.featured = command.featured;
      audit("調整示意首頁師資展示", teacher.id, command.reason, before, teacher.featured); return succeed(teacher.id);
    }
    case "grantPackage": {
      const student = state.students.find((item) => item.id === command.studentId), offer = state.offers.find((item) => item.id === command.offerId);
      if (!canOperate(actor) || !student || !offer?.published || !confirm(command)) return reject("需學生、公開課程包、平台權限、原因與確認。");
      if ((offer.published.targetStudentId && offer.published.targetStudentId !== student.id) || (offer.published.mode !== "both" && offer.published.mode !== command.mode)) return reject("指定學生或排課方式不符合這份課程包。");
      if (!validDate(command.expiry) || new Date(command.expiry + "T23:59:59Z") <= new Date(state.clock)) return reject("請設定有效的未來截止日。");
      const pack: StudentPackage = { id: id("package"), studentId: student.id, teacherId: offer.teacherId, offerId: offer.id, offerVersion: offer.version, snapshot: clone(offer.published), mode: command.mode, expiry: command.expiry, source: command.source, status: "active" };
      state.packages.push(pack); state.ledger.push({ id: id("credit"), packageId: pack.id, kind: "allocate", quantity: pack.snapshot.count, label: command.reason });
      audit("人工新增示意權益", pack.id, command.reason, null, { studentId: student.id, count: pack.snapshot.count, paymentCreated: false }); return succeed(pack.id);
    }
    case "book": {
      const pack = state.packages.find((item) => item.id === command.packageId), slot = availableSlots(state, command.packageId, actor).find((item) => item.id === command.slotId);
      if (!pack || !slot || !confirm(command) || !reasonValid(command.consent) || !command.policyConfirmed) return reject("需有效堂數、無衝突時段、具體同意依據、原因與再次確認。");
      if (actor.role === "teacher" && !policiesAccepted(state, actor)) return reject("老師須先閱讀目前版本守則。");
      const booking: Booking = { id: id("booking"), studentId: pack.studentId, teacherId: pack.teacherId, packageId: pack.id, start: slot.start, end: slot.end, mode: pack.mode, format: "online", status: "reserved", createdBy: actor.id, consent: command.consent, reason: command.reason };
      state.bookings.push(booking); state.ledger.push({ id: id("credit"), packageId: pack.id, kind: "reserve", quantity: 1, bookingId: booking.id, label: "示意預約，只預留堂數" });
      audit("線上示意預約", booking.id, command.reason, balance(original, pack.id), balance(state, pack.id)); return succeed(booking.id);
    }
    case "reschedule": {
      const booking = state.bookings.find((item) => item.id === command.bookingId);
      if (!booking || booking.status !== "reserved" || !canOperate(actor) || !confirm(command) || !reasonValid(command.consent)) return reject("改期需平台權限、同意依據、原因與確認。");
      const slot = availableSlots(state, booking.packageId, actor, booking.id).find((item) => item.id === command.slotId);
      if (!slot) return reject("時段不相容或已衝突。");
      const before = clone(booking); booking.start = slot.start; booking.end = slot.end; booking.consent = command.consent;
      audit("示意改期", booking.id, command.reason, before, booking); return succeed(booking.id);
    }
    case "cancelBooking": {
      const booking = state.bookings.find((item) => item.id === command.bookingId);
      if (!booking || booking.status !== "reserved" || !canOperate(actor) || !confirm(command)) return reject("取消需平台權限、有效預約、原因與確認。");
      booking.status = "cancelled"; state.ledger.push({ id: id("credit"), packageId: booking.packageId, kind: "release", quantity: 1, bookingId: booking.id, label: command.reason });
      audit("取消示意預約", booking.id, command.reason, "reserved", "cancelled"); return succeed(booking.id);
    }
    case "submitGuidance": {
      const gate = guidanceEligibility(state, command.studentId, command.courseId);
      if (actor.role !== "student" || actor.id !== command.studentId || !gate.allowed) return reject(gate.reason);
      if (!command.question.trim() || !command.mediaName.trim()) return reject("請填練習問題並選擇示意影片。");
      const submission: Submission = { id: id("submission"), studentId: actor.id, teacherId: null, kind: "pro", courseId: command.courseId, lessonId: command.lessonId, title: command.title || "本次練習指導", question: command.question, submittedAt: state.clock, duration: "本地示意", mediaName: command.mediaName, status: "submitted" };
      state.submissions.push(submission); audit("提交示意指導", submission.id, "學生明確提交，不扣正式額度", null, submission); return succeed(submission.id);
    }
    case "assignSubmission": {
      const submission = state.submissions.find((item) => item.id === command.submissionId), teacher = state.teachers.find((item) => item.id === command.teacherId);
      if (!canOperate(actor) || submission?.kind !== "pro" || submission.status === "replied" || !teacher?.canReview || !reasonValid(command.reason)) return reject("需平台權限、有能力的老師及指派原因。");
      const previous = submission.teacherId; submission.teacherId = teacher.id; submission.status = "assigned";
      audit("指派 Pro 示意回饋", submission.id, command.reason, previous, teacher.id); return succeed(submission.id);
    }
    case "saveTeachingDraft": {
      const ownTarget = command.kind === "review"
        ? state.submissions.some((submission) => submission.id === command.targetId && submission.teacherId === actor.id && submission.status !== "replied")
        : state.bookings.some((booking) => booking.id === command.targetId && booking.teacherId === actor.id);
      if (actor.role !== "teacher" || !ownTarget) return reject("只能保存自己作業或課次的教學草稿。");
      const key = `${actor.id}:${command.kind}:${command.targetId}`;
      state.teachingDrafts = state.teachingDrafts.filter((draft) => draft.key !== key);
      state.teachingDrafts.push({ key, teacherId: actor.id, kind: command.kind, targetId: command.targetId, observation: command.observation, nextPractice: command.nextPractice });
      return succeed(key);
    }
    case "reply": {
      const submission = visibleSubmissions(state, actor).find((item) => item.id === command.submissionId);
      if (actor.role !== "teacher" || submission?.teacherId !== actor.id || submission.status === "replied") return reject("只能回覆自己關係內或平台指派的未回覆作業。");
      if (!command.observation.trim() || !command.nextPractice.trim()) return reject("請填觀察與下一次可執行的練習。");
      const feedback: Feedback = { id: id("feedback"), submissionId: submission.id, studentId: submission.studentId, teacherId: actor.id, observation: command.observation, nextPractice: command.nextPractice, privateNote: command.privateNote, createdAt: state.clock };
      state.feedback.push(feedback); submission.status = "replied";
      state.teachingDrafts = state.teachingDrafts.filter((draft) => draft.key !== `${actor.id}:review:${submission.id}`);
      audit("送出老師示意回饋", submission.id, "老師確認回覆，私人備註不送學生", "assigned", "replied"); return succeed(feedback.id);
    }
    case "saveLessonRecord": {
      const booking = state.bookings.find((item) => item.id === command.bookingId);
      if (actor.role !== "teacher" || booking?.teacherId !== actor.id) return reject("只能記錄自己的教學資訊。");
      let record = state.lessonRecords.find((item) => item.bookingId === booking.id);
      if (!record) { record = { id: id("record"), bookingId: booking.id, teacherId: actor.id, studentId: booking.studentId, publicNote: "", privateNote: "", practice: "" }; state.lessonRecords.push(record); }
      Object.assign(record, { publicNote: command.publicNote, privateNote: command.privateNote, practice: command.practice });
      state.teachingDrafts = state.teachingDrafts.filter((draft) => draft.key !== `${actor.id}:lesson:${booking.id}`);
      audit("保存教學紀錄", record.id, "只保存筆記，不完成上課或消耗堂數", null, { bookingId: booking.id }); return succeed(record.id);
    }
    case "createArticle": {
      if (!canOperate(actor)) return reject("文章需平台內容權限。");
      const article: Article = { id: id("article"), draft: { title: "新文章草稿", slug: "", category: "練習筆記", summary: "", body: "" }, published: null, status: "draft", revision: 0, reviewSnapshot: null };
      state.articles.push(article); return succeed(article.id);
    }
    case "saveArticle": {
      const article = state.articles.find((item) => item.id === command.id);
      if (!canOperate(actor) || !article || !command.content.title.trim() || !/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(command.content.slug)) return reject("需內容權限、標題及英數連字號網址。");
      if (state.articles.some((item) => item.id !== article.id && (item.draft.slug === command.content.slug || item.published?.slug === command.content.slug))) return reject("文章網址已被使用。");
      article.draft = clone(command.content); article.status = "draft"; return succeed(article.id);
    }
    case "submitArticle": {
      const article = state.articles.find((item) => item.id === command.id);
      if (!canOperate(actor) || !article || !article.draft.body.trim() || !article.draft.slug) return reject("請填完整文章再送審。");
      article.reviewSnapshot = clone(article.draft); article.status = "review"; return succeed(article.id);
    }
    case "publishArticle": {
      const article = state.articles.find((item) => item.id === command.id);
      if (!canOperate(actor) || article?.status !== "review" || !article.reviewSnapshot || !confirm(command)) return reject("需要待審文章、內容權限、原因與確認。");
      if (command.expectedSnapshot !== undefined && JSON.stringify(article.reviewSnapshot) !== command.expectedSnapshot) return reject("文章送審快照已改變，請重新檢視。");
      const before = clone(article.published); article.published = clone(article.reviewSnapshot); article.status = "published"; article.revision++;
      audit("發布示意文章", article.id, command.reason, before, article.published); return succeed(article.id);
    }
    case "ackPolicy": {
      const policy = state.policies.find((item) => item.id === command.policyId);
      if (!policy || policy.audience !== actor.role) return reject("只能標記目前身分的守則。");
      state.acknowledgements = state.acknowledgements.filter((ack) => !(ack.actorId === actor.id && ack.policyId === policy.id));
      state.acknowledgements.push({ actorId: actor.id, policyId: policy.id, version: policy.version }); return succeed(policy.id);
    }
    case "savePolicy": {
      const policy = state.policies.find((item) => item.id === command.id);
      if (!canOperate(actor) || !policy || !command.title.trim() || !command.body.trim() || !command.version.trim() || policy.usedVersions.includes(command.version) || !reasonValid(command.reason)) return reject("請填新版本、完整條文與修訂原因，不能重用舊版號。");
      policy.draft = { title: command.title, body: command.body, version: command.version }; return succeed(policy.id);
    }
    case "publishPolicy": {
      const policy = state.policies.find((item) => item.id === command.id);
      if (!canOperate(actor) || !policy?.draft || !confirm(command) || policy.usedVersions.includes(policy.draft.version)) return reject("需新守則草稿、原因及確認。");
      const before = { version: policy.version, body: policy.body }; Object.assign(policy, clone(policy.draft)); policy.usedVersions.push(policy.version); policy.draft = null;
      audit("發布示意守則版本", policy.id, command.reason, before, { version: policy.version, body: policy.body }); return succeed(policy.id);
    }
    case "prepareSettlement": {
      if (!canFinance(actor) || !reasonValid(command.reason)) return reject("需財務權限及核對原因。");
      const rows = state.earnings.filter((earning) => earning.teacherId === command.teacherId && earning.month === command.month && earning.status === "ready");
      if (!rows.length || state.settlements.some((settlement) => settlement.status !== "paid" && settlement.earningIds.some((earningId) => rows.some((row) => row.id === earningId)))) return reject("沒有可準備的報酬，或已有待處理結算單。");
      const settlement: Settlement = { id: id("settlement"), teacherId: command.teacherId, month: command.month, earningIds: rows.map((row) => row.id), total: rows.reduce((sum, row) => sum + (row.amount ?? 0), 0), status: "prepared", reason: command.reason };
      state.settlements.push(settlement); audit("準備示意結算單", settlement.id, command.reason, null, settlement, true); return succeed(settlement.id);
    }
    case "approveSettlement": {
      const settlement = state.settlements.find((item) => item.id === command.id);
      if (actor.role !== "admin" || actor.capability !== "owner" || settlement?.status !== "prepared" || !confirm(command)) return reject("結算需平台負責人覆核，準備不等於核准。");
      const rows = state.earnings.filter((earning) => settlement.earningIds.includes(earning.id));
      if (rows.length !== settlement.earningIds.length || rows.some((row) => row.status !== "ready") || rows.reduce((sum, row) => sum + (row.amount ?? 0), 0) !== settlement.total) return reject("報酬資料已變，請重新核對。");
      settlement.status = "approved"; rows.forEach((row) => { row.status = "approved"; }); audit("負責人覆核示意結算", settlement.id, command.reason, "prepared", "approved", true); return succeed(settlement.id);
    }
    case "recordPayout": {
      const settlement = state.settlements.find((item) => item.id === command.id);
      if (!canFinance(actor) || settlement?.status !== "approved" || !confirm(command) || !/^DEMO-[A-Za-z0-9-]{3,60}$/.test(command.proof) || state.earnings.some((earning) => earning.proof === command.proof)) return reject("需已覆核結算、未用過的 DEMO- 憑證與確認。");
      const rows = state.earnings.filter((earning) => settlement.earningIds.includes(earning.id));
      if (rows.some((row) => row.status !== "approved")) return reject("報酬狀態已變。");
      settlement.status = "paid"; settlement.proof = command.proof; rows.forEach((row) => { row.status = "paid"; row.proof = command.proof; row.paidAt = state.clock.slice(0, 10); });
      audit("登記虛構撥款憑證", settlement.id, command.reason, "approved", { proof: command.proof, actualTransfer: false }, true); return succeed(settlement.id);
    }
    case "saveFinanceDraft": {
      const values = [command.base, ...command.allocations], allocated = command.allocations.reduce((sum, value) => sum + value, 0);
      if (!canFinance(actor) || !command.name.trim() || !command.scope.trim() || !reasonValid(command.reason) || !validDate(command.effective) || command.effective < state.clock.slice(0, 10) || values.some((value) => !Number.isSafeInteger(value) || value < 0) || allocated > command.base) return reject("請填完整假設、適用範圍、未來日期與原因；分配不可超過基礎。");
      const draft: FinanceDraft = { id: id("finance-draft"), name: command.name, scope: command.scope, kind: command.kind, effective: command.effective, base: command.base, allocations: clone(command.allocations), unallocated: command.base - allocated, reason: command.reason, status: "draft" };
      state.financeDrafts.push(draft); audit("保存未核准分潤假設", draft.id, command.reason, null, draft, true); return succeed(draft.id);
    }
    case "earningInquiry": {
      const earning = visibleEarnings(state, actor).find((item) => item.id === command.earningId);
      if (!earning || !reasonValid(command.reason)) return reject("只能查詢可查看的報酬，請填原因。");
      audit("報酬查詢", earning.id, command.reason, earning.amount, earning.amount, true); return succeed(earning.id);
    }
    case "openOversight": {
      if (!canOperate(actor) || !state.students.some((student) => student.id === command.studentId) || !reasonValid(command.reason)) return reject("敏感檢視需指定學生、必要理由與內容權限。");
      state.oversightAccess = state.oversightAccess.filter((access) => access.actorId !== actor.id);
      state.oversightAccess.push({ actorId: actor.id, studentId: command.studentId, reason: command.reason }); audit("開啟受控示意互動", command.studentId, command.reason, "masked", "visible"); return succeed(command.studentId);
    }
    case "closeOversight": state.oversightAccess = state.oversightAccess.filter((access) => access.actorId !== actor.id); return succeed();
    case "platformReply": {
      if (!canOperate(actor) || !state.oversightAccess.some((access) => access.actorId === actor.id && access.studentId === command.studentId) || !command.body.trim() || !reasonValid(command.reason)) return reject("先以必要理由開啟指定對象，只能用平台身分回覆。");
      const reply: PlatformReply = { id: id("platform-reply"), studentId: command.studentId, actorId: actor.id, body: command.body, authorLabel: "平台協助" };
      state.platformReplies.push(reply); audit("平台身分示意回覆", command.studentId, command.reason, null, reply); return succeed(reply.id);
    }
    case "addDiscussionComment": {
      const student = state.students.find((item) => item.id === actor.id), course = state.courses.find((item) => item.id === command.courseId);
      if (actor.role !== "student" || !student?.joinedCourseIds.includes(command.courseId) || !course?.published || !command.text.trim()) return reject("加入課程後才可留下非空白的練習討論。");
      const comment: DiscussionComment = { id: id("discussion"), studentId: actor.id, courseId: command.courseId, lessonId: command.lessonId, text: command.text.trim() };
      state.discussionComments.push(comment); return succeed(comment.id);
    }
    case "privatePractice": {
      const student = state.students.find((item) => item.id === command.studentId);
      if (actor.role !== "student" || actor.id !== student?.id || !state.packages.some((pack) => pack.studentId === student.id)) return reject("只能回報自己的私人課練習，不需要加入系統課程。");
      const practiced = student.privatePracticed ?? [];
      student.privatePracticed = practiced.includes(command.practiceId) ? practiced.filter((item) => item !== command.practiceId) : [...practiced, command.practiceId];
      return succeed();
    }
    case "setRosterScenario": {
      if (!canOperate(actor)) return reject("版面情境工具需要本地營運或負責人視角。");
      const teacher = state.teachers.find((item) => item.id === "t1"), offer = state.offers.find((item) => item.id === "p4");
      if (!teacher?.published || !offer?.published) return reject("請先重設示意資料，再使用師資版面情境。");
      if (command.scenario === "empty") state.teachers.forEach((item) => { item.featured = false; });
      if (command.scenario === "no-public-offer") state.offers.filter((item) => item.teacherId === "t1").forEach((item) => { item.published = null; });
      if (command.scenario === "long") {
        teacher.published.name = "The One 很長的中文老師姓名與節奏伴奏教學介紹（排版測試）";
        teacher.published.specialties = "從基本和弦與右手節奏訓練，到歌曲伴奏、切音留白、聽覺理解，以及慢慢建立自己的音樂表達方式";
      }
      if (command.scenario === "missing-image") teacher.published.photo = "/ux-prototype-assets/intentional-missing-portrait.jpg";
      if (command.scenario === "many") {
        for (const index of [2, 3]) {
          const teacherId = `qa-teacher-${index}`, offerId = `qa-offer-${index}`;
          state.teachers = state.teachers.filter((item) => item.id !== teacherId); state.offers = state.offers.filter((item) => item.id !== offerId);
          const profile = { ...clone(teacher.published), name: `排版測試老師 ${index}（非正式師資）`, specialties: index === 2 ? "節奏與歌曲伴奏・QA 示意" : "音樂理解與練習方法・QA 示意" };
          state.teachers.push({ id: teacherId, draft: clone(profile), published: profile, featured: true, status: "published", canReview: false });
          const content = { ...clone(offer.published), title: `排版測試老師 ${index} 專屬課程包`, targetStudentId: null };
          state.offers.push({ id: offerId, teacherId, draft: clone(content), published: content, version: 1, status: "published" });
        }
      }
      audit("套用師資排版情境", command.scenario, "明確的本地 QA 情境；回基準需重設示意資料", null, { scenario: command.scenario }); return succeed();
    }
    case "savePrivateNote": {
      const student = state.students.find((item) => item.id === command.studentId);
      if (actor.role !== "teacher" || student?.teacherId !== actor.id || student.relation !== "private") return reject("私人備註只限自己的私人課學生，不包含單筆平台指派。");
      let note = state.privateNotes.find((item) => item.teacherId === actor.id && item.studentId === student.id);
      if (!note) { note = { id: id("private-note"), teacherId: actor.id, studentId: student.id, text: "" }; state.privateNotes.push(note); }
      note.text = command.text;
      audit("保存老師私人備註", student.id, "自己的私人課關係內備註", null, { noteSaved: true }); return succeed(note.id);
    }
    case "setAvailability": {
      if (actor.role !== "teacher") return reject("老師只能設定自己的本機開放時段。");
      const incoming: Availability[] = command.slots.map((slot) => ({ ...slot, teacherId: actor.id }));
      if (new Set(incoming.map((slot) => slot.id)).size !== incoming.length || incoming.some((slot) => !slot.id.trim() || !Number.isFinite(Date.parse(slot.start)) || !Number.isFinite(Date.parse(slot.end)) || Date.parse(slot.start) <= Date.parse(state.clock) || Date.parse(slot.end) <= Date.parse(slot.start) || state.availability.some((existing) => existing.id === slot.id && existing.teacherId !== actor.id))) return reject("請用不重複的 ID 與有效未來起迄時間，只能修改自己的時段。");
      if (incoming.some((slot, index) => incoming.some((other, otherIndex) => otherIndex > index && Date.parse(slot.start) < Date.parse(other.end) && Date.parse(slot.end) > Date.parse(other.start)))) return reject("老師開放時段不能互相重疊。");
      if (incoming.some((slot) => slot.priorityStudentId && !state.students.some((student) => student.id === slot.priorityStudentId && student.teacherId === actor.id && student.relation === "private"))) return reject("優先時段只能設定給自己的私人課學生。");
      const own = state.availability.filter((slot) => slot.teacherId === actor.id);
      const reserved = own.filter((slot) => state.bookings.some((booking) => booking.teacherId === actor.id && booking.status === "reserved" && slot.start < booking.end && slot.end > booking.start));
      if (reserved.some((slot) => !incoming.some((next) => next.id === slot.id && next.start === slot.start && next.end === slot.end && next.mode === slot.mode))) return reject("已有預約的時段必須保留，不能透過開放時段設定取消或移動預約。");
      state.availability = [...state.availability.filter((slot) => slot.teacherId !== actor.id || Date.parse(slot.start) <= Date.parse(state.clock)), ...incoming];
      audit("保存本機開放時段", actor.id, "老師確認未來線上時段", own, incoming); return succeed();
    }
  }
}

/** Source v1.6 five-answer diagnostic; advisory only, never mutates enrollment. */
export function diagnosisRecommendation(answers: readonly string[]) {
  const [level, goal, time, obstacle, support] = answers;
  const beginner = level === "new" || level === "chords";
  const focus = level === "new" ? "從穩定的第一個和弦開始" : obstacle === "beat" ? "先讓節奏穩下來" : obstacle === "hands" ? "把卡住的動作拆小一點" : goal === "theory" || obstacle === "understand" ? "把和弦與音樂理解接起來" : goal === "rhythm" ? "讓伴奏開始有變化" : goal === "freedom" ? "從小段旋律，練習自己的表達" : "把一首歌，慢慢接起來";
  const entry = beginner ? "基礎與第一首歌" : goal === "theory" || obstacle === "understand" ? "和弦與音樂理解" : "節奏與伴奏變化";
  const mins = ["10", "20", "30"].includes(time) ? Number(time) : 10;
  const parts = [Math.round(mins * 0.2), Math.round(mins * 0.5)]; parts.push(mins - parts[0] - parts[1]);
  return { focus, entry, mins, parts, support, practice: beginner ? ["找一個熟悉或容易按的和弦，慢慢彈清楚。", "只練一個小動作，維持舒服、不急的速度。", "把剛才的動作放進兩小節，觀察哪裡最容易停住。"] : ["先聽或彈一遍短片段，找出現在的卡點。", "把片段拆成兩小節，只處理一個節奏或轉換。", "把兩小節接起來，留一句下次想改善的筆記。"] };
}
