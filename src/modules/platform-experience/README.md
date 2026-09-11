# Local platform experience gateway

`gateway.ts` is a pure, synchronous application adapter for the preview UI. It imports existing Epic 1/4/5/6 validation, role checks and DTO types. It has no database client, DAL/action import, network call, environment lookup or persistence.

`HYBRID` means **existing contract validation plus synthetic local DTOs**. It does not mean an RPC ran, a user was authenticated, or a production transaction succeeded. The normal Supabase/RPC implementation remains authoritative and unchanged.

## UI contract

Every query/validation returns `GatewayResult<T>`:

- Success: `{ ok: true, mode: "HYBRID", source: "existing-contract-local-fixture", data, receipt? }`.
- Failure: `{ ok: false, mode: "HYBRID", code, message, issues? }`.
- Validation receipts always contain `simulated: true`, `persisted: false` and `transactionExecuted: false`.

Show validation success as 「輸入驗證完成，正式儲存／交易待接線」. Never label it 「付款成功」、「已取消預約」、「已儲存個人資料」 or an entitlement grant. No order/payment/transaction ID is generated.

| Function | Purpose |
|---|---|
| `getLocalIdentity(key)` | Explicit synthetic fixture identity: student, student-2, student-3, teacher, admin or multi. This is not Auth. |
| `getWorkspaceOptions(identity)` | Uses existing `canAccessArea` on the fixed fixture's allowed roles. |
| `validateWorkspaceSwitch(identity, area)` | Selects an already allowed workspace; adds no role. |
| `getLocalProfile(identity)` | Own safe profile fixture, never the selected student's account. |
| `validateProfileUpdate(identity, input)` | Existing `editableProfileSchema`; returns only its approved fields, without saving. |
| `listLocalProducts()` | Three distinct checkout categories; prices unknown/null. Membership policy remains proposed. |
| `validateCheckout(identity, input)` | Existing `checkoutSchema`; accepts only product slug, quantity and idempotency key. Returns `{ request, product }`, not an Order. |
| `listLocalLessonPackages(identity)` | Existing `EntitlementSummary` shape; fixed safe fixture balance. |
| `listLocalBookings(identity)` | Existing `SchedulingBooking` shape; participant-scoped fixtures without raw reservation/private data. |
| `validateBookingCancellation(identity, input)` | Existing cancellation schema and fixture participant boundary; no credit outcome is executed. |
| `validateBookingReschedule(identity, input)` | Existing reschedule schema and fixture participant boundary; no final availability/expiry/credit check or schedule mutation. |
| `requestExistingOperation(operation)` | Always unavailable. There is deliberately no real commit or backend fallback. |
| `getLearningAccessStatus()` | Always unavailable; Epic 7's shipped authority remains fail-closed pending Epic 8. |

`LOCAL_IDS` are clearly synthetic UUIDs. `LOCAL_REFERENCE_MAP` maps old preview references s1/s2/s3/t1/ab1/e-yu only; it is not a lookup into production. Existing public teacher/product routes must still use their safe public slugs.

The query fixtures do not implement a ledger, payment provider, availability engine, recurring schedule, membership lifecycle or enrollment engine. Existing PostgreSQL RPCs retain those boundaries. The adapter must not calculate teacher-cancellation makeup credit or set learning authority true for convenience.

Tests cover existing schemas, multi-role/inactive/forged-role boundaries, distinct self profiles, cross-student privacy, immutable fixture returns, ignored untrusted checkout totals, absence of transaction side effects, unavailable execution and prohibited runtime dependencies.
