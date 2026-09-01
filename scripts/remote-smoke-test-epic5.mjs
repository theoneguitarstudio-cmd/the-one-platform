import { execFile } from "node:child_process";
import { randomUUID } from "node:crypto";
import { readFile } from "node:fs/promises";
import process from "node:process";
import { promisify } from "node:util";

import { createClient } from "@supabase/supabase-js";

const execFileAsync = promisify(execFile);
const PROJECT_REF = "ygxeihtcolpiulupieeq";
const RUN_TAG =
  "epic5-smoke-" +
  new Date().toISOString().replaceAll(/[-:.TZ]/g, "").slice(0, 14) +
  "-" +
  randomUUID().slice(0, 8);
const PASSWORD = "Smoke-" + randomUUID() + "-Aa1!";
const CLI = "node_modules/supabase/dist/supabase.js";
const results = [];
const identities = [];
const ids = {
  audits: new Set(),
  entitlements: new Set(),
  events: new Set(),
  lessons: new Set(),
  orders: new Set(),
  payments: new Set(),
  products: new Set(),
  relationships: new Set(),
  reservations: new Set(),
};
const concurrency = {
  deadlock40P01: 0,
  domainRejection: 0,
  partialState: 0,
  unexpected23xxx: 0,
  unique23505: 0,
};

function parseEnv(text) {
  const values = {};
  for (const rawLine of text.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#")) continue;
    const separator = line.indexOf("=");
    if (separator < 1) continue;
    const name = line.slice(0, separator).trim();
    let value = line.slice(separator + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    values[name] = value;
  }
  return values;
}

const env = parseEnv(await readFile(".env.local", "utf8"));
const supabaseUrl = env.NEXT_PUBLIC_SUPABASE_URL;
const publishableKey = env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
const serviceRoleKey = env.SUPABASE_SERVICE_ROLE_KEY;
if (!supabaseUrl || !publishableKey || !serviceRoleKey) {
  throw new Error("Required Supabase environment variables are not configured.");
}
if (new URL(supabaseUrl).hostname !== PROJECT_REF + ".supabase.co") {
  throw new Error("Supabase URL does not match the required linked project.");
}

const clientOptions = {
  auth: {
    autoRefreshToken: false,
    detectSessionInUrl: false,
    persistSession: false,
  },
};
const service = createClient(supabaseUrl, serviceRoleKey, clientOptions);
const anon = createClient(supabaseUrl, publishableKey, clientOptions);

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function describeError(error) {
  if (!error) return "unknown error";
  return [error.code, error.message].filter(Boolean).join(": ");
}

function requireData(result, label) {
  if (result.error) throw new Error(label + ": " + describeError(result.error));
  return result.data;
}

function expectDenied(result, label, acceptedCodes = []) {
  assert(result.error, label + " unexpectedly succeeded");
  if (acceptedCodes.length > 0) {
    assert(
      acceptedCodes.includes(result.error.code),
      label + " returned " + describeError(result.error),
    );
  }
  return result.error;
}

function quoteSql(value) {
  if (value === null || value === undefined) return "null";
  return "'" + String(value).replaceAll("'", "''") + "'";
}

function sqlList(values) {
  const items = [...values].filter(Boolean);
  return items.length ? items.map(quoteSql).join(",") : "null";
}

async function dbQuery(sql) {
  const { stdout } = await execFileAsync(
    process.execPath,
    [CLI, "db", "query", "--linked", "--output-format", "json", sql],
    { cwd: process.cwd(), maxBuffer: 16 * 1024 * 1024 },
  );
  const start = stdout.indexOf("{");
  if (start < 0) throw new Error("Linked database query did not return JSON.");
  return JSON.parse(stdout.slice(start)).rows ?? [];
}

async function dbOne(sql, label) {
  const rows = await dbQuery(sql);
  assert(rows.length === 1, label + " returned " + rows.length + " rows");
  return rows[0];
}

async function run(number, name, body) {
  try {
    const detail = await body();
    results.push({ number, name, status: "PASS", detail: detail ?? "verified" });
  } catch (error) {
    results.push({
      number,
      name,
      status: "FAIL",
      detail: error instanceof Error ? error.message : String(error),
    });
  }
}

function recordRaceError(error) {
  if (!error) return;
  if (error.code === "40P01") concurrency.deadlock40P01 += 1;
  else if (error.code === "23505") concurrency.unique23505 += 1;
  else if (error.code === "P0001") concurrency.domainRejection += 1;
  else if (error.code?.startsWith("23")) concurrency.unexpected23xxx += 1;
}

async function signIn(email) {
  const client = createClient(supabaseUrl, publishableKey, clientOptions);
  const data = requireData(
    await client.auth.signInWithPassword({ email, password: PASSWORD }),
    "sign in " + email,
  );
  assert(data.session?.access_token, "Authenticated session missing for " + email);
  return client;
}

async function createIdentity(label, role) {
  const email = RUN_TAG + "-" + label + "@example.invalid";
  const created = await service.auth.admin.createUser({
    email,
    email_confirm: true,
    password: PASSWORD,
    user_metadata: { display_name: "Epic5 Smoke " + label },
  });
  const user = requireData(created, "create " + label).user;
  assert(user?.id, "Auth user ID missing for " + label);
  const identity = { client: null, email, label, role, userId: user.id };
  identities.push(identity);
  if (role) {
    requireData(
      await service
        .from("user_roles")
        .upsert({ role, user_id: user.id }, { ignoreDuplicates: true, onConflict: "user_id,role" }),
      "assign " + role + " to " + label,
    );
  } else {
    requireData(
      await service.from("user_roles").delete().eq("user_id", user.id),
      "remove automatic role from " + label,
    );
  }
  identity.client = await signIn(email);
  return identity;
}

async function createStudentProfile(identity) {
  requireData(
    await service.from("student_profiles").upsert({
      learning_goal: "Epic 5 fake smoke goal",
      onboarding_status: "complete",
      preferred_mode: "online",
      user_id: identity.userId,
    }),
    "create Student profile " + identity.label,
  );
}

async function createTeacherProfile(identity, suffix) {
  const row = requireData(
    await service
      .from("teacher_profiles")
      .insert({
        bio: "Epic 5 fake smoke Teacher " + suffix,
        default_meeting_provider: "manual_google_meet",
        default_meeting_url: "https://meet.google.com/epc-five-test",
        is_public: true,
        location_text: "Fake smoke location",
        public_slug: RUN_TAG + "-" + suffix,
        teaching_modes: ["online"],
        teaching_status: "active",
        trial_price_twd: 500,
        user_id: identity.userId,
        years_experience: 1,
      })
      .select("id,public_slug")
      .single(),
    "create Teacher profile " + suffix,
  );
  identity.teacherProfileId = row.id;
  identity.teacherSlug = row.public_slug;
}

async function createProduct(admin, suffix, config, productType = "lesson_package") {
  const slug = RUN_TAG + "-" + suffix;
  const row = requireData(
    await service
      .from("products")
      .insert({
        base_price_amount: 1000,
        currency: "TWD",
        description: "Fake Epic 5 smoke Product",
        is_public: true,
        is_purchasable: true,
        metadata: { smoke_tag: RUN_TAG },
        name: "Epic5 Smoke " + suffix,
        owner_type: "platform",
        product_type: productType,
        public_slug: slug,
        published_at: new Date().toISOString(),
        short_description: "Fake smoke package",
        status: "active",
      })
      .select("id,name,public_slug")
      .single(),
    "create Product " + suffix,
  );
  ids.products.add(row.id);
  if (config) {
    requireData(
      await admin.client.rpc("admin_set_lesson_package_product_config", {
        p_booking_mode: config.bookingMode,
        p_lesson_count: config.lessonCount,
        p_lesson_duration_minutes: config.duration,
        p_product_id: row.id,
        p_reason: RUN_TAG + " fake config",
        p_validity_unit: config.validityUnit,
        p_validity_value: config.validityValue,
      }),
      "configure Product " + suffix,
    );
  }
  return row;
}

async function checkout(identity, product, key = randomUUID()) {
  const id = requireData(
    await identity.client.rpc("create_checkout_order", {
      p_idempotency_key: key,
      p_product_slug: product.public_slug,
      p_quantity: 1,
    }),
    "checkout " + product.public_slug,
  );
  ids.orders.add(id);
  return id;
}

async function payOrder(student, admin, orderId, suffix) {
  const paymentId = requireData(
    await student.client.rpc("submit_bank_transfer", {
      p_idempotency_key: randomUUID(),
      p_order_id: orderId,
      p_payer_name: "Epic5 Fake Payer",
      p_payment_note: RUN_TAG + " fake payment",
      p_transfer_last5: "54321",
    }),
    "submit fake payment",
  );
  ids.payments.add(paymentId);
  requireData(
    await admin.client.rpc("admin_confirm_payment", {
      p_order_id: orderId,
      p_payment_id: paymentId,
      p_provider_event_id: RUN_TAG + "-" + suffix,
      p_reason: RUN_TAG + " fake payment confirmation",
    }),
    "confirm fake payment",
  );
  const event = requireData(
    await service
      .from("order_fulfillment_events")
      .select("id,status")
      .eq("order_id", orderId)
      .single(),
    "read order.paid event",
  );
  ids.events.add(event.id);
  return { eventId: event.id, paymentId };
}

async function fulfill(eventId, client = service) {
  return client.rpc("process_order_fulfillment_event", { p_event_id: eventId });
}

async function entitlementForOrder(orderId) {
  const row = await dbOne(
    `select e.id,e.beneficiary_user_id,e.entitlement_type::text,e.status::text,e.starts_at,e.expires_at,
      e.product_name_snapshot,e.booking_mode_eligibility::text,e.lesson_duration_minutes,e.config_snapshot,
      b.available,b.reserved,b.consumed,b.total
     from public.entitlements e cross join lateral private.lesson_credit_balance(e.id) b
     where e.source_order_id=${quoteSql(orderId)}`,
    "entitlement for Order",
  );
  ids.entitlements.add(row.id);
  return row;
}

async function createPaidEntitlement(student, admin, product, suffix) {
  const orderId = await checkout(student, product);
  const { eventId } = await payOrder(student, admin, orderId, suffix);
  requireData(await fulfill(eventId), "automatic fulfillment " + suffix);
  return { entitlement: await entitlementForOrder(orderId), eventId, orderId };
}

async function createCompletedLesson(student, teacher, relationshipId, offsetMinutes) {
  const startsAt = new Date(Date.now() - offsetMinutes * 60_000);
  const endsAt = new Date(startsAt.getTime() + 50 * 60_000);
  const row = requireData(
    await service
      .from("lessons")
      .insert({
        delivery_mode: "online",
        duration_minutes: 50,
        ends_at: endsAt.toISOString(),
        lesson_type: "flexible",
        meeting_provider: "manual_google_meet",
        meeting_url: "https://meet.google.com/epc-five-test",
        relationship_id: relationshipId,
        starts_at: startsAt.toISOString(),
        status: "completed",
        student_user_id: student.userId,
        teacher_user_id: teacher.userId,
        timezone_anchor: "Asia/Taipei",
      })
      .select("id")
      .single(),
    "create completed Lesson",
  );
  ids.lessons.add(row.id);
  return row.id;
}

async function balance(entitlementId) {
  return dbOne(
    `select * from private.lesson_credit_balance(${quoteSql(entitlementId)}::uuid)`,
    "credit balance",
  );
}

async function reserve(identity, entitlementId, key, lessonId = null, booking = null) {
  const result = await identity.client.rpc("reserve_lesson_credit", {
    p_booking_reference: booking,
    p_entitlement_id: entitlementId,
    p_lesson_id: lessonId,
    p_reservation_key: key,
  });
  if (!result.error && result.data) ids.reservations.add(result.data);
  return result;
}

async function collectFixtureIds() {
  const rows = await dbQuery(`
    select 'user' kind,id from auth.users where email like ${quoteSql(RUN_TAG + "%@example.invalid")}
    union all select 'product',id from public.products where public_slug like ${quoteSql(RUN_TAG + "%")}
    union all select 'order',id from public.orders where buyer_user_id in
      (select id from auth.users where email like ${quoteSql(RUN_TAG + "%@example.invalid")})
    union all select 'payment',p.id from public.payments p join public.orders o on o.id=p.order_id
      where o.buyer_user_id in (select id from auth.users where email like ${quoteSql(RUN_TAG + "%@example.invalid")})
    union all select 'event',f.id from public.order_fulfillment_events f join public.orders o on o.id=f.order_id
      where o.buyer_user_id in (select id from auth.users where email like ${quoteSql(RUN_TAG + "%@example.invalid")})
    union all select 'entitlement',e.id from public.entitlements e where e.beneficiary_user_id in
      (select id from auth.users where email like ${quoteSql(RUN_TAG + "%@example.invalid")})
    union all select 'reservation',r.id from public.lesson_credit_reservations r where r.beneficiary_user_id in
      (select id from auth.users where email like ${quoteSql(RUN_TAG + "%@example.invalid")})
    union all select 'relationship',r.id from public.student_teacher_relationships r where r.student_user_id in
      (select id from auth.users where email like ${quoteSql(RUN_TAG + "%@example.invalid")})
    union all select 'lesson',l.id from public.lessons l where l.student_user_id in
      (select id from auth.users where email like ${quoteSql(RUN_TAG + "%@example.invalid")});
  `);
  for (const row of rows) {
    const collection = ids[row.kind + "s"];
    if (collection) collection.add(row.id);
  }
}

async function cleanup() {
  await collectFixtureIds();
  const users = new Set(identities.map((identity) => identity.userId));
  const discoveredUsers = await dbQuery(
    `select id from auth.users where email like ${quoteSql(RUN_TAG + "%@example.invalid")}`,
  );
  for (const row of discoveredUsers) users.add(row.id);
  const userList = sqlList(users);
  const productList = sqlList(ids.products);
  const orderList = sqlList(ids.orders);
  const paymentList = sqlList(ids.payments);
  const eventList = sqlList(ids.events);
  const entitlementList = sqlList(ids.entitlements);
  const lessonList = sqlList(ids.lessons);
  const relationshipList = sqlList(ids.relationships);
  const targetList = sqlList(
    new Set([
      ...ids.products,
      ...ids.orders,
      ...ids.payments,
      ...ids.events,
      ...ids.entitlements,
      ...ids.lessons,
      ...ids.relationships,
    ]),
  );
  await dbQuery(`begin;
    set local session_replication_role='replica';
    delete from public.audit_logs where actor_user_id in (${userList}) or target_id in (${targetList});
    delete from public.fulfillment_manual_retry_attempts where fulfillment_event_id in (${eventList});
    delete from public.entitlement_expiry_history where entitlement_id in (${entitlementList}) or actor_user_id in (${userList});
    delete from public.lesson_credit_ledger where entitlement_id in (${entitlementList}) or beneficiary_user_id in (${userList});
    delete from public.lesson_credit_reservations where entitlement_id in (${entitlementList}) or beneficiary_user_id in (${userList});
    delete from public.entitlements where id in (${entitlementList}) or beneficiary_user_id in (${userList});
    delete from public.order_item_fulfillment_snapshots where order_item_id in
      (select id from public.order_items where order_id in (${orderList}));
    delete from public.order_fulfillment_events where id in (${eventList}) or order_id in (${orderList});
    delete from public.refunds where order_id in (${orderList}) or payment_id in (${paymentList});
    delete from public.payment_submissions where order_id in (${orderList}) or payment_id in (${paymentList});
    delete from public.payments where id in (${paymentList}) or order_id in (${orderList});
    delete from public.order_items where order_id in (${orderList});
    delete from public.orders where id in (${orderList}) or buyer_user_id in (${userList});
    delete from public.lesson_package_product_configs where product_id in (${productList});
    delete from public.product_publication_requests where product_id in (${productList}) or teacher_user_id in (${userList});
    delete from public.product_public_catalog where product_id in (${productList}) or public_slug like ${quoteSql(RUN_TAG + "%")};
    delete from public.products where id in (${productList}) or public_slug like ${quoteSql(RUN_TAG + "%")};
    delete from public.lesson_records where lesson_id in (${lessonList});
    delete from public.assessments where lesson_id in (${lessonList}) or student_user_id in (${userList});
    delete from public.lessons where id in (${lessonList}) or student_user_id in (${userList}) or teacher_user_id in (${userList});
    delete from public.trial_orders where student_user_id in (${userList}) or teacher_user_id in (${userList});
    delete from public.student_teacher_relationships where id in (${relationshipList}) or student_user_id in (${userList}) or teacher_user_id in (${userList});
    delete from public.teacher_stage_capabilities where teacher_profile_id in
      (select id from public.teacher_profiles where user_id in (${userList}));
    delete from public.teacher_specialties where teacher_profile_id in
      (select id from public.teacher_profiles where user_id in (${userList}));
    delete from public.teacher_public_profiles where teacher_profile_id in
      (select id from public.teacher_profiles where user_id in (${userList})) or public_slug like ${quoteSql(RUN_TAG + "%")};
    delete from public.teacher_profiles where user_id in (${userList});
    delete from public.student_profiles where user_id in (${userList});
    delete from public.public_profiles where user_id in (${userList});
    delete from public.user_roles where user_id in (${userList});
    delete from public.profiles where user_id in (${userList});
    commit;`);
  for (const userId of users) {
    const deleted = await service.auth.admin.deleteUser(userId);
    if (deleted.error && deleted.error.status !== 404) {
      throw new Error("delete auth user: " + describeError(deleted.error));
    }
  }
}

async function residueCounts() {
  const userList = sqlList(new Set(identities.map((identity) => identity.userId)));
  const row = await dbOne(`select
    (select count(*) from auth.users where email like ${quoteSql(RUN_TAG + "%@example.invalid")}) auth_users,
    (select count(*) from public.profiles where user_id in (${userList})) profiles,
    (select count(*) from public.user_roles where user_id in (${userList})) roles,
    (select count(*) from public.student_profiles where user_id in (${userList})) student_profiles,
    (select count(*) from public.teacher_profiles where user_id in (${userList})) teacher_profiles,
    (select count(*) from public.student_teacher_relationships where id in (${sqlList(ids.relationships)})) relationships,
    (select count(*) from public.products where public_slug like ${quoteSql(RUN_TAG + "%")}) products,
    (select count(*) from public.lesson_package_product_configs where product_id in (${sqlList(ids.products)})) configs,
    (select count(*) from public.orders where id in (${sqlList(ids.orders)})) orders,
    (select count(*) from public.order_items where order_id in (${sqlList(ids.orders)})) order_items,
    (select count(*) from public.order_item_fulfillment_snapshots where order_item_id in (select id from public.order_items where order_id in (${sqlList(ids.orders)}))) snapshots,
    (select count(*) from public.payments where order_id in (${sqlList(ids.orders)})) payments,
    (select count(*) from public.order_fulfillment_events where order_id in (${sqlList(ids.orders)})) outbox,
    (select count(*) from public.entitlements where id in (${sqlList(ids.entitlements)})) entitlements,
    (select count(*) from public.lesson_credit_reservations where entitlement_id in (${sqlList(ids.entitlements)})) reservations,
    (select count(*) from public.lesson_credit_ledger where entitlement_id in (${sqlList(ids.entitlements)})) ledger,
    (select count(*) from public.entitlement_expiry_history where entitlement_id in (${sqlList(ids.entitlements)})) expiry_history,
    (select count(*) from public.fulfillment_manual_retry_attempts where fulfillment_event_id in (${sqlList(ids.events)})) manual_retry_attempts,
    (select count(*) from public.audit_logs where actor_user_id in (${userList}) or target_id in (${sqlList(new Set([...ids.products,...ids.orders,...ids.payments,...ids.events,...ids.entitlements,...ids.lessons,...ids.relationships]))})) audit,
    (select count(*) from public.lessons where id in (${sqlList(ids.lessons)})) lessons,
    (select count(*) from public.lesson_records where lesson_id in (${sqlList(ids.lessons)})) lesson_records;`, "residue counts");
  return Object.fromEntries(Object.entries(row).map(([key, value]) => [key, Number(value)]));
}

let studentA;
let studentB;
let teacherA;
let teacherB;
let adminA;
let ordinaryA;
let relationshipA;
let packageA;
let packageB;
let packageOne;
let main;
let second;

console.log("RUN_TAG " + RUN_TAG);

try {
  studentA = await createIdentity("student-a", "student");
  studentB = await createIdentity("student-b", "student");
  teacherA = await createIdentity("teacher-a", "teacher");
  teacherB = await createIdentity("teacher-b", "teacher");
  adminA = await createIdentity("admin-a", "admin");
  ordinaryA = await createIdentity("ordinary-a", null);
  await Promise.all([
    createStudentProfile(studentA),
    createStudentProfile(studentB),
    createTeacherProfile(teacherA, "teacher-a"),
    createTeacherProfile(teacherB, "teacher-b"),
  ]);
  relationshipA = requireData(
    await service
      .from("student_teacher_relationships")
      .insert({
        preferred_mode: "online",
        relationship_status: "active",
        student_user_id: studentA.userId,
        teacher_user_id: teacherA.userId,
      })
      .select("id")
      .single(),
    "create active relationship",
  ).id;
  ids.relationships.add(relationshipA);
  packageA = await createProduct(adminA, "package-a", {
    bookingMode: "both",
    duration: 50,
    lessonCount: 4,
    validityUnit: "weeks",
    validityValue: 5,
  });
  packageB = await createProduct(adminA, "package-b", {
    bookingMode: "flexible",
    duration: 60,
    lessonCount: 2,
    validityUnit: "days",
    validityValue: 45,
  });
  packageOne = await createProduct(adminA, "package-one", {
    bookingMode: "fixed",
    duration: 50,
    lessonCount: 1,
    validityUnit: "days",
    validityValue: 30,
  });

  await run(1, "Checkout, payment, and outbox", async () => {
    const key = randomUUID();
    const orderId = await checkout(studentA, packageA, key);
    const retry = await checkout(studentA, packageA, key);
    assert(retry === orderId, "checkout idempotency returned another Order");
    const paid = await payOrder(studentA, adminA, orderId, "payment-a");
    const state = await dbOne(`select
      (select count(*) from public.orders where id=${quoteSql(orderId)} and status='paid' and payment_status='paid') paid_order,
      (select count(*) from public.order_items where order_id=${quoteSql(orderId)}) items,
      (select count(*) from public.payments where id=${quoteSql(paid.paymentId)} and status='paid') paid_payment,
      (select count(*) from public.order_fulfillment_events where id=${quoteSql(paid.eventId)} and event_type='order.paid') outbox`, "checkout state");
    assert(+state.paid_order === 1 && +state.items === 1 && +state.paid_payment === 1 && +state.outbox === 1, "checkout/payment/outbox mismatch");
    main = { eventId: paid.eventId, orderId };
    return "one paid Order, Item, Payment, and order.paid outbox; checkout retry idempotent";
  });

  await run(2, "Automatic fulfillment", async () => {
    requireData(await fulfill(main.eventId), "process order.paid");
    main.entitlement = await entitlementForOrder(main.orderId);
    const e = main.entitlement;
    assert(e.entitlement_type === "lesson_package" && e.beneficiary_user_id === studentA.userId, "entitlement authority mismatch");
    assert(+e.total === 4 && +e.available === 4 && +e.reserved === 0 && +e.consumed === 0, "initial allocation mismatch");
    assert(e.booking_mode_eligibility === "both" && +e.lesson_duration_minutes === 50, "package snapshot mismatch");
    const days = (new Date(e.expires_at) - new Date(e.starts_at)) / 86_400_000;
    assert(Math.abs(days - 35) < 0.01, "five-week expiry mismatch");
    assert(e.config_snapshot.lesson_count === 4 && e.config_snapshot.validity_value === 5, "config snapshot mismatch");
    return "exactly one lesson_package entitlement and one 4-credit allocation; 5-week snapshot verified";
  });

  await run(3, "Fulfillment retry idempotency", async () => {
    requireData(await fulfill(main.eventId), "fulfillment retry");
    const state = await dbOne(`select
      (select count(*) from public.entitlements where source_fulfillment_event_id=${quoteSql(main.eventId)}) entitlements,
      (select count(*) from public.lesson_credit_ledger where source_fulfillment_event_id=${quoteSql(main.eventId)} and entry_type='allocation') allocations,
      (select sum(available_delta) from public.lesson_credit_ledger where entitlement_id=${quoteSql(main.entitlement.id)}) available`, "retry state");
    assert(+state.entitlements === 1 && +state.allocations === 1 && +state.available === 4, "fulfillment duplicated state");
    return "one entitlement/allocation; credits stayed 4";
  });

  await run(4, "Concurrent fulfillment", async () => {
    const orderId = await checkout(studentA, packageB);
    const paid = await payOrder(studentA, adminA, orderId, "concurrent-fulfillment");
    const serviceA = createClient(supabaseUrl, serviceRoleKey, clientOptions);
    const serviceB = createClient(supabaseUrl, serviceRoleKey, clientOptions);
    const outcomes = await Promise.all([fulfill(paid.eventId, serviceA), fulfill(paid.eventId, serviceB)]);
    for (const outcome of outcomes) recordRaceError(outcome.error);
    outcomes.forEach((outcome) => requireData(outcome, "concurrent fulfillment"));
    second = { entitlement: await entitlementForOrder(orderId), eventId: paid.eventId, orderId };
    const state = await dbOne(`select
      (select count(*) from public.entitlements where source_fulfillment_event_id=${quoteSql(paid.eventId)}) entitlements,
      (select count(*) from public.lesson_credit_ledger where source_fulfillment_event_id=${quoteSql(paid.eventId)} and entry_type='allocation') allocations`, "concurrent fulfillment state");
    assert(+state.entitlements === 1 && +state.allocations === 1, "concurrent fulfillment duplicated state");
    return "two independent service clients; exactly one entitlement/allocation";
  });

  await run(5, "Student safe DTO and isolation", async () => {
    const rows = requireData(await studentA.client.rpc("get_own_lesson_entitlement_summaries"), "Student DTO");
    const own = rows.find((row) => row.id === main.entitlement.id);
    assert(own && own.package_name === packageA.name && own.credits_total === 4, "Student package summary missing");
    const allowed = new Set(["id", "package_name", "credits_total", "credits_available", "credits_reserved", "credits_consumed", "starts_at", "expires_at", "status", "booking_mode_eligibility", "lesson_duration_minutes"]);
    assert(Object.keys(own).every((key) => allowed.has(key)), "Student DTO exposed unexpected field");
    for (const forbidden of ["source_order_id", "source_order_item_id", "source_fulfillment_event_id", "config_snapshot", "metadata", "actor_user_id"]) assert(!(forbidden in own), "Student DTO exposed " + forbidden);
    const other = requireData(await studentB.client.rpc("get_own_lesson_entitlement_summaries"), "Student B DTO");
    assert(!other.some((row) => row.id === main.entitlement.id), "Student B saw Student A entitlement");
    return "safe fields only; no fulfillment/internal metadata; Student B isolated";
  });

  await run(6, "Teacher safe DTO and finance isolation", async () => {
    const rows = requireData(await teacherA.client.rpc("get_teacher_student_lesson_entitlement_summaries", { p_student_user_id: studentA.userId }), "Teacher DTO");
    const own = rows.find((row) => row.id === main.entitlement.id);
    assert(own && own.status === "active" && own.credits_available === 4, "Teacher safe summary missing");
    const other = await teacherB.client.rpc("get_teacher_student_lesson_entitlement_summaries", { p_student_user_id: studentA.userId });
    expectDenied(other, "unrelated Teacher summary", ["42501"]);
    const teacherOrders = requireData(await teacherA.client.from("orders").select("id"), "Teacher Orders RLS");
    assert(teacherOrders.length === 0, "Teacher saw Student finance Order");
    for (const table of ["payments", "payment_submissions", "lesson_credit_ledger", "entitlement_expiry_history"]) expectDenied(await teacherA.client.from(table).select("*"), "Teacher raw " + table);
    return "related Teacher sees safe summary; unrelated Teacher and finance/raw ledger denied";
  });

  await run(7, "Reserve and same-key idempotency", async () => {
    const key = randomUUID();
    const first = requireData(await reserve(studentA, main.entitlement.id, key, null, RUN_TAG + "-booking-main"), "reserve");
    const retry = requireData(await reserve(studentA, main.entitlement.id, key, null, RUN_TAG + "-booking-main"), "reserve retry");
    assert(first === retry, "same reservation key returned another ID");
    const b = await balance(main.entitlement.id);
    assert(+b.available === 3 && +b.reserved === 1, "reserve balance mismatch");
    main.reservationId = first;
    return "4 available -> 3 available / 1 reserved; retry returned same reservation";
  });

  await run(8, "Concurrent same reservation key", async () => {
    const key = randomUUID();
    const booking = RUN_TAG + "-same-key-race";
    const sessionB = await signIn(studentA.email);
    const outcomes = await Promise.all([
      reserve(studentA, main.entitlement.id, key, null, booking),
      reserve({ client: sessionB }, main.entitlement.id, key, null, booking),
    ]);
    for (const outcome of outcomes) recordRaceError(outcome.error);
    const values = outcomes.map((outcome) => requireData(outcome, "same-key race"));
    assert(values[0] === values[1], "same-key race returned different reservations");
    return "two authenticated sessions returned one reservation ID";
  });

  await run(9, "Cross-package duplicate booking protection", async () => {
    const booking = RUN_TAG + "-cross-package";
    requireData(await reserve(studentA, main.entitlement.id, randomUUID(), null, booking), "first package reserve");
    expectDenied(await reserve(studentA, second.entitlement.id, randomUUID(), null, booking), "cross-package duplicate", ["P0001"]);
    return "same booking reference on another entitlement rejected with domain error";
  });

  await run(10, "Final-credit race", async () => {
    const one = await createPaidEntitlement(studentA, adminA, packageOne, "final-credit");
    const sessionB = await signIn(studentA.email);
    const outcomes = await Promise.all([
      reserve(studentA, one.entitlement.id, randomUUID(), null, RUN_TAG + "-last-a"),
      reserve({ client: sessionB }, one.entitlement.id, randomUUID(), null, RUN_TAG + "-last-b"),
    ]);
    outcomes.forEach((outcome) => recordRaceError(outcome.error));
    assert(outcomes.filter((outcome) => !outcome.error).length === 1, "final credit did not have one winner");
    assert(outcomes.find((outcome) => outcome.error)?.error.code === "P0001", "final-credit loser was not domain rejection");
    const b = await balance(one.entitlement.id);
    assert(+b.available === 0 && +b.reserved === 1, "final-credit partial/negative state");
    return "exactly one winner; loser domain rejection; available 0 / reserved 1";
  });

  await run(11, "Release semantics", async () => {
    requireData(await studentA.client.rpc("release_lesson_credit", { p_reason: "fake cancellation", p_reservation_id: main.reservationId }), "release");
    requireData(await studentA.client.rpc("release_lesson_credit", { p_reason: "fake cancellation", p_reservation_id: main.reservationId }), "release retry");
    const b = await balance(main.entitlement.id);
    assert(+b.available === 2 && +b.reserved === 2, "release balance/idempotency mismatch");
    const rows = await dbQuery(`select count(*) releases from public.lesson_credit_ledger where reservation_id=${quoteSql(main.reservationId)} and entry_type='release'`);
    assert(+rows[0].releases === 1, "release duplicated ledger movement");
    return "available restored once; retry idempotent; no over-release";
  });

  await run(12, "Consume and double-consume", async () => {
    const lessonId = await createCompletedLesson(studentA, teacherA, relationshipA, 300);
    const reservationId = requireData(await reserve(studentA, second.entitlement.id, randomUUID(), lessonId), "lesson reserve");
    requireData(await teacherA.client.rpc("consume_lesson_credit", { p_lesson_id: lessonId, p_reservation_id: reservationId }), "consume");
    requireData(await teacherA.client.rpc("consume_lesson_credit", { p_lesson_id: lessonId, p_reservation_id: reservationId }), "double consume");
    expectDenied(await studentA.client.rpc("release_lesson_credit", { p_reason: "invalid release", p_reservation_id: reservationId }), "release consumed reservation", ["P0001"]);
    const state = await dbOne(`select
      (select status::text from public.lesson_credit_reservations where id=${quoteSql(reservationId)}) reservation_status,
      (select count(*) from public.lesson_credit_ledger where reservation_id=${quoteSql(reservationId)} and entry_type='consumption') consumptions`, "consume state");
    assert(state.reservation_status === "consumed" && +state.consumptions === 1, "consume duplicated/partial state");
    return "authorized Teacher consumed once; retry idempotent; consumed release denied";
  });

  await run(13, "Release versus consume race", async () => {
    const one = await createPaidEntitlement(studentA, adminA, packageOne, "release-consume");
    const lessonId = await createCompletedLesson(studentA, teacherA, relationshipA, 420);
    const reservationId = requireData(await reserve(studentA, one.entitlement.id, randomUUID(), lessonId), "race reserve");
    const studentSession = await signIn(studentA.email);
    const teacherSession = await signIn(teacherA.email);
    const outcomes = await Promise.all([
      studentSession.rpc("release_lesson_credit", { p_reason: "race release", p_reservation_id: reservationId }),
      teacherSession.rpc("consume_lesson_credit", { p_lesson_id: lessonId, p_reservation_id: reservationId }),
    ]);
    outcomes.forEach((outcome) => recordRaceError(outcome.error));
    assert(outcomes.filter((outcome) => !outcome.error).length === 1, "release/consume race did not have one winner");
    assert(outcomes.find((outcome) => outcome.error)?.error.code === "P0001", "release/consume loser was not domain-safe");
    const state = await dbOne(`select r.status::text,
      (select count(*) from public.lesson_credit_ledger l where l.reservation_id=r.id and l.entry_type in('release','consumption')) terminal_entries
      from public.lesson_credit_reservations r where r.id=${quoteSql(reservationId)}`, "release/consume state");
    assert(["released", "consumed"].includes(state.status) && +state.terminal_entries === 1, "release/consume partial state");
    return "one consistent winner and one terminal ledger movement";
  });

  await run(14, "Expired entitlement", async () => {
    const expired = await createPaidEntitlement(studentA, adminA, packageOne, "expired");
    await dbQuery(`update public.entitlements set starts_at=now()-interval '40 days',expires_at=now()-interval '10 days' where id=${quoteSql(expired.entitlement.id)};`);
    expectDenied(await reserve(studentA, expired.entitlement.id, randomUUID(), null, RUN_TAG + "-expired"), "expired reserve", ["P0001"]);
    return "new reservation rejected; reserved-across-expiry TBD was not asserted";
  });

  await run(15, "Teacher expiry extension", async () => {
    const before = await entitlementForOrder(main.orderId);
    const target = new Date(new Date(before.expires_at).getTime() + 7 * 86_400_000).toISOString();
    const key = randomUUID();
    requireData(await teacherA.client.rpc("extend_lesson_package_entitlement", { p_entitlement_id: main.entitlement.id, p_idempotency_key: key, p_new_expires_at: target, p_reason: "Fake Teacher extension" }), "Teacher extension");
    const after = await dbOne(`select e.expires_at,b.total,b.available,b.reserved,b.consumed,
      (select count(*) from public.entitlement_expiry_history h where h.entitlement_id=e.id and h.idempotency_key=${quoteSql(key)} and h.actor_user_id=${quoteSql(teacherA.userId)} and h.actor_role='teacher' and h.reason='Fake Teacher extension') history
      from public.entitlements e cross join lateral private.lesson_credit_balance(e.id) b where e.id=${quoteSql(main.entitlement.id)}`, "extension state");
    assert(new Date(after.expires_at).getTime() === new Date(target).getTime() && +after.history === 1, "extension/history mismatch");
    assert(+after.total === +before.total && +after.available === +before.available && +after.reserved === +before.reserved, "extension changed credits");
    expectDenied(await teacherB.client.rpc("extend_lesson_package_entitlement", { p_entitlement_id: main.entitlement.id, p_idempotency_key: randomUUID(), p_new_expires_at: new Date(new Date(target).getTime() + 86_400_000).toISOString(), p_reason: "Fake unrelated extension" }), "Teacher B extension", ["42501"]);
    expectDenied(await studentA.client.rpc("extend_lesson_package_entitlement", { p_entitlement_id: main.entitlement.id, p_idempotency_key: randomUUID(), p_new_expires_at: new Date(new Date(target).getTime() + 86_400_000).toISOString(), p_reason: "Fake Student extension" }), "Student extension", ["42501"]);
    return "+7 days; immutable history actor/role/reason recorded; credits unchanged; Teacher B/Student denied";
  });

  await run(16, "Expiry history raw DML denial", async () => {
    expectDenied(await service.from("entitlement_expiry_history").insert({ entitlement_id: main.entitlement.id }), "service expiry INSERT", ["42501"]);
    expectDenied(await service.from("entitlement_expiry_history").update({ reason: "tamper" }).eq("entitlement_id", main.entitlement.id), "service expiry UPDATE", ["42501"]);
    expectDenied(await service.from("entitlement_expiry_history").delete().eq("entitlement_id", main.entitlement.id), "service expiry DELETE", ["42501"]);
    return "application service_role INSERT/UPDATE/DELETE all denied";
  });

  await run(17, "Ledger raw DML denial", async () => {
    expectDenied(await service.from("lesson_credit_ledger").insert({ entitlement_id: main.entitlement.id }), "service ledger INSERT", ["42501"]);
    expectDenied(await service.from("lesson_credit_ledger").update({ reason_code: "tamper" }).eq("entitlement_id", main.entitlement.id), "service ledger UPDATE", ["42501"]);
    expectDenied(await service.from("lesson_credit_ledger").delete().eq("entitlement_id", main.entitlement.id), "service ledger DELETE", ["42501"]);
    return "application service_role INSERT/UPDATE/DELETE all denied";
  });

  await run(18, "Entitlement immutable authority fields", async () => {
    for (const patch of [
      { beneficiary_user_id: studentB.userId },
      { entitlement_type: "membership_access" },
      { source_order_id: randomUUID() },
      { source_order_item_id: randomUUID() },
      { source_fulfillment_event_id: randomUUID() },
      { config_snapshot: { tampered: true } },
      { teacher_scope_user_id: teacherB.userId },
      { booking_mode_eligibility: "fixed" },
      { lesson_duration_minutes: 999 },
    ]) expectDenied(await service.from("entitlements").update(patch).eq("id", main.entitlement.id), "service immutable update", ["42501"]);
    return "beneficiary/type/source/snapshot/teacher/eligibility/duration raw mutations denied";
  });

  await run(19, "Admin credit adjustment", async () => {
    const key = randomUUID();
    const before = await balance(main.entitlement.id);
    requireData(await adminA.client.rpc("admin_adjust_lesson_credits", { p_entitlement_id: main.entitlement.id, p_idempotency_key: key, p_quantity_delta: 1, p_reason: "Fake compensation" }), "Admin adjustment");
    requireData(await adminA.client.rpc("admin_adjust_lesson_credits", { p_entitlement_id: main.entitlement.id, p_idempotency_key: key, p_quantity_delta: 1, p_reason: "Fake compensation" }), "Admin adjustment retry");
    const after = await balance(main.entitlement.id);
    assert(+after.available === +before.available + 1, "adjustment retry duplicated credits");
    const audit = await dbOne(`select
      (select count(*) from public.lesson_credit_ledger where entitlement_id=${quoteSql(main.entitlement.id)} and operation_key=${quoteSql("adjust:" + key)} and metadata->>'reason'='Fake compensation') ledger,
      (select count(*) from public.audit_logs where actor_user_id=${quoteSql(adminA.userId)} and target_id=${quoteSql(main.entitlement.id)} and action='entitlement.credit_adjusted' and reason='Fake compensation') audit`, "adjustment audit");
    assert(+audit.ledger === 1 && +audit.audit === 1, "adjustment ledger/audit mismatch");
    expectDenied(await adminA.client.rpc("admin_adjust_lesson_credits", { p_entitlement_id: main.entitlement.id, p_idempotency_key: randomUUID(), p_quantity_delta: -999, p_reason: "Fake negative attempt" }), "negative adjustment", ["P0001"]);
    expectDenied(await studentA.client.rpc("admin_adjust_lesson_credits", { p_entitlement_id: main.entitlement.id, p_idempotency_key: randomUUID(), p_quantity_delta: 1, p_reason: "Fake Student attempt" }), "Student adjustment", ["42501"]);
    expectDenied(await teacherA.client.rpc("admin_adjust_lesson_credits", { p_entitlement_id: main.entitlement.id, p_idempotency_key: randomUUID(), p_quantity_delta: 1, p_reason: "Fake Teacher attempt" }), "Teacher adjustment", ["42501"]);
    return "+1 once with reason/audit; negative denied; Student/Teacher denied";
  });

  await run(20, "Manual fulfillment retry success and idempotency", async () => {
    const orderId = await checkout(studentA, packageOne);
    const eventId = randomUUID();
    ids.events.add(eventId);
    await dbQuery(`insert into public.order_fulfillment_events(id,order_id,event_type,payload) values(${quoteSql(eventId)},${quoteSql(orderId)},'order.paid',jsonb_build_object('smoke_tag',${quoteSql(RUN_TAG)}));`);
    requireData(await fulfill(eventId), "intentional pre-payment fulfillment failure");
    const paid = await payOrder(studentA, adminA, orderId, "manual-retry-success");
    assert(paid.eventId === eventId, "payment created a second fulfillment event");
    const key = randomUUID();
    const args = { p_event_id: eventId, p_idempotency_key: key, p_reason: "Fake safe manual retry" };
    const first = requireData(await adminA.client.rpc("admin_retry_order_fulfillment_event", args), "manual retry");
    const retry = requireData(await adminA.client.rpc("admin_retry_order_fulfillment_event", args), "manual retry same key");
    assert(first === "processed" && retry === "processed", "manual retry did not process");
    const e = await entitlementForOrder(orderId);
    const state = await dbOne(`select
      (select count(*) from public.fulfillment_manual_retry_attempts where fulfillment_event_id=${quoteSql(eventId)} and idempotency_key=${quoteSql(key)} and actor_user_id=${quoteSql(adminA.userId)}) attempts,
      (select count(*) from public.audit_logs where target_id=${quoteSql(eventId)} and action='fulfillment.manual_retry') audits,
      (select count(*) from public.entitlements where source_fulfillment_event_id=${quoteSql(eventId)}) entitlements,
      (select count(*) from public.lesson_credit_ledger where source_fulfillment_event_id=${quoteSql(eventId)} and entry_type='allocation') allocations`, "manual retry state");
    assert(+state.attempts === 1 && +state.audits === 1 && +state.entitlements === 1 && +state.allocations === 1 && +e.total === 1, "manual retry idempotency mismatch");
    return "failed pre-payment event recovered; one attempt/audit/entitlement/allocation; same key idempotent";
  });

  let failedRetry;
  await run(21, "Manual fulfillment retry durable failure", async () => {
    const unsupported = await createProduct(adminA, "unsupported", null, "recorded_course");
    const orderId = await checkout(studentA, unsupported);
    const paid = await payOrder(studentA, adminA, orderId, "manual-retry-failure");
    const key = randomUUID();
    const result = requireData(await adminA.client.rpc("admin_retry_order_fulfillment_event", { p_event_id: paid.eventId, p_idempotency_key: key, p_reason: "Fake expected failure" }), "failed manual retry");
    assert(result === "failed", "unsupported fulfillment unexpectedly succeeded");
    failedRetry = { eventId: paid.eventId, key };
    const state = await dbOne(`select
      (select count(*) from public.entitlements where source_fulfillment_event_id=${quoteSql(paid.eventId)}) entitlements,
      (select count(*) from public.lesson_credit_ledger where source_fulfillment_event_id=${quoteSql(paid.eventId)}) allocations,
      (select count(*) from public.fulfillment_manual_retry_attempts where fulfillment_event_id=${quoteSql(paid.eventId)} and result='failed' and safe_error_code='UNSUPPORTED_FULFILLMENT_HANDLER' and reason='Fake expected failure') attempts,
      (select count(*) from public.audit_logs where target_id=${quoteSql(paid.eventId)} and action='fulfillment.manual_retry' and reason='Fake expected failure') audits`, "failed retry state");
    assert(+state.entitlements === 0 && +state.allocations === 0 && +state.attempts === 1 && +state.audits === 1, "failed retry partial/audit state");
    return "no grant/allocation; durable failed attempt and central audit with safe code";
  });

  await run(22, "Non-Admin and anonymous manual retry denial", async () => {
    const before = await dbOne(`select count(*) attempts from public.fulfillment_manual_retry_attempts where fulfillment_event_id=${quoteSql(failedRetry.eventId)}`, "attempt count before denial");
    for (const [label, client] of [["Student", studentA.client], ["Teacher", teacherA.client], ["authenticated-no-role", ordinaryA.client], ["anon", anon]]) {
      expectDenied(await client.rpc("admin_retry_order_fulfillment_event", { p_event_id: failedRetry.eventId, p_idempotency_key: randomUUID(), p_reason: "Fake denied retry" }), label + " manual retry", ["42501"]);
    }
    const after = await dbOne(`select count(*) attempts from public.fulfillment_manual_retry_attempts where fulfillment_event_id=${quoteSql(failedRetry.eventId)}`, "attempt count after denial");
    assert(+after.attempts === +before.attempts, "denied retry created attempt/audit");
    return "Student/Teacher/non-Admin/anon denied; no fake Admin attempt";
  });

  await run(23, "Automatic fulfillment remains service-only", async () => {
    const auto = await createPaidEntitlement(studentA, adminA, packageOne, "automatic-retry");
    expectDenied(await studentA.client.rpc("process_order_fulfillment_event", { p_event_id: auto.eventId }), "Student automatic fulfillment", ["42501"]);
    expectDenied(await adminA.client.rpc("process_order_fulfillment_event", { p_event_id: auto.eventId }), "Admin automatic fulfillment", ["42501"]);
    expectDenied(await service.rpc("fulfill_order_paid_event", { p_actor: adminA.userId, p_event_id: auto.eventId }), "private fulfillment helper");
    return "automatic service path exactly once; authenticated callers and private helper denied";
  });

  await run(24, "Admin revoke", async () => {
    const revocable = await createPaidEntitlement(studentA, adminA, packageA, "revoke");
    const reservation = requireData(await reserve(studentA, revocable.entitlement.id, randomUUID(), null, RUN_TAG + "-revoke-held"), "reserve before revoke");
    const key = randomUUID();
    requireData(await adminA.client.rpc("admin_revoke_entitlement", { p_entitlement_id: revocable.entitlement.id, p_idempotency_key: key, p_reason: "Fake revocation" }), "Admin revoke");
    const state = await dbOne(`select e.status::text,e.revoked_by,e.revoked_reason,b.available,b.reserved,b.consumed,
      (select status::text from public.lesson_credit_reservations where id=${quoteSql(reservation)}) reservation_status,
      (select count(*) from public.audit_logs where target_id=e.id and action='entitlement.revoked' and actor_user_id=${quoteSql(adminA.userId)}) audits
      from public.entitlements e cross join lateral private.lesson_credit_balance(e.id) b where e.id=${quoteSql(revocable.entitlement.id)}`, "revoke state");
    assert(state.status === "revoked" && state.revoked_by === adminA.userId && state.revoked_reason === "Fake revocation", "revoke authority/reason mismatch");
    assert(+state.available === 0 && +state.reserved === 0 && state.reservation_status === "released" && +state.audits === 1, "revoke balance/history mismatch");
    expectDenied(await reserve(studentA, revocable.entitlement.id, randomUUID(), null, RUN_TAG + "-after-revoke"), "reserve revoked", ["P0001"]);
    return "revoked with actor/reason/audit; held reservation released; history preserved; new reserve denied";
  });

  await run(25, "Reserve versus revoke race", async () => {
    const race = await createPaidEntitlement(studentA, adminA, packageOne, "reserve-revoke");
    const studentSession = await signIn(studentA.email);
    const adminSession = await signIn(adminA.email);
    const outcomes = await Promise.all([
      studentSession.rpc("reserve_lesson_credit", { p_booking_reference: RUN_TAG + "-reserve-revoke", p_entitlement_id: race.entitlement.id, p_lesson_id: null, p_reservation_key: randomUUID() }),
      adminSession.rpc("admin_revoke_entitlement", { p_entitlement_id: race.entitlement.id, p_idempotency_key: randomUUID(), p_reason: "Fake race revoke" }),
    ]);
    outcomes.forEach((outcome) => recordRaceError(outcome.error));
    assert(!outcomes[1].error, "revoke lost unexpectedly: " + describeError(outcomes[1].error));
    const state = await dbOne(`select e.status::text,b.available,b.reserved,
      (select count(*) from public.lesson_credit_reservations where entitlement_id=e.id and status='reserved') live_reservations
      from public.entitlements e cross join lateral private.lesson_credit_balance(e.id) b where e.id=${quoteSql(race.entitlement.id)}`, "reserve/revoke state");
    assert(state.status === "revoked" && +state.available === 0 && +state.reserved === 0 && +state.live_reservations === 0, "reserve/revoke partial state");
    return "revocation serialized with reserve; final revoked / zero live balance";
  });

  await run(26, "Multiple packages and explicit selection", async () => {
    const rows = requireData(await studentA.client.rpc("get_own_lesson_entitlement_summaries"), "multiple package DTO");
    const active = rows.filter((row) => row.status === "active");
    assert(active.length >= 2 && new Set(active.map((row) => row.id)).size === active.length, "multiple active packages unsupported");
    expectDenied(await studentA.client.rpc("reserve_lesson_credit", { p_booking_reference: RUN_TAG + "-no-entitlement", p_entitlement_id: null, p_lesson_id: null, p_reservation_key: randomUUID() }), "implicit package selection");
    return `${active.length} active packages coexist; entitlement_id is required; no auto earliest-expiry selection`;
  });

  await run(27, "Fixed/flexible shared ledger", async () => {
    const row = await dbOne(`select
      (select count(*) from public.entitlements where id in (${quoteSql(main.entitlement.id)},${quoteSql(second.entitlement.id)}) and booking_mode_eligibility in('both','flexible')) eligible,
      (select count(*) from information_schema.tables where table_schema='public' and table_name in('fixed_credits','flexible_credits')) split_tables,
      (select count(*) from information_schema.columns where table_schema='public' and table_name in('entitlements','lesson_credit_ledger') and column_name like '%price%') price_columns`, "shared ledger schema");
    assert(+row.eligible === 2 && +row.split_tables === 0 && +row.price_columns === 0, "fixed/flexible ledger separation/pricing leak found");
    return "fixed/flexible/both eligibility snapshots use one ledger; no split credit tables or price columns";
  });

  await run(28, "Trial isolation", async () => {
    const before = await dbOne(`select count(*) entitlements from public.entitlements where beneficiary_user_id=${quoteSql(studentB.userId)}`, "Trial pre-count");
    const startsAt = new Date(Date.now() + 48 * 60 * 60_000).toISOString();
    const trialOrder = requireData(await studentB.client.rpc("request_trial_checkout", {
      p_idempotency_key: randomUUID(),
      p_learning_goal: "Epic5 fake Trial isolation",
      p_preferred_location: null,
      p_preferred_mode: "online",
      p_proposed_starts_at: startsAt,
      p_teacher_slug: teacherA.teacherSlug,
      p_timezone: "Asia/Taipei",
    }), "request fake Trial");
    const lessonId = requireData(await adminA.client.rpc("confirm_trial_payment", { p_order_id: trialOrder, p_starts_at: startsAt }), "confirm fake Trial");
    ids.lessons.add(lessonId);
    const relation = await dbOne(`select relationship_id from public.lessons where id=${quoteSql(lessonId)}`, "Trial relationship");
    ids.relationships.add(relation.relationship_id);
    const after = await dbOne(`select count(*) entitlements from public.entitlements where beneficiary_user_id=${quoteSql(studentB.userId)}`, "Trial post-count");
    assert(+after.entitlements === +before.entitlements, "Trial created generic entitlement/credits");
    return "paid Trial created no generic entitlement or lesson-credit dual-write";
  });

  await run(29, "RLS and raw table isolation", async () => {
    const epic5Tables = ["lesson_package_product_configs", "order_item_fulfillment_snapshots", "lesson_credit_reservations", "lesson_credit_ledger", "entitlement_expiry_history", "fulfillment_manual_retry_attempts"];
    for (const table of epic5Tables) {
      expectDenied(await anon.from(table).select("*"), "anon " + table);
      expectDenied(await studentA.client.from(table).select("*"), "Student raw " + table);
      expectDenied(await teacherA.client.from(table).select("*"), "Teacher raw " + table);
    }
    expectDenied(await anon.from("entitlements").select("id"), "anon entitlements");
    expectDenied(
      await adminA.client.from("lesson_credit_ledger").insert({ entitlement_id: main.entitlement.id }),
      "Admin raw ledger mutation",
      ["42501"],
    );
    expectDenied(
      await adminA.client.from("entitlements").update({ status: "cancelled" }).eq("id", main.entitlement.id),
      "Admin raw entitlement mutation",
      ["42501"],
    );
    const own = requireData(await studentA.client.from("entitlements").select("id,status,starts_at,expires_at,product_name_snapshot,booking_mode_eligibility,lesson_duration_minutes"), "Student safe entitlement columns");
    assert(own.some((row) => row.id === main.entitlement.id), "Student safe own entitlement hidden");
    expectDenied(await studentA.client.from("entitlements").select("source_order_id"), "Student raw source Order");
    return "anon denied; Student/Teacher raw internals denied; Admin raw mutations denied; Student limited own projection works";
  });

  await run(30, "Ledger invariants", async () => {
    await collectFixtureIds();
    const row = await dbOne(`select
      count(*) filter(where b.available<0 or b.reserved<0) negative,
      count(*) filter(where b.available+b.reserved+b.consumed<>b.total) impossible,
      (select count(*) from (select entitlement_id,operation_key from public.lesson_credit_ledger where entitlement_id in (${sqlList(ids.entitlements)}) group by 1,2 having count(*)>1) d) duplicate_operations,
      (select count(*) from (select beneficiary_user_id,lesson_id from public.lesson_credit_reservations where beneficiary_user_id in (${sqlList(new Set(identities.map((i) => i.userId)))}) and lesson_id is not null group by 1,2 having count(*)>1) d) duplicate_lessons,
      (select count(*) from (select beneficiary_user_id,booking_reference from public.lesson_credit_reservations where beneficiary_user_id in (${sqlList(new Set(identities.map((i) => i.userId)))}) and booking_reference is not null group by 1,2 having count(*)>1) d) duplicate_bookings
      from public.entitlements e cross join lateral private.lesson_credit_balance(e.id) b where e.id in (${sqlList(ids.entitlements)})`, "ledger invariants");
    assert(+row.negative === 0 && +row.impossible === 0 && +row.duplicate_operations === 0 && +row.duplicate_lessons === 0 && +row.duplicate_bookings === 0, "ledger invariant violation: " + JSON.stringify(row));
    return "no negative/impossible balance or duplicate operation/lesson/booking";
  });

  await run(31, "Concurrency acceptance summary", async () => {
    assert(concurrency.deadlock40P01 === 0, "remote 40P01 observed");
    assert(concurrency.unique23505 === 0, "23505 leaked");
    assert(concurrency.unexpected23xxx === 0, "unexpected 23xxx leaked");
    assert(concurrency.partialState === 0, "partial state observed");
    return `40P01=0; 23505=0; unexpected23xxx=0; partial=0; domain=${concurrency.domainRejection}`;
  });
} finally {
  await run(32, "Cleanup and final residue", async () => {
    await cleanup();
    const counts = await residueCounts();
    assert(Object.values(counts).every((value) => value === 0), "residue remains: " + JSON.stringify(counts));
    return JSON.stringify(counts);
  });

  for (const result of results) {
    console.log(`TEST ${result.number} [${result.status}] ${result.name}: ${result.detail}`);
  }
  console.log(
    `CONCURRENCY 40P01=${concurrency.deadlock40P01} 23505=${concurrency.unique23505} ` +
      `unexpected23xxx=${concurrency.unexpected23xxx} domain=${concurrency.domainRejection} partial=${concurrency.partialState}`,
  );
  console.log("RESULTS " + JSON.stringify(results));
  if (
    results.some((result) => result.status === "FAIL") ||
    concurrency.deadlock40P01 !== 0 ||
    concurrency.unique23505 !== 0 ||
    concurrency.unexpected23xxx !== 0 ||
    concurrency.partialState !== 0
  ) {
    process.exitCode = 1;
  }
}
