/**
 * Local contract adapter. No DAL, Server Action, Supabase client, network or storage.
 * Successful validation is NOT an order, payment, booking, credit or Auth change.
 * Database authorization and transaction invariants remain in the existing Epics.
 */
import { z } from "zod";
import type { AccountStatus, AppRole } from "@/modules/auth/domain";
import { canAccessArea, type ProtectedArea } from "@/modules/auth/route-access";
import { editableProfileSchema, type PrivateProfile } from "@/modules/profiles/domain";
import { checkoutSchema } from "@/modules/commerce/domain";
import { entitlementSummarySchema, type EntitlementSummary } from "@/modules/entitlements/domain";
import {
  cancellationSchema, rescheduleSchema, schedulingBookingSchema,
  type SchedulingBooking,
} from "@/modules/scheduling/domain";

export const LOCAL_IDS = {
  student: "98000000-0000-4000-8000-000000000001",
  teacher: "98000000-0000-4000-8000-000000000002",
  admin: "98000000-0000-4000-8000-000000000003",
  multi: "98000000-0000-4000-8000-000000000004",
  otherStudent: "98000000-0000-4000-8000-000000000005",
  otherTeacher: "98000000-0000-4000-8000-000000000006",
  thirdStudent: "98000000-0000-4000-8000-000000000007",
  entitlement: "98000000-0000-4000-8000-000000000010",
  booking: "98000000-0000-4000-8000-000000000020",
  otherBooking: "98000000-0000-4000-8000-000000000021",
  lesson: "98000000-0000-4000-8000-000000000030",
  otherLesson: "98000000-0000-4000-8000-000000000031",
  relationship: "98000000-0000-4000-8000-000000000040",
} as const;

/** Synthetic contract tokens only. ab1/ab2/e-yu do NOT map business records to the
 * independent DTO examples below. Live preview screens must use shared state. */
export const LOCAL_REFERENCE_MAP = {
  s1: LOCAL_IDS.student, s2: LOCAL_IDS.otherStudent, s3: LOCAL_IDS.thirdStudent,
  t1: LOCAL_IDS.teacher, ab1: LOCAL_IDS.booking, ab2: LOCAL_IDS.otherBooking,
  "e-yu": LOCAL_IDS.entitlement,
} as const;

export type LocalIdentityKey = "student" | "student-2" | "student-3" | "teacher" | "admin" | "multi";
export type LocalIdentity = {
  userId: string;
  roles: AppRole[];
  accountStatus: AccountStatus;
  synthetic: true;
};
export type GatewayFailure = {
  ok: false;
  mode: "HYBRID";
  code: "invalid_input" | "forbidden" | "unavailable" | "not_found";
  message: string;
  issues?: Array<{ path: string; message: string }>;
};
export type SimulationReceipt = {
  simulated: true;
  persisted: false;
  transactionExecuted: false;
  operation: "profile-validation" | "checkout-validation" | "cancel-validation" | "reschedule-validation" | "workspace-selection";
  existingContract: string;
  message: string;
};
export type GatewayResult<T> = GatewayFailure | {
  ok: true;
  mode: "HYBRID";
  source: "existing-contract-local-fixture";
  data: T;
  receipt?: SimulationReceipt;
};

const identities: Record<LocalIdentityKey, LocalIdentity> = {
  student: { userId: LOCAL_IDS.student, roles: ["student"], accountStatus: "active", synthetic: true },
  "student-2": { userId: LOCAL_IDS.otherStudent, roles: ["student"], accountStatus: "active", synthetic: true },
  "student-3": { userId: LOCAL_IDS.thirdStudent, roles: ["student"], accountStatus: "active", synthetic: true },
  teacher: { userId: LOCAL_IDS.teacher, roles: ["teacher"], accountStatus: "active", synthetic: true },
  admin: { userId: LOCAL_IDS.admin, roles: ["admin"], accountStatus: "active", synthetic: true },
  multi: { userId: LOCAL_IDS.multi, roles: ["student", "teacher", "admin"], accountStatus: "active", synthetic: true },
};

function failure(code: GatewayFailure["code"], message: string): GatewayFailure {
  return { ok: false, mode: "HYBRID", code, message };
}
function success<T>(data: T, receipt?: SimulationReceipt): GatewayResult<T> {
  return { ok: true, mode: "HYBRID", source: "existing-contract-local-fixture", data, ...(receipt ? { receipt } : {}) };
}
function validationFailure(error: z.ZodError): GatewayFailure {
  return {
    ...failure("invalid_input", "請檢查欄位內容；尚未執行任何正式儲存或交易。"),
    issues: error.issues.map(issue => ({ path: issue.path.join("."), message: issue.message })),
  };
}
function receipt(operation: SimulationReceipt["operation"], existingContract: string): SimulationReceipt {
  return {
    simulated: true, persisted: false, transactionExecuted: false, operation, existingContract,
    message: "已通過既有輸入契約的本機驗證；正式授權、儲存及交易尚未接線。",
  };
}
function knownActiveIdentity(identity: LocalIdentity): boolean {
  const known = Object.values(identities).find(item => item.userId === identity.userId);
  return Boolean(known && identity.synthetic === true && identity.accountStatus === "active"
    && identity.roles.length > 0 && identity.roles.every(role => known.roles.includes(role)));
}
function authorize(identity: LocalIdentity, area: ProtectedArea): GatewayFailure | null {
  return knownActiveIdentity(identity) && canAccessArea(identity, area).allowed
    ? null : failure("forbidden", "這個本機示意身分沒有此工作區權限；切換介面不會新增角色。" );
}

export function getLocalIdentity(key: LocalIdentityKey = "student"): LocalIdentity {
  return { ...identities[key], roles: [...identities[key].roles] };
}

export function getWorkspaceOptions(identity: LocalIdentity): ProtectedArea[] {
  if (!knownActiveIdentity(identity)) return [];
  return (["student", "teacher", "admin"] as const).filter(area => canAccessArea(identity, area).allowed);
}

export function validateWorkspaceSwitch(identity: LocalIdentity, area: ProtectedArea): GatewayResult<{ area: ProtectedArea }> {
  const denied = authorize(identity, area);
  return denied ?? success({ area }, receipt("workspace-selection", "auth/route-access::canAccessArea"));
}

export type LocalProfile = Pick<PrivateProfile, "userId" | "displayName" | "avatarUrl" | "phone" | "timezone" | "locale">;

export function getLocalProfile(identity: LocalIdentity): GatewayResult<LocalProfile> {
  if (!knownActiveIdentity(identity)) return failure("forbidden", "此本機示意帳號目前不可使用。" );
  const labels: Record<string, string> = {
    [LOCAL_IDS.student]: "本機示意學生", [LOCAL_IDS.teacher]: "本機示意老師",
    [LOCAL_IDS.otherStudent]: "本機示意學生二", [LOCAL_IDS.thirdStudent]: "本機示意學生三",
    [LOCAL_IDS.admin]: "本機示意管理員", [LOCAL_IDS.multi]: "本機多角色帳號",
  };
  return success({ userId: identity.userId, displayName: labels[identity.userId], avatarUrl: null, phone: null, timezone: "Asia/Taipei", locale: "zh-TW" });
}

export function validateProfileUpdate(identity: LocalIdentity, input: unknown): GatewayResult<z.infer<typeof editableProfileSchema>> {
  if (!knownActiveIdentity(identity)) return failure("forbidden", "此本機示意帳號目前不可使用。" );
  // Existing object schemas strip unapproved fields; never echo raw input/roles back.
  const parsed = editableProfileSchema.safeParse(input);
  return parsed.success ? success(parsed.data, receipt("profile-validation", "profiles/domain::editableProfileSchema")) : validationFailure(parsed.error);
}

export type LocalProduct = {
  slug: string;
  name: string;
  productType: "subscription" | "recorded_course" | "lesson_package";
  billingLabel: string;
  policyStatus: "proposed" | "existing-commerce-contract";
  priceTwd: null;
  nextStep: "membership-catalog" | "purchased-product" | "lesson-credits";
};

export const LOCAL_PRODUCTS: readonly Readonly<LocalProduct>[] = Object.freeze([
  Object.freeze({ slug: "local-platform-membership", name: "平台會員方案示意", productType: "subscription" as const, billingLabel: "週期訂閱，週期與價格待決策", policyStatus: "proposed" as const, priceTwd: null, nextStep: "membership-catalog" as const }),
  Object.freeze({ slug: "local-standalone-course", name: "獨立課程示意", productType: "recorded_course" as const, billingLabel: "單次購買示意", policyStatus: "existing-commerce-contract" as const, priceTwd: null, nextStep: "purchased-product" as const }),
  Object.freeze({ slug: "local-private-package", name: "一對一課程包示意", productType: "lesson_package" as const, billingLabel: "單次購買課程包示意", policyStatus: "existing-commerce-contract" as const, priceTwd: null, nextStep: "lesson-credits" as const }),
]);

export function listLocalProducts(): GatewayResult<LocalProduct[]> {
  return success(LOCAL_PRODUCTS.map(product => ({ ...product })));
}

export function validateCheckout(identity: LocalIdentity, input: unknown): GatewayResult<{
  request: z.infer<typeof checkoutSchema>;
  product: LocalProduct;
}> {
  const denied = authorize(identity, "student");
  if (denied) return denied;
  const parsed = checkoutSchema.safeParse(input);
  if (!parsed.success) return validationFailure(parsed.error);
  const product = LOCAL_PRODUCTS.find(item => item.slug === parsed.data.productSlug);
  if (!product) return failure("not_found", "找不到此本機示意商品；不會查詢正式商品資料。" );
  return success({ request: parsed.data, product: { ...product } }, receipt("checkout-validation", "commerce/domain::checkoutSchema"));
}

const packageFixture = entitlementSummarySchema.parse({
  id: LOCAL_IDS.entitlement, package_name: "本機四堂課包示意", status: "active",
  booking_mode_eligibility: "flexible", credits_available: 2, credits_reserved: 1,
  credits_consumed: 1, credits_total: 4, starts_at: "2026-09-01T00:00:00Z", expires_at: "2027-01-01T00:00:00Z",
});
const bookingFixtures = [
  { studentId: LOCAL_IDS.student, teacherId: LOCAL_IDS.teacher, data: schedulingBookingSchema.parse({
    id: LOCAL_IDS.booking, lesson_id: LOCAL_IDS.lesson, recurring_series_id: null, source: "flexible",
    starts_at: "2026-09-13T12:00:00Z", ends_at: "2026-09-13T12:50:00Z", timezone_anchor: "Asia/Taipei", status: "confirmed", credit_outcome: null,
  }) },
  { studentId: LOCAL_IDS.otherStudent, teacherId: LOCAL_IDS.otherTeacher, data: schedulingBookingSchema.parse({
    id: LOCAL_IDS.otherBooking, lesson_id: LOCAL_IDS.otherLesson, recurring_series_id: null, source: "flexible",
    starts_at: "2026-09-14T12:00:00Z", ends_at: "2026-09-14T12:50:00Z", timezone_anchor: "Asia/Taipei", status: "confirmed", credit_outcome: null,
  }) },
];

function canViewBooking(identity: LocalIdentity, booking: typeof bookingFixtures[number]): boolean {
  return knownActiveIdentity(identity) && (
    (identity.userId === booking.studentId && canAccessArea(identity, "student").allowed)
    || (identity.userId === booking.teacherId && canAccessArea(identity, "teacher").allowed)
    || canAccessArea(identity, "admin").allowed
  );
}

export function listLocalLessonPackages(identity: LocalIdentity): GatewayResult<EntitlementSummary[]> {
  if (!knownActiveIdentity(identity)) return failure("forbidden", "此本機示意帳號目前不可使用。" );
  // One known fixture relationship, not a new general-purpose entitlement policy.
  const visible = canViewBooking(identity, bookingFixtures[0]);
  return success(visible ? [{ ...packageFixture }] : []);
}

export function listLocalBookings(identity: LocalIdentity): GatewayResult<SchedulingBooking[]> {
  if (!knownActiveIdentity(identity)) return failure("forbidden", "此本機示意帳號目前不可使用。" );
  return success(bookingFixtures.filter(booking => canViewBooking(identity, booking)).map(booking => ({ ...booking.data })));
}

function authorizeBooking(identity: LocalIdentity, bookingId: string): GatewayFailure | null {
  if (!knownActiveIdentity(identity)) return failure("forbidden", "此本機示意帳號目前不可使用。" );
  const booking = bookingFixtures.find(item => item.data.id === bookingId);
  if (!booking) return failure("not_found", "找不到此本機示意預約。" );
  return canViewBooking(identity, booking) ? null : failure("forbidden", "無法驗證其他學生或老師的預約。" );
}

export function validateBookingCancellation(identity: LocalIdentity, input: unknown): GatewayResult<z.infer<typeof cancellationSchema>> {
  const parsed = cancellationSchema.safeParse(input);
  if (!parsed.success) return validationFailure(parsed.error);
  const denied = authorizeBooking(identity, parsed.data.bookingId);
  if (denied) return denied;
  return success(parsed.data, receipt("cancel-validation", "scheduling/domain::cancellationSchema"));
}

export function validateBookingReschedule(identity: LocalIdentity, input: unknown): GatewayResult<z.infer<typeof rescheduleSchema>> {
  const parsed = rescheduleSchema.safeParse(input);
  if (!parsed.success) return validationFailure(parsed.error);
  const denied = authorizeBooking(identity, parsed.data.bookingId);
  if (denied) return denied;
  return success(parsed.data, receipt("reschedule-validation", "scheduling/domain::rescheduleSchema"));
}

export type ExistingOperation = "profile-update" | "create_checkout_order" | "cancel_lesson_booking" | "reschedule_lesson_booking" | "learning_set_activity" | "learning_get_own_activity";

/** The local adapter deliberately has no commit implementation or backend fallback. */
export function requestExistingOperation(operation: ExistingOperation): GatewayFailure {
  return failure("unavailable", `正式操作 ${operation} 尚未接到核准的 local／preview backend；沒有儲存或交易。`);
}

export function getLearningAccessStatus(): GatewayFailure {
  return failure("unavailable", "Epic 7 個人學習權限仍採封閉預設；待 Epic 8 核准權限接線，不提供正式個人進度或存取。" );
}
