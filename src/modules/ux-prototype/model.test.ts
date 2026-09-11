import { describe, expect, it } from "vitest";
import { createFixtures } from "./fixtures";
import { availableSlots, balance, diagnosisRecommendation, executeCommand, guidanceEligibility, policiesAccepted, publicOffers, publicTeachers, studentBookings, visibleAudit, visibleEarnings, visibleFeedback, visibleSubmissions, visibleTeachingDrafts, type Actor, type Command, type PrototypeState } from "./model";

const teacher: Actor = { role: "teacher", id: "t1" };
const otherTeacher: Actor = { role: "teacher", id: "t2" };
const owner: Actor = { role: "admin", id: "admin-owner", capability: "owner" };
const ops: Actor = { role: "admin", id: "admin-ops", capability: "ops" };
const finance: Actor = { role: "admin", id: "admin-finance", capability: "finance" };
const student: Actor = { role: "student", id: "s1" };
function run(state: PrototypeState, actor: Actor, command: Command) {
  const outcome = executeCommand(state, actor, command);
  expect(outcome.result, command.type).toMatchObject({ ok: true });
  return outcome;
}
function acceptedTeacher() {
  let state = createFixtures();
  for (const policy of state.policies.filter((item) => item.audience === "teacher")) state = run(state, teacher, { type: "ackPolicy", policyId: policy.id }).state;
  return state;
}
function submittedProposal() {
  let state = acceptedTeacher();
  const created = run(state, teacher, { type: "createProposal" }); state = created.state;
  const id = created.result.id!;
  state = run(state, teacher, { type: "saveProposal", id, content: { ...state.courses[0].draft, title: "新內容提案", objective: "同一首歌曲練習兩種伴奏" }, audience: "想改善節奏的學生", rightsNote: "本地示意原創教材，未上傳任何檔案", proRequested: true }).state;
  state = run(state, teacher, { type: "submitProposal", id, rightsConfirmed: true }).state;
  return { state, id };
}
const bookingCommand: Command = { type: "book", packageId: "e-an", slotId: "s1", consent: "學生已確認 9/10 20:00", reason: "學生請老師協助預約", policyConfirmed: true, confirmed: true, requestId: "booking-click-1" };

describe("native UX shared fixture boundaries", () => {
  it("keeps teacher drafts across commands without publishing, and clears only the submitted target", () => {
    const initial = createFixtures();
    const draft: Command = { type: "saveTeachingDraft", kind: "review", targetId: "r1", observation: "先保留觀察草稿", nextPractice: "" };
    let state = run(initial, teacher, draft).state;
    state = run(state, teacher, { ...draft, observation: "更新同一份觀察草稿", nextPractice: "先慢速練四小節" }).state;
    state = run(state, teacher, { ...draft, kind: "lesson", targetId: "ab1" }).state;
    expect(state.teachingDrafts).toHaveLength(2);
    expect(state.feedback).toEqual(initial.feedback);
    expect(state.lessonRecords).toEqual(initial.lessonRecords);
    expect(state.ledger).toEqual(initial.ledger);
    expect(visibleTeachingDrafts(state, otherTeacher)).toEqual([]);
    expect(visibleTeachingDrafts(state, student)).toEqual([]);
    for (const actor of [otherTeacher, student, owner]) expect(executeCommand(state, actor, draft).result.ok).toBe(false);
    state = run(state, teacher, { type: "reply", submissionId: "r1", observation: "右手維持擺動", nextPractice: "用60BPM練四小節", privateNote: "不給學生的備註" }).state;
    expect(state.teachingDrafts.map((item) => item.key)).toEqual(["t1:lesson:ab1"]);
    expect(executeCommand(state, teacher, draft).result.ok).toBe(false);
    state = run(state, teacher, { type: "saveLessonRecord", bookingId: "ab1", publicNote: "課後摘要", practice: "四小節練習", privateNote: "" }).state;
    expect(state.teachingDrafts).toEqual([]);
    expect(state.ledger).toEqual(initial.ledger);
  });
  it("retains source identities, filters unpublished staff and targeted prices", () => {
    const state = createFixtures();
    expect(state.students.map((item) => item.sourceId)).toEqual(["yu", "an", "qing"]);
    expect(publicTeachers(state).map((item) => item.id)).toEqual(["t1"]);
    state.offers.push({ ...structuredClone(state.offers[0]), id: "private-quote", published: { ...state.offers[0].draft, targetStudentId: "s1" } });
    expect(publicOffers(state, "t1")).toHaveLength(4);
    expect(publicOffers(state, "t2")).toHaveLength(0);
    state.teachers[0].featured = false;
    expect(publicTeachers(state)).toHaveLength(0);
  });
  it("exposes explicit 0/3/long/missing/no-offer fixture states without merging teacher identities", () => {
    const many = run(createFixtures(), owner, { type: "setRosterScenario", scenario: "many" }).state;
    expect(publicTeachers(many).map((item) => item.id)).toEqual(["t1", "qa-teacher-2", "qa-teacher-3"]);
    for (const teacher of publicTeachers(many)) expect(publicOffers(many, teacher.id).every((offer) => offer.teacherId === teacher.id)).toBe(true);
    expect(publicTeachers(run(createFixtures(), owner, { type: "setRosterScenario", scenario: "empty" }).state)).toEqual([]);
    expect(publicTeachers(run(createFixtures(), owner, { type: "setRosterScenario", scenario: "no-public-offer" }).state)).toEqual([]);
    expect(run(createFixtures(), owner, { type: "setRosterScenario", scenario: "long" }).state.teachers[0].published?.name.length).toBeGreaterThan(30);
    expect(run(createFixtures(), owner, { type: "setRosterScenario", scenario: "missing-image" }).state.teachers[0].published?.photo).toContain("missing");
    expect(executeCommand(createFixtures(), otherTeacher, { type: "saveProfile", teacherId: "t1", profile: createFixtures().teachers[0].draft }).result.ok).toBe(false);
  });
  it("keeps diagnosis advisory and different answer sets produce different advice", () => {
    const state = createFixtures(), baseline = structuredClone(state);
    const a = diagnosisRecommendation(["new", "song", "10", "direction", "self"]);
    const b = diagnosisRecommendation(["songs", "theory", "30", "understand", "review"]);
    expect(a.focus).not.toEqual(b.focus);
    expect(b.parts.reduce((total, value) => total + value, 0)).toBe(30);
    expect(state).toEqual(baseline);
  });
  it("explicit enrollment starts at zero without purchasing, upgrading or granting access", () => {
    const before = createFixtures();
    const after = run(before, { role: "student", id: "s2" }, { type: "joinCourse", studentId: "s2", courseId: "c1" }).state;
    expect(before.students[1].joinedCourseIds).toEqual([]);
    expect(after.students[1].membership).toBe("Free");
    expect(after.students[1].accessCourseIds).toEqual([]);
    expect(after.students[1].progress[0].selfCompleted).toEqual([]);
    expect(after.cashEvents).toEqual(before.cashEvents);
    expect(after.packages).toEqual(before.packages);
  });
  it("self reports never become verification or certificates", () => {
    const state = run(createFixtures(), student, { type: "progress", studentId: "s1", courseId: "c1", lessonId: "l3", selfComplete: true }).state;
    expect(state.students[0].progress[0].selfCompleted).toContain("l3");
    expect(state.students[0].progress[0].verified).toEqual([]);
    const rejected = executeCommand(state, { role: "student", id: "s2" }, { type: "progress", studentId: "s2", courseId: "c1", lessonId: "l3", selfComplete: true });
    expect(rejected.result.ok).toBe(false);
    expect(rejected.state).toBe(state);
  });
  it("does not permit another student to alter one's progress or scenario", () => {
    const state = createFixtures();
    expect(executeCommand(state, { role: "student", id: "s2" }, { type: "progress", studentId: "s1", courseId: "c1", lessonId: "l4" }).result.ok).toBe(false);
    expect(executeCommand(state, teacher, { type: "setStudentScenario", studentId: "s1", membership: "Free" }).result.ok).toBe(false);
  });
  it("shares private practice even when the student never joined the system course", () => {
    const after = run(createFixtures(), { role: "student", id: "s2" }, { type: "privatePractice", studentId: "s2", practiceId: "rhythm-60" }).state;
    expect(after.students[1].privatePracticed).toEqual(["rhythm-60"]);
    expect(after.students[1].joinedCourseIds).toEqual([]);
    expect(executeCommand(after, student, { type: "privatePractice", studentId: "s2", practiceId: "rhythm-60" }).result.ok).toBe(false);
  });
});

describe("proposal → import → previewed official publication", () => {
  it("requires current policies and material-rights confirmation before immutable submission", () => {
    const { state, id } = submittedProposal();
    expect(state.proposals[0].snapshot?.content.title).toBe("新內容提案");
    expect(state.courses).toHaveLength(2);
    expect(executeCommand(state, teacher, { type: "saveProposal", id, content: state.courses[0].draft, audience: "改寫", rightsNote: "新的來源", proRequested: false }).result.ok).toBe(false);
    const withoutAcks = structuredClone(state); withoutAcks.acknowledgements = []; withoutAcks.proposals[0].status = "draft";
    expect(executeCommand(withoutAcks, teacher, { type: "submitProposal", id, rightsConfirmed: true }).result.ok).toBe(false);
  });
  it("denies teacher and finance mutation of formal courses", () => {
    const state = createFixtures();
    for (const actor of [teacher, finance]) {
      expect(executeCommand(state, actor, { type: "createCourse" }).result.ok).toBe(false);
      expect(executeCommand(state, actor, { type: "publishCourse", id: "c1", expectedRevision: 1, reason: "測試發布限制", confirmed: true }).result.ok).toBe(false);
    }
  });
  it("imports only a draft, preserves public data until an explicit current revision is confirmed", () => {
    const { state, id } = submittedProposal();
    const imported = run(state, owner, { type: "reviewProposal", id, decision: "import", reason: "教學成果符合提案", confirmed: true });
    const courseId = imported.result.id!, draft = imported.state.courses.find((item) => item.id === courseId)!;
    expect(draft.published).toBeNull();
    expect(imported.state.proposals[0].status).toBe("imported");
    const saved = run(imported.state, owner, { type: "saveCourse", id: courseId, content: { ...draft.draft, title: "平台確認標題" }, policy: draft.policy, reason: "核對正式教學課綱" }).state;
    expect(executeCommand(saved, owner, { type: "publishCourse", id: courseId, expectedRevision: draft.draftRevision, reason: "使用舊預覽发布", confirmed: true }).result.ok).toBe(false);
    const current = saved.courses.find((item) => item.id === courseId)!;
    const published = run(saved, owner, { type: "publishCourse", id: courseId, expectedRevision: current.draftRevision, reason: "已預覽完整內容", confirmed: true }).state;
    expect(published.courses.find((item) => item.id === courseId)?.published?.title).toBe("平台確認標題");
    expect(published.proposals[0].status).toBe("published");
    expect(published.students).toEqual(state.students);
  });
  it("supersedes old pending revisions and blocks their import", () => {
    const { state, id } = submittedProposal();
    const revised = run(state, teacher, { type: "reviseProposal", id }).state;
    expect(revised.proposals[0].status).toBe("superseded");
    expect(executeCommand(revised, owner, { type: "reviewProposal", id, decision: "import", reason: "試著匯入過期版本", confirmed: true }).result.ok).toBe(false);
  });
  it("refuses to overwrite an existing platform draft with a teacher update", () => {
    let state = acceptedTeacher();
    const created = run(state, teacher, { type: "createProposal", baseCourseId: "c1" }); state = created.state;
    const id = created.result.id!;
    state = run(state, teacher, { type: "saveProposal", id, content: state.proposals[0].content, audience: "已加入學生", rightsNote: "原創教材示意", proRequested: true }).state;
    state = run(state, teacher, { type: "submitProposal", id, rightsConfirmed: true }).state;
    state = run(state, ops, { type: "saveCourse", id: "c1", content: { ...state.courses[0].draft, summary: "平台未發布修改" }, policy: state.courses[0].policy, reason: "平台正在修改內容" }).state;
    expect(executeCommand(state, owner, { type: "reviewProposal", id, decision: "import", reason: "試著覆蓋平台草稿", confirmed: true }).result.ok).toBe(false);
  });
});

describe("shared packages, reservations and monetary separation", () => {
  it("publishes the reviewed price snapshot without overwriting later drafts or bought snapshots", () => {
    let state = acceptedTeacher(); const before = structuredClone(state.packages);
    state = run(state, teacher, { type: "saveOffer", id: "p4", content: { ...state.offers[0].draft, unitPrice: 1200 } }).state;
    state = run(state, teacher, { type: "submitOffer", id: "p4" }).state;
    state = run(state, teacher, { type: "saveOffer", id: "p4", content: { ...state.offers[0].draft, unitPrice: 1400 } }).state;
    state = run(state, owner, { type: "publishOffer", id: "p4", reason: "核對送審價格版本", confirmed: true }).state;
    expect(state.offers[0].published?.unitPrice).toBe(1200);
    expect(state.offers[0].draft.unitPrice).toBe(1400);
    expect(state.packages).toEqual(before);
  });
  it("keeps teacher profile review snapshot independent from further draft editing", () => {
    let state = createFixtures();
    state = run(state, teacher, { type: "saveProfile", teacherId: "t1", profile: { ...state.teachers[0].draft, name: "送審名稱" } }).state;
    state = run(state, teacher, { type: "submitProfile", teacherId: "t1" }).state;
    expect(executeCommand(state, owner, { type: "publishProfile", teacherId: "t1", featured: true, reason: "舊快照不可發布", confirmed: true, expectedSnapshot: "stale-snapshot" }).result.ok).toBe(false);
    state = run(state, teacher, { type: "saveProfile", teacherId: "t1", profile: { ...state.teachers[0].draft, name: "後續草稿" } }).state;
    state = run(state, owner, { type: "publishProfile", teacherId: "t1", featured: true, reason: "核准送審公開資料", confirmed: true }).state;
    expect(state.teachers[0].published?.name).toBe("送審名稱");
    expect(state.teachers[0].draft.name).toBe("後續草稿");
    state = run(state, owner, { type: "setTeacherFeatured", teacherId: "t1", featured: false, reason: "本地移出首頁展示", confirmed: true }).state;
    expect(publicTeachers(state)).toEqual([]);
  });
  it("reserves one shared booking without consuming, generating earnings or recording payments", () => {
    const before = acceptedTeacher(), outcome = run(before, teacher, bookingCommand), after = outcome.state;
    expect(balance(before, "e-an")).toMatchObject({ available: 3, reserved: 1, consumed: 0 });
    expect(balance(after, "e-an")).toMatchObject({ available: 2, reserved: 2, consumed: 0 });
    expect(studentBookings(after, "s2").some((booking) => booking.id === outcome.result.id)).toBe(true);
    expect(after.bookings.find((booking) => booking.id === outcome.result.id)?.teacherId).toBe("t1");
    expect(after.earnings).toEqual(before.earnings);
    expect(after.cashEvents).toEqual(before.cashEvents);
    expect(executeCommand(after, teacher, bookingCommand).result.ok).toBe(false);
    expect(executeCommand(after, teacher, { ...bookingCommand, requestId: "another-click" }).result.ok).toBe(false);
  });
  it("denies fixed-mode, foreign-teacher, missing consent and stale policy reservations", () => {
    const state = acceptedTeacher();
    expect(availableSlots(state, "e-yu", teacher)).toEqual([]);
    expect(availableSlots(state, "e-an", otherTeacher)).toEqual([]);
    expect(executeCommand(state, teacher, { ...bookingCommand, consent: "" }).result.ok).toBe(false);
    const noPolicy = structuredClone(state); noPolicy.policies[2].version = "0.2";
    expect(executeCommand(noPolicy, teacher, bookingCommand).result.ok).toBe(false);
  });
  it("checks expiry, exhausted balance and overlap against either participant", () => {
    const state = acceptedTeacher();
    state.packages[1].expiry = "2026-09-01";
    expect(executeCommand(state, teacher, bookingCommand).result.ok).toBe(false);
    state.packages[1].expiry = "2027-01-01";
    state.ledger.push({ id: "exhaust", packageId: "e-an", kind: "consume", quantity: 3, label: "用完 fixture" });
    expect(availableSlots(state, "e-an", teacher)).toEqual([]);
    state.ledger.pop();
    state.bookings.push({ ...state.bookings[1], id: "student-conflict", teacherId: "t2", start: state.availability[0].start, end: state.availability[0].end });
    expect(availableSlots(state, "e-an", teacher).some((slot) => slot.id === "s1")).toBe(false);
  });
  it("rescheduling retains reserve count and cancellation releases only once", () => {
    const booked = run(acceptedTeacher(), teacher, bookingCommand);
    const bookingId = booked.result.id!;
    const moved = run(booked.state, ops, { type: "reschedule", bookingId, slotId: "s2", consent: "學生確認改期到 21 點", reason: "配合學生可上課時間", confirmed: true }).state;
    expect(balance(moved, "e-an")).toEqual(balance(booked.state, "e-an"));
    const cancelled = run(moved, ops, { type: "cancelBooking", bookingId, reason: "學生請求取消本次預約", confirmed: true }).state;
    expect(balance(cancelled, "e-an").available).toBe(3);
    expect(executeCommand(cancelled, ops, { type: "cancelBooking", bookingId, reason: "重複取消檢查", confirmed: true }).result.ok).toBe(false);
  });
  it("manual grants create entitlements with immutable snapshots, never fake payments", () => {
    const before = createFixtures();
    const after = run(before, ops, { type: "grantPackage", studentId: "s2", offerId: "p12", mode: "flexible", expiry: "2027-01-01", source: "gift", reason: "本地贈課權益示範", confirmed: true }).state;
    expect(after.packages).toHaveLength(3);
    expect(after.packages[2].snapshot.count).toBe(12);
    expect(after.cashEvents).toEqual(before.cashEvents);
    expect(after.bookings).toEqual(before.bookings);
    expect(executeCommand(before, ops, { type: "grantPackage", studentId: "s2", offerId: "p12", mode: "flexible", expiry: "2027-02-31", source: "gift", reason: "無效日期不得新增", confirmed: true }).result.ok).toBe(false);
  });
});

describe("feedback, policies, editorial and finance guards", () => {
  it("limits private notes to the teacher's own private students and keeps note text out of audit", () => {
    const state = run(createFixtures(), teacher, { type: "savePrivateNote", studentId: "s1", text: "僅老师可見的課前提醒" }).state;
    expect(state.privateNotes[0].text).toContain("課前提醒");
    expect(JSON.stringify(state.audit)).not.toContain("僅老师可見的課前提醒");
    expect(executeCommand(state, teacher, { type: "savePrivateNote", studentId: "s3", text: "平台指派不可使用私人備註" }).result.ok).toBe(false);
    expect(executeCommand(state, student, { type: "savePrivateNote", studentId: "s1", text: "學生越權" }).result.ok).toBe(false);
    expect(executeCommand(state, otherTeacher, { type: "savePrivateNote", studentId: "s1", text: "其他老師越權" }).result.ok).toBe(false);
  });
  it("saves only own future availability and refuses to remove a reserved slot", () => {
    const state = acceptedTeacher(), own = state.availability.filter((slot) => slot.teacherId === "t1");
    const changed = run(state, teacher, { type: "setAvailability", slots: own.slice(0, 2) }).state;
    expect(changed.availability.filter((slot) => slot.teacherId === "t1")).toHaveLength(2);
    expect(changed.availability.some((slot) => slot.teacherId === "t2")).toBe(true);
    const booked = run(changed, teacher, bookingCommand).state;
    expect(executeCommand(booked, teacher, { type: "setAvailability", slots: [] }).result.ok).toBe(false);
    expect(executeCommand(state, teacher, { type: "setAvailability", slots: [{ ...own[0], start: "2026-01-01T00:00:00Z" }] }).result.ok).toBe(false);
    expect(executeCommand(state, otherTeacher, { type: "setAvailability", slots: own }).result.ok).toBe(false);
  });
  it.each(["Free", "Plus"] as const)("%s membership is insufficient for Pro guidance", (membership) => {
    const state = createFixtures(); state.students[0].membership = membership;
    expect(guidanceEligibility(state, "s1", "c1").allowed).toBe(false);
  });
  it("requires all eligibility dimensions independently", () => {
    for (const dimension of ["join", "access", "course", "service"] as const) {
      const state = createFixtures();
      if (dimension === "join") state.students[0].joinedCourseIds = [];
      if (dimension === "access") state.students[0].accessCourseIds = [];
      if (dimension === "course") state.courses[0].policy.proReview = false;
      if (dimension === "service") state.students[0].serviceEligibility = "unknown";
      expect(guidanceEligibility(state, "s1", "c1").allowed).toBe(false);
    }
  });
  it("shares assigned teacher replies with the student while stripping private notes", () => {
    const before = createFixtures();
    const submitted = run(before, student, { type: "submitGuidance", studentId: "s1", courseId: "c1", lessonId: "l3", title: "切音練習", question: "切音後怎麼維持穩定？", mediaName: "DEMO 本地影片" });
    const submissionId = submitted.result.id!;
    expect(visibleSubmissions(submitted.state, teacher).some((item) => item.id === submissionId)).toBe(false);
    expect(executeCommand(submitted.state, owner, { type: "assignSubmission", submissionId, teacherId: "t2", reason: "測試能力限制" }).result.ok).toBe(false);
    const assigned = run(submitted.state, ops, { type: "assignSubmission", submissionId, teacherId: "t1", reason: "老師具節奏回饋能力" }).state;
    expect(executeCommand(assigned, otherTeacher, { type: "reply", submissionId, observation: "觀察", nextPractice: "練習", privateNote: "" }).result.ok).toBe(false);
    const replied = run(assigned, teacher, { type: "reply", submissionId, observation: "切音後右手停了一下", nextPractice: "先以 60 BPM 練四小節", privateNote: "下次課先確認學生練習時間" }).state;
    expect(visibleFeedback(replied, student)[0].privateNote).toBe("");
    expect(visibleFeedback(replied, teacher)[0].privateNote).toContain("下次課");
    expect(replied.students[0].progress[0].verified).toEqual([]);
    expect(replied.earnings).toEqual(before.earnings);
  });
  it("policy publication invalidates old acknowledgement without deleting its history", () => {
    let state = acceptedTeacher(); expect(policiesAccepted(state, teacher)).toBe(true);
    const policy = state.policies[2];
    state = run(state, ops, { type: "savePolicy", id: policy.id, title: policy.title, body: policy.body + "\n新版說明。", version: "0.2", reason: "補充提案版本流程" }).state;
    expect(policiesAccepted(state, teacher)).toBe(true);
    state = run(state, ops, { type: "publishPolicy", id: policy.id, reason: "確認新版示意條文", confirmed: true }).state;
    expect(policiesAccepted(state, teacher)).toBe(false);
    expect(state.acknowledgements.find((ack) => ack.policyId === policy.id)?.version).toBe("0.1");
  });
  it("article edits preserve published copy, and text remains plain text for safe React rendering", () => {
    let state = createFixtures();
    state = run(state, ops, { type: "submitArticle", id: "a1" }).state;
    state = run(state, ops, { type: "publishArticle", id: "a1", reason: "核對文章送審內容", confirmed: true }).state;
    const published = structuredClone(state.articles[0].published);
    state = run(state, ops, { type: "saveArticle", id: "a1", content: { ...state.articles[0].draft, body: "<script>alert('plain-text')</script>" } }).state;
    expect(state.articles[0].published).toEqual(published);
    expect(state.articles[0].draft.body).toContain("<script>");
    expect(executeCommand(state, teacher, { type: "publishArticle", id: "a1", reason: "老師越權发布", confirmed: true }).result.ok).toBe(false);
    state = run(state, ops, { type: "submitArticle", id: "a1" }).state;
    state = run(state, ops, { type: "rejectContent", kind: "article", id: "a1", reason: "補充更清楚的練習說明", confirmed: true, expectedSnapshot: JSON.stringify(state.articles[0].reviewSnapshot) }).state;
    expect(state.articles[0].reviewSnapshot).toBeNull();
    expect(state.articles[0].status).toBe("draft");
    expect(state.articles[0].published).toEqual(published);
  });
  it("separates teacher income, ops, finance preparation, owner approval and payout proof", () => {
    let state = createFixtures();
    expect(visibleEarnings(state, teacher).every((earning) => earning.teacherId === "t1")).toBe(true);
    expect(visibleEarnings(state, ops)).toEqual([]);
    expect(executeCommand(state, ops, { type: "prepareSettlement", teacherId: "t1", month: "2026-09", reason: "測試越權準備" }).result.ok).toBe(false);
    const prepared = run(state, finance, { type: "prepareSettlement", teacherId: "t1", month: "2026-09", reason: "已核對三筆示意報酬" }); state = prepared.state;
    const id = prepared.result.id!;
    expect(state.settlements[0].total).toBe(3150);
    expect(executeCommand(state, finance, { type: "approveSettlement", id, reason: "財務不可自己覆核", confirmed: true }).result.ok).toBe(false);
    expect(executeCommand(state, finance, { type: "recordPayout", id, proof: "DEMO-PROOF-1", reason: "未覆核不能撥款", confirmed: true }).result.ok).toBe(false);
    state = run(state, owner, { type: "approveSettlement", id, reason: "負責人已確認本次結算", confirmed: true }).state;
    expect(state.earnings.find((earning) => earning.id === "E-901")?.status).toBe("approved");
    state = run(state, finance, { type: "recordPayout", id, proof: "DEMO-PROOF-1", reason: "僅登記本地虛構憑證", confirmed: true }).state;
    expect(state.settlements[0].status).toBe("paid");
    expect(state.cashEvents).toEqual(createFixtures().cashEvents);
    expect(visibleAudit(state, ops)).toEqual([]);
    expect(visibleAudit(state, finance)).not.toHaveLength(0);
  });
  it("rejects overallocated finance assumptions and never rewrites historical earnings", () => {
    const state = createFixtures(), command: Command = { type: "saveFinanceDraft", name: "假設草稿", scope: "指定示意合約", kind: "creator", effective: "2026-10-01", base: 1000, allocations: [700, 400], reason: "測試分配基礎範圍" };
    expect(executeCommand(state, finance, command).result.ok).toBe(false);
    const after = run(state, finance, { ...command, allocations: [600, 300] }).state;
    expect(after.financeDrafts[0].unallocated).toBe(100);
    expect(after.earnings).toEqual(state.earnings);
    expect(after.earnings.find((earning) => earning.id === "E-905")?.amount).toBeNull();
    expect(executeCommand(state, finance, { ...command, allocations: [500], effective: "invalid-date" }).result.ok).toBe(false);
  });
  it("requires a new reason after switching the oversight target and labels replies as platform", () => {
    let state = run(createFixtures(), ops, { type: "openOversight", studentId: "s1", reason: "協助確認回饋內容" }).state;
    state = run(state, ops, { type: "openOversight", studentId: "s2", reason: "協助另一位學生預約" }).state;
    expect(executeCommand(state, ops, { type: "platformReply", studentId: "s1", body: "協助訊息", reason: "不可沿用舊對象權限" }).result.ok).toBe(false);
    state = run(state, ops, { type: "platformReply", studentId: "s2", body: "平台已收到你的示意需求。", reason: "回覆本次協助內容" }).state;
    expect(state.platformReplies[0].authorLabel).toBe("平台協助");
    state = run(state, ops, { type: "closeOversight" }).state;
    expect(state.oversightAccess).toEqual([]);
  });
});
