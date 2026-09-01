import { randomUUID } from "node:crypto";
import { readFile } from "node:fs/promises";
import process from "node:process";

import { createClient } from "@supabase/supabase-js";

const PROJECT_REF = "ygxeihtcolpiulupieeq";
const RUN_TAG =
  "epic4-smoke-" +
  new Date().toISOString().replaceAll(/[-:.TZ]/g, "").slice(0, 14) +
  "-" +
  randomUUID().slice(0, 8);
const PASSWORD = "Smoke-" + randomUUID() + "-Aa1!";

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
const identities = [];
const productIds = new Set();
const productSlugs = new Set();
const orderIds = new Set();
const paymentIds = new Set();
const results = [];
const concurrency = {
  deadlock: 0,
  domain: 0,
  integrity: 0,
  partial: 0,
  unique: 0,
};

function describeError(error) {
  if (!error) return "unknown error";
  return [error.code, error.message].filter(Boolean).join(": ");
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
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

function recordRaceError(error) {
  if (!error) return;
  if (error.code === "40P01") concurrency.deadlock += 1;
  else if (error.code === "23505") concurrency.unique += 1;
  else if (error.code === "P0001") concurrency.domain += 1;
  else if (error.code?.startsWith("23")) concurrency.integrity += 1;
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

async function createIdentity(label, roles = []) {
  const email = RUN_TAG + "-" + label + "@example.invalid";
  const created = await service.auth.admin.createUser({
    email,
    email_confirm: true,
    password: PASSWORD,
    user_metadata: { display_name: "Epic4 Smoke " + label },
  });
  const user = requireData(created, "create " + label).user;
  assert(user?.id, "Auth user ID missing for " + label);
  const identity = { label, email, userId: user.id, client: null };
  identities.push(identity);
  for (const role of roles) {
    requireData(
      await service
        .from("user_roles")
        .upsert({ user_id: user.id, role }, { onConflict: "user_id,role" }),
      "assign " + role + " to " + label,
    );
  }
  identity.client = await signIn(email);
  return identity;
}

async function signIn(email) {
  const client = createClient(supabaseUrl, publishableKey, clientOptions);
  const signedIn = await client.auth.signInWithPassword({ email, password: PASSWORD });
  const authData = requireData(signedIn, "sign in " + email);
  assert(authData.session?.access_token, "Session missing for " + email);
  return client;
}

async function createStudentProfile(identity) {
  requireData(
    await service.from("student_profiles").upsert({
      learning_goal: "Epic4 remote smoke goal",
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
        bio: "Epic4 remote smoke Teacher " + suffix,
        is_public: true,
        location_text: "Fake remote location",
        public_slug: RUN_TAG + "-" + suffix,
        teaching_modes: ["online"],
        teaching_status: "active",
        trial_price_twd: 500,
        user_id: identity.userId,
        years_experience: 5,
      })
      .select("id,public_slug")
      .single(),
    "create Teacher profile " + suffix,
  );
  identity.teacherProfileId = row.id;
  identity.teacherSlug = row.public_slug;
}

async function createProduct({
  slugSuffix,
  owner = "platform",
  teacher = null,
  purchasable = true,
  status = "active",
  price = 3200,
}) {
  const slug = RUN_TAG + "-" + slugSuffix;
  const row = requireData(
    await service
      .from("products")
      .insert({
        base_price_amount: price,
        currency: "TWD",
        description: "Fake remote smoke Product",
        is_public: status === "active",
        is_purchasable: status === "active" && purchasable,
        metadata: { smoke_tag: RUN_TAG },
        name: "Epic4 Smoke " + slugSuffix,
        owner_teacher_user_id: teacher?.userId ?? null,
        owner_type: owner,
        product_type: "lesson_package",
        public_slug: slug,
        published_at: status === "active" ? new Date().toISOString() : null,
        short_description: "Fake Product " + slugSuffix,
        status,
      })
      .select("id,public_slug")
      .single(),
    "create Product " + slugSuffix,
  );
  productIds.add(row.id);
  productSlugs.add(row.public_slug);
  return row;
}

async function checkout(identity, product, key = randomUUID(), quantity = 1) {
  const id = requireData(
    await identity.client.rpc("create_checkout_order", {
      p_idempotency_key: key,
      p_product_slug: product.public_slug,
      p_quantity: quantity,
    }),
    "checkout " + product.public_slug,
  );
  orderIds.add(id);
  return id;
}

async function submitBank(identity, orderId, key = randomUUID(), last5 = "12345") {
  const id = requireData(
    await identity.client.rpc("submit_bank_transfer", {
      p_idempotency_key: key,
      p_order_id: orderId,
      p_payer_name: "Epic4 Fake Payer",
      p_payment_note: RUN_TAG + " fake transfer",
      p_transfer_last5: last5,
    }),
    "submit bank transfer",
  );
  paymentIds.add(id);
  return id;
}

async function insertPayment(orderId, suffix, provider = "manual_bank_transfer") {
  const order = requireData(
    await service
      .from("orders")
      .select("currency,total_amount")
      .eq("id", orderId)
      .single(),
    "read fixture Order",
  );
  const row = requireData(
    await service
      .from("payments")
      .insert({
        amount: order.total_amount,
        currency: order.currency,
        idempotency_key: RUN_TAG + "-" + suffix,
        method: provider === "manual_cash" ? "cash" : "bank_transfer",
        order_id: orderId,
        provider,
        provider_reference: RUN_TAG + "-fake-" + suffix,
        status: "pending",
      })
      .select("id")
      .single(),
    "insert Payment fixture " + suffix,
  );
  paymentIds.add(row.id);
  return row.id;
}

async function inspectOrder(orderId) {
  const [order, payments, submissions, audits, outbox, items] = await Promise.all([
    service.from("orders").select("*").eq("id", orderId).single(),
    service.from("payments").select("*").eq("order_id", orderId),
    service.from("payment_submissions").select("*").eq("order_id", orderId),
    service.from("audit_logs").select("*").eq("target_type", "payment"),
    service.from("order_fulfillment_events").select("*").eq("order_id", orderId),
    service.from("order_items").select("*").eq("order_id", orderId),
  ]);
  return {
    order: requireData(order, "inspect Order"),
    payments: requireData(payments, "inspect Payments"),
    submissions: requireData(submissions, "inspect submissions"),
    audits: requireData(audits, "inspect audits"),
    outbox: requireData(outbox, "inspect outbox"),
    items: requireData(items, "inspect Items"),
  };
}

function paymentAuditCount(state) {
  const ids = new Set(state.payments.map((payment) => payment.id));
  return state.audits.filter(
    (audit) => audit.action === "payment.confirmed" && ids.has(audit.target_id),
  ).length;
}

async function expectOneRaceWinner(outcomes, label) {
  for (const outcome of outcomes) recordRaceError(outcome.error);
  const successes = outcomes.filter((outcome) => !outcome.error);
  const failures = outcomes.filter((outcome) => outcome.error);
  assert(successes.length === 1 && failures.length === 1, label + " winner mismatch");
  assert(failures[0].error.code === "P0001", label + " loser was not domain rejection");
}

async function collectFixtureIds() {
  const userIds = identities.map((identity) => identity.userId).filter(Boolean);
  if (userIds.length > 0) {
    const rows = requireData(await service.from("orders").select("id").in("buyer_user_id", userIds), "collect Orders");
    for (const row of rows) orderIds.add(row.id);
  }
  if (orderIds.size > 0) {
    const rows = requireData(await service.from("payments").select("id").in("order_id", [...orderIds]), "collect Payments");
    for (const row of rows) paymentIds.add(row.id);
  }
  const rows = requireData(await service.from("products").select("id,public_slug").like("public_slug", RUN_TAG + "%"), "collect Products");
  for (const row of rows) { productIds.add(row.id); productSlugs.add(row.public_slug); }
}

async function cleanup() {
  await collectFixtureIds();
  const users = identities.map((identity) => identity.userId).filter(Boolean);
  const orders = [...orderIds]; const payments = [...paymentIds]; const products = [...productIds];
  const filters = [];
  if (users.length) filters.push("actor_user_id.in.(" + users.join(",") + ")");
  if (orders.length) filters.push("target_id.in.(" + orders.join(",") + ")");
  if (payments.length) filters.push("target_id.in.(" + payments.join(",") + ")");
  if (products.length) filters.push("target_id.in.(" + products.join(",") + ")");
  if (filters.length) await service.from("audit_logs").delete().or(filters.join(","));
  if (orders.length) {
    await service.from("order_fulfillment_events").delete().in("order_id", orders);
    await service.from("refunds").delete().in("order_id", orders);
    await service.from("payment_submissions").delete().in("order_id", orders);
    await service.from("payments").delete().in("order_id", orders);
    await service.from("order_items").delete().in("order_id", orders);
    await service.from("orders").delete().in("id", orders);
  }
  if (products.length) {
    await service.from("product_publication_requests").delete().in("product_id", products);
    await service.from("product_public_catalog").delete().in("product_id", products);
    await service.from("products").delete().in("id", products);
  }
  if (users.length) {
    const teacherRows = requireData(await service.from("teacher_profiles").select("id").in("user_id", users), "collect Teachers");
    const teacherIds = teacherRows.map((row) => row.id);
    if (teacherIds.length) {
      await service.from("teacher_stage_capabilities").delete().in("teacher_profile_id", teacherIds);
      await service.from("teacher_specialties").delete().in("teacher_profile_id", teacherIds);
    }
    await service.from("teacher_profiles").delete().in("user_id", users);
    await service.from("student_profiles").delete().in("user_id", users);
    await service.from("public_profiles").delete().in("user_id", users);
    await service.from("user_roles").delete().in("user_id", users);
    await service.from("profiles").delete().in("user_id", users);
  }
  for (const identity of identities) await service.auth.admin.deleteUser(identity.userId);
}

async function exactCount(table, applyFilters, label) {
  const query = service.from(table).select("*", { count: "exact", head: true });
  const result = await applyFilters(query);
  if (result.error) throw new Error(label + ": " + describeError(result.error));
  return result.count ?? 0;
}

async function residueCounts() {
  const users = identities.map((identity) => identity.userId).filter(Boolean);
  const orders = [...orderIds]; const payments = [...paymentIds]; const products = [...productIds];
  const countIn = async (table, column, values) => values.length ? exactCount(table, (query) => query.in(column, values), table) : 0;
  const counts = {
    auditRows: 0, authUsers: 0,
    orderItems: await countIn("order_items", "order_id", orders), orders: await countIn("orders", "id", orders),
    outboxRows: await countIn("order_fulfillment_events", "order_id", orders),
    paymentSubmissions: await countIn("payment_submissions", "order_id", orders),
    payments: await countIn("payments", "id", payments), products: await countIn("products", "id", products),
    profiles: await countIn("profiles", "user_id", users), refunds: await countIn("refunds", "order_id", orders),
    studentProfiles: await countIn("student_profiles", "user_id", users),
    teacherProfiles: await countIn("teacher_profiles", "user_id", users),
  };
  const filters = [];
  if (users.length) filters.push("actor_user_id.in.(" + users.join(",") + ")");
  if (orders.length) filters.push("target_id.in.(" + orders.join(",") + ")");
  if (payments.length) filters.push("target_id.in.(" + payments.join(",") + ")");
  if (products.length) filters.push("target_id.in.(" + products.join(",") + ")");
  if (filters.length) counts.auditRows = await exactCount("audit_logs", (query) => query.or(filters.join(",")), "audit residue");
  for (const identity of identities) { const result = await service.auth.admin.getUserById(identity.userId); if (result.data?.user) counts.authUsers += 1; }
  return counts;
}

let studentA; let studentB; let teacherA; let teacherB; let adminA; let adminSessionB;
let platformProduct; let comingSoonProduct; let teacherProduct; let mainOrderId; let mainPaymentId;

console.log("RUN_TAG " + RUN_TAG);

try {
  studentA = await createIdentity("student-a"); studentB = await createIdentity("student-b");
  teacherA = await createIdentity("teacher-a", ["teacher"]); teacherB = await createIdentity("teacher-b", ["teacher"]);
  adminA = await createIdentity("admin-a", ["admin"]); adminSessionB = await signIn(adminA.email);
  await Promise.all([createStudentProfile(studentA), createStudentProfile(studentB), createTeacherProfile(teacherA, "teacher-a"), createTeacherProfile(teacherB, "teacher-b")]);
  [platformProduct, comingSoonProduct, teacherProduct] = await Promise.all([
    createProduct({ slugSuffix: "platform" }), createProduct({ slugSuffix: "coming-soon", purchasable: false }),
    createProduct({ slugSuffix: "teacher", owner: "teacher", teacher: teacherA, price: 2400 }),
  ]);

  await run(1, "Public Product catalog", async () => {
    const rows = requireData(await anon.from("product_public_catalog").select("public_slug,name,short_description,description,currency,base_price_amount,product_type,owner_type,seller_display_name,seller_public_slug,is_purchasable,published_at,updated_at").eq("public_slug", platformProduct.public_slug), "public Product");
    assert(rows.length === 1 && rows[0].is_purchasable, "public Product missing");
    expectDenied(await anon.from("product_public_catalog").select("product_id").eq("public_slug", platformProduct.public_slug), "technical Product ID");
    expectDenied(await anon.from("products").select("metadata"), "anonymous metadata");
    return "safe projection visible; technical/private columns denied";
  });

  await run(2, "Coming Soon behavior", async () => {
    const rows = requireData(await anon.from("product_public_catalog").select("public_slug,is_purchasable").eq("public_slug", comingSoonProduct.public_slug), "Coming Soon catalog");
    assert(rows.length === 1 && rows[0].is_purchasable === false, "Coming Soon DTO mismatch");
    expectDenied(await studentA.client.rpc("create_checkout_order", {p_idempotency_key:randomUUID(),p_product_slug:comingSoonProduct.public_slug,p_quantity:1}), "Coming Soon checkout", ["P0001"]);
    return "public with is_purchasable=false; DB checkout rejected";
  });

  await run(3, "Teacher-owned Product", async () => {
    const rows = requireData(await anon.from("product_public_catalog").select("public_slug,seller_display_name,seller_public_slug").eq("public_slug", teacherProduct.public_slug), "Teacher Product catalog");
    assert(rows.length === 1 && rows[0].seller_public_slug === teacherA.teacherSlug, "Teacher seller mismatch");
    expectDenied(await teacherA.client.from("payments").select("*"), "Teacher finance read");
    return "safe Teacher seller fields visible; finance denied";
  });

  await run(4, "Checkout, price authority, and snapshots", async () => {
    const key=randomUUID(); mainOrderId=await checkout(studentA,platformProduct,key,2); const state=await inspectOrder(mainOrderId);
    assert(state.order.buyer_user_id===studentA.userId,"Order buyer mismatch");
    assert(state.order.status==="awaiting_payment"&&state.order.payment_status==="unpaid","initial Order state mismatch");
    assert(state.items.length===1&&state.items[0].quantity===2,"Item snapshot missing");
    assert(state.items[0].unit_price_amount===3200&&state.order.total_amount===6400,"authoritative total mismatch");
    expectDenied(await studentA.client.from("orders").update({total_amount:1}).eq("id",mainOrderId),"client total override");
    for(const quantity of [0,101]) expectDenied(await studentA.client.rpc("create_checkout_order",{p_idempotency_key:randomUUID(),p_product_slug:platformProduct.public_slug,p_quantity:quantity}),"invalid quantity");
    expectDenied(await studentA.client.rpc("create_checkout_order",{p_currency:"USD",p_idempotency_key:randomUUID(),p_product_slug:platformProduct.public_slug,p_quantity:1}),"currency override");
    requireData(await service.from("products").update({base_price_amount:3900}).eq("id",platformProduct.id),"change Product price");
    const unchanged=requireData(await service.from("order_items").select("unit_price_amount").eq("order_id",mainOrderId).single(),"snapshot after price change");
    assert(unchanged.unit_price_amount===3200,"Order snapshot changed");
    return "DB calculated TWD 6400; overrides denied; snapshot stayed 3200";
  });

  await run(5, "Checkout idempotency and buyer scope", async () => {
    const sameKey=requireData(await service.from("orders").select("idempotency_key").eq("id",mainOrderId).single(),"main key").idempotency_key;
    const retry=await checkout(studentA,platformProduct,sameKey,2); assert(retry===mainOrderId,"retry returned different Order");
    assert(await exactCount("orders",(query)=>query.eq("buyer_user_id",studentA.userId).eq("idempotency_key",sameKey),"A key")===1,"duplicate Order");
    assert(await exactCount("order_items",(query)=>query.eq("order_id",mainOrderId),"main Items")===1,"duplicate Item");
    const bOrder=await checkout(studentB,platformProduct,sameKey,1); assert(bOrder!==mainOrderId,"buyer scope collision");
    assert(requireData(await studentB.client.from("orders").select("id").eq("id",mainOrderId),"cross read").length===0,"cross-buyer read");
    const parallelKey=randomUUID(); const session=await signIn(studentA.email);
    const outcomes=await Promise.all([studentA.client.rpc("create_checkout_order",{p_product_slug:platformProduct.public_slug,p_quantity:1,p_idempotency_key:parallelKey}),session.rpc("create_checkout_order",{p_product_slug:platformProduct.public_slug,p_quantity:1,p_idempotency_key:parallelKey})]);
    for(const outcome of outcomes){if(outcome.error)recordRaceError(outcome.error);requireData(outcome,"concurrent checkout");orderIds.add(outcome.data)}
    assert(outcomes[0].data===outcomes[1].data,"concurrent IDs differ");
    return "sequential/concurrent retry same ID; Buyer B independent";
  });

  await run(6, "Inactive and archived Product denial", async () => {
    const inactive=await createProduct({slugSuffix:"inactive",status:"draft",purchasable:false});
    expectDenied(await studentA.client.rpc("create_checkout_order",{p_product_slug:inactive.public_slug,p_quantity:1,p_idempotency_key:randomUUID()}),"inactive Product",["P0001"]);
    requireData(await service.from("products").update({status:"archived",archived_at:new Date().toISOString()}).eq("id",inactive.id),"archive fixture");
    expectDenied(await studentA.client.rpc("create_checkout_order",{p_product_slug:inactive.public_slug,p_quantity:1,p_idempotency_key:randomUUID()}),"archived Product",["P0001"]);
    return "draft and archived Products rejected";
  });

  await run(7, "Bank submission ownership and isolation", async () => {
    mainPaymentId=await submitBank(studentA,mainOrderId,randomUUID(),"54321");
    expectDenied(await studentB.client.rpc("submit_bank_transfer",{p_idempotency_key:randomUUID(),p_order_id:mainOrderId,p_payer_name:"Wrong Buyer",p_payment_note:"fake",p_transfer_last5:"11111"}),"Student B submission",["42501"]);
    for(const [label,client] of [["anonymous",anon],["Student B",studentB.client],["Teacher",teacherA.client]]) expectDenied(await client.from("payment_submissions").select("payer_name,transfer_last5").eq("order_id",mainOrderId),label+" evidence");
    const own=requireData(await studentA.client.rpc("get_own_payment_summaries",{p_order_id:mainOrderId}),"own Payment DTO");
    assert(own.length===1&&own[0].id===mainPaymentId,"safe DTO missing");
    return "own fake submission accepted; evidence isolated";
  });

  await run(8, "Non-Admin confirmation denial", async () => {
    const args={p_order_id:mainOrderId,p_payment_id:mainPaymentId,p_provider_event_id:RUN_TAG+"-bank-main",p_reason:"Fake bank review"};
    expectDenied(await studentA.client.rpc("admin_confirm_payment",args),"Student confirm",["42501"]);
    expectDenied(await teacherA.client.rpc("admin_confirm_payment",args),"Teacher confirm",["42501"]);
    assert(await exactCount("audit_logs",(query)=>query.eq("target_id",mainPaymentId).eq("action","payment.confirmed"),"denied audit")===0,"denied audit created");
    return "Student/Teacher denied; no audit";
  });

  await run(9, "Admin bank confirmation and retry", async () => {
    const event=RUN_TAG+"-bank-main"; const args={p_order_id:mainOrderId,p_payment_id:mainPaymentId,p_provider_event_id:event,p_reason:"Fake bank review"};
    requireData(await adminA.client.rpc("admin_confirm_payment",args),"Admin bank confirm"); let state=await inspectOrder(mainOrderId);
    const payment=state.payments.find((row)=>row.id===mainPaymentId); const submission=state.submissions.find((row)=>row.payment_id===mainPaymentId);
    assert(state.order.status==="paid"&&state.order.payment_status==="paid"&&state.order.paid_at,"Order not paid");
    assert(payment?.status==="paid"&&payment.amount===state.order.total_amount&&payment.currency===state.order.currency,"Payment mismatch");
    assert(submission?.status==="approved"&&paymentAuditCount(state)===1&&state.outbox.length===1,"submission/audit/outbox mismatch");
    requireData(await adminA.client.rpc("admin_confirm_payment",args),"same Payment retry"); state=await inspectOrder(mainOrderId);
    assert(state.payments.filter((row)=>row.status==="paid").length===1&&paymentAuditCount(state)===1&&state.outbox.length===1,"retry duplicated effects");
    expectDenied(await adminA.client.rpc("admin_confirm_payment",{...args,p_provider_event_id:RUN_TAG+"-different-event"}),"different event",["P0001"]);
    return "paid atomically; same event idempotent; different event rejected";
  });

  await run(10, "Second Payment and provider event safety", async () => {
    const second=await insertPayment(mainOrderId,"second-main");
    expectDenied(await adminA.client.rpc("admin_confirm_payment",{p_order_id:mainOrderId,p_payment_id:second,p_provider_event_id:RUN_TAG+"-second",p_reason:"Second attempt"}),"second paid attempt",["P0001"]);
    let state=await inspectOrder(mainOrderId);
    assert(state.payments.filter((row)=>row.status==="paid").length===1&&state.payments.find((row)=>row.id===second)?.status==="pending","second Payment changed");
    assert(paymentAuditCount(state)===1&&state.outbox.length===1,"second Payment added effects");
    const eventOrder=await checkout(studentA,platformProduct,randomUUID(),1); const eventPayment=await insertPayment(eventOrder,"event-reuse");
    expectDenied(await adminA.client.rpc("admin_confirm_payment",{p_order_id:eventOrder,p_payment_id:eventPayment,p_provider_event_id:RUN_TAG+"-bank-main",p_reason:"Reused event"}),"event reuse",["P0001"]);
    return "second unchanged; one paid/audit/outbox; reused event rejected";
  });

  await run(11, "Cash confirmation", async () => {
    const order=await checkout(studentA,platformProduct,randomUUID(),1); const key=randomUUID();
    expectDenied(await studentA.client.rpc("admin_confirm_cash_payment",{p_order_id:order,p_idempotency_key:key,p_reason:"Fake cash"}),"non-Admin cash",["42501"]);
    const paymentId=requireData(await adminA.client.rpc("admin_confirm_cash_payment",{p_order_id:order,p_idempotency_key:key,p_reason:"Fake cash received"}),"Admin cash"); paymentIds.add(paymentId);
    const state=await inspectOrder(order); const payment=state.payments.find((row)=>row.id===paymentId);
    assert(payment?.status==="paid"&&payment.amount===state.order.total_amount&&state.order.status==="paid","cash mismatch");
    assert(paymentAuditCount(state)===1&&state.outbox.length===1,"cash effects mismatch");
    return "authoritative cash amount; one audit/outbox; non-Admin denied";
  });

  await run(12, "Bank versus cash race", async () => {
    const order=await checkout(studentA,platformProduct,randomUUID(),1); const bank=await submitBank(studentA,order,randomUUID(),"20001"); const cashKey=randomUUID();
    const outcomes=await Promise.all([
      adminA.client.rpc("admin_confirm_payment",{p_order_id:order,p_payment_id:bank,p_provider_event_id:RUN_TAG+"-bank-cash-bank",p_reason:"Bank race"}),
      adminSessionB.rpc("admin_confirm_cash_payment",{p_order_id:order,p_idempotency_key:cashKey,p_reason:"Cash race"}),
    ]);
    await expectOneRaceWinner(outcomes,"bank vs cash"); const state=await inspectOrder(order);
    const valid=state.order.status==="paid"&&state.payments.filter((row)=>row.status==="paid").length===1&&paymentAuditCount(state)===1&&state.outbox.length===1;
    if(!valid)concurrency.partial+=1; assert(valid,"bank/cash partial state");
    for(const row of state.payments)paymentIds.add(row.id);
    return "one paid Payment, financial audit, and outbox; loser P0001";
  });

  await run(13, "Different Payments concurrent confirmation", async () => {
    const order=await checkout(studentA,platformProduct,randomUUID(),1); const first=await submitBank(studentA,order,randomUUID(),"20002"); const second=await submitBank(studentA,order,randomUUID(),"20003");
    const outcomes=await Promise.all([
      adminA.client.rpc("admin_confirm_payment",{p_order_id:order,p_payment_id:first,p_provider_event_id:RUN_TAG+"-different-a",p_reason:"Payment A"}),
      adminSessionB.rpc("admin_confirm_payment",{p_order_id:order,p_payment_id:second,p_provider_event_id:RUN_TAG+"-different-b",p_reason:"Payment B"}),
    ]);
    await expectOneRaceWinner(outcomes,"different Payments"); const state=await inspectOrder(order);
    const valid=state.order.status==="paid"&&state.payments.filter((row)=>row.status==="paid").length===1&&paymentAuditCount(state)===1&&state.outbox.length===1;
    if(!valid)concurrency.partial+=1; assert(valid,"different-Payment partial state");
    return "exactly one Payment/audit/outbox; loser P0001";
  });

  await run(14, "Confirm versus reject race", async () => {
    const order=await checkout(studentA,platformProduct,randomUUID(),1); const payment=await submitBank(studentA,order,randomUUID(),"20004");
    const outcomes=await Promise.all([
      adminA.client.rpc("admin_confirm_payment",{p_order_id:order,p_payment_id:payment,p_provider_event_id:RUN_TAG+"-confirm-reject",p_reason:"Confirm race"}),
      adminSessionB.rpc("admin_reject_payment_submission",{p_payment_id:payment,p_reason:"Reject race"}),
    ]);
    await expectOneRaceWinner(outcomes,"confirm vs reject"); const state=await inspectOrder(order); const p=state.payments[0]; const s=state.submissions[0];
    const paid=state.order.status==="paid"&&state.order.payment_status==="paid"&&p.status==="paid"&&s.status==="approved"&&state.outbox.length===1;
    const rejected=state.order.status==="awaiting_payment"&&state.order.payment_status==="failed"&&p.status==="failed"&&s.status==="rejected"&&state.outbox.length===0;
    const auditCount=state.audits.filter((row)=>row.target_id===payment&&["payment.confirmed","payment_submission.rejected"].includes(row.action)).length;
    if(!(paid||rejected)||auditCount!==1)concurrency.partial+=1; assert((paid||rejected)&&auditCount===1,"confirm/reject partial state");
    return paid?"confirm won with paid/approved":"reject won with failed/rejected";
  });

  await run(15, "Buyer cancellation", async () => {
    const order=await checkout(studentA,platformProduct,randomUUID(),1); const payment=await submitBank(studentA,order,randomUUID(),"20005");
    expectDenied(await studentB.client.rpc("cancel_own_order",{p_order_id:order,p_reason:"Wrong buyer"}),"cross-buyer cancel",["42501"]);
    requireData(await studentA.client.rpc("cancel_own_order",{p_order_id:order,p_reason:"Fake Buyer cancellation"}),"Buyer cancel");
    requireData(await studentA.client.rpc("cancel_own_order",{p_order_id:order,p_reason:"Retry"}),"Buyer cancel retry");
    const state=await inspectOrder(order); const audits=requireData(await service.from("audit_logs").select("id").eq("target_id",order).eq("action","buyer_cancel_order"),"Buyer audit");
    assert(state.order.status==="cancelled"&&state.order.cancelled_at&&state.payments.find((row)=>row.id===payment)?.status==="cancelled","Buyer cancel state mismatch");
    assert(audits.length===1,"Buyer cancel audit duplicated");
    expectDenied(await studentA.client.rpc("cancel_own_order",{p_order_id:mainOrderId,p_reason:"Paid cancel"}),"paid Buyer cancel",["P0001"]);
    return "own open Order cancelled and audited once; cross-buyer/paid denied";
  });

  await run(16, "Admin cancellation", async () => {
    const order=await checkout(studentA,platformProduct,randomUUID(),1); const args={p_order_id:order,p_reason:"Fake Admin cancellation"};
    expectDenied(await studentA.client.rpc("admin_cancel_order",args),"non-Admin cancellation",["42501"]);
    requireData(await adminA.client.rpc("admin_cancel_order",args),"Admin cancellation"); const row=requireData(await service.from("orders").select("status,cancelled_at").eq("id",order).single(),"cancelled Order");
    assert(row.status==="cancelled"&&row.cancelled_at,"Admin cancel state mismatch");
    assert(await exactCount("audit_logs",(query)=>query.eq("target_id",order).eq("action","order.cancelled"),"Admin cancel audit")===1,"Admin cancel audit missing");
    return "non-Admin denied; Admin state and durable audit verified";
  });

  await run(17, "Expiry rules", async () => {
    const expiredOrder=await checkout(studentA,platformProduct,randomUUID(),1); requireData(await service.from("orders").update({expires_at:new Date(Date.now()-60000).toISOString()}).eq("id",expiredOrder),"backdate expiry");
    requireData(await adminA.client.rpc("admin_expire_order",{p_order_id:expiredOrder,p_reason:"Fake expiry"}),"expire Order");
    const row=requireData(await service.from("orders").select("status").eq("id",expiredOrder).single(),"expired state"); assert(row.status==="expired","expiry state mismatch");
    assert(await exactCount("audit_logs",(query)=>query.eq("target_id",expiredOrder).eq("action","order.expired"),"expiry audit")===1,"expiry audit missing");
    const futureOrder=await checkout(studentA,platformProduct,randomUUID(),1);
    expectDenied(await adminA.client.rpc("admin_expire_order",{p_order_id:futureOrder,p_reason:"Too early"}),"future expiry",["P0001"]);
    expectDenied(await adminA.client.rpc("admin_expire_order",{p_order_id:mainOrderId,p_reason:"Paid expiry"}),"paid expiry",["P0001"]);
    return "past-due expired/audited; future and paid denied";
  });

  await run(18, "Cancel versus payment race", async () => {
    const order=await checkout(studentA,platformProduct,randomUUID(),1); const payment=await submitBank(studentA,order,randomUUID(),"20006");
    const outcomes=await Promise.all([
      adminA.client.rpc("admin_confirm_payment",{p_order_id:order,p_payment_id:payment,p_provider_event_id:RUN_TAG+"-cancel-pay",p_reason:"Pay race"}),
      adminSessionB.rpc("admin_cancel_order",{p_order_id:order,p_reason:"Cancel race"}),
    ]);
    await expectOneRaceWinner(outcomes,"cancel vs payment"); const state=await inspectOrder(order);
    const paid=state.order.status==="paid"&&state.order.payment_status==="paid"&&state.payments[0].status==="paid"&&state.outbox.length===1;
    const cancelled=state.order.status==="cancelled"&&state.order.payment_status==="unpaid"&&state.payments[0].status==="cancelled"&&state.outbox.length===0;
    if(!(paid||cancelled))concurrency.partial+=1; assert(paid||cancelled,"cancel/payment partial state");
    return paid?"payment won consistently":"cancellation won consistently";
  });

  await run(19, "Expire versus payment race", async () => {
    const order=await checkout(studentA,platformProduct,randomUUID(),1); const payment=await submitBank(studentA,order,randomUUID(),"20007");
    requireData(await service.from("orders").update({expires_at:new Date(Date.now()-60000).toISOString()}).eq("id",order),"backdate race Order");
    const outcomes=await Promise.all([
      adminA.client.rpc("admin_confirm_payment",{p_order_id:order,p_payment_id:payment,p_provider_event_id:RUN_TAG+"-expire-pay",p_reason:"Pay race"}),
      adminSessionB.rpc("admin_expire_order",{p_order_id:order,p_reason:"Expire race"}),
    ]);
    await expectOneRaceWinner(outcomes,"expire vs payment"); const state=await inspectOrder(order);
    const paid=state.order.status==="paid"&&state.order.payment_status==="paid"&&state.payments[0].status==="paid"&&state.outbox.length===1;
    const expired=state.order.status==="expired"&&state.order.payment_status==="unpaid"&&state.payments[0].status==="cancelled"&&state.outbox.length===0;
    if(!(paid||expired))concurrency.partial+=1; assert(paid||expired,"expire/payment partial state");
    return paid?"payment won consistently":"expiry won consistently";
  });

  await run(20, "Teacher paused/private/suspended revocation", async () => {
    const attempt=async(label)=>expectDenied(await studentA.client.rpc("create_checkout_order",{p_product_slug:teacherProduct.public_slug,p_quantity:1,p_idempotency_key:randomUUID()}),label,["P0001"]);
    requireData(await service.from("teacher_profiles").update({teaching_status:"paused"}).eq("user_id",teacherA.userId),"pause Teacher");
    assert(requireData(await anon.from("product_public_catalog").select("public_slug").eq("public_slug",teacherProduct.public_slug),"paused catalog").length===0,"paused Product public"); await attempt("paused checkout");
    requireData(await service.from("teacher_profiles").update({teaching_status:"active",is_public:false}).eq("user_id",teacherA.userId),"private Teacher"); await attempt("private checkout");
    requireData(await service.from("teacher_profiles").update({is_public:true}).eq("user_id",teacherA.userId),"restore public Teacher");
    requireData(await service.from("profiles").update({account_status:"suspended"}).eq("user_id",teacherA.userId),"suspend Teacher");
    assert(requireData(await anon.from("product_public_catalog").select("public_slug").eq("public_slug",teacherProduct.public_slug),"suspended catalog").length===0,"suspended Product public"); await attempt("suspended checkout");
    requireData(await service.from("profiles").update({account_status:"active"}).eq("user_id",teacherA.userId),"restore Teacher account");
    const restored=await checkout(studentA,teacherProduct,randomUUID(),1); assert(restored,"restored Teacher checkout failed");
    return "paused/private/suspended denied and hidden; fully restored checkout succeeded";
  });

  await run(21, "Teacher role revocation", async () => {
    const draft=await createProduct({slugSuffix:"role-draft",owner:"teacher",teacher:teacherA,status:"draft",purchasable:false});
    requireData(await service.from("user_roles").delete().eq("user_id",teacherA.userId).eq("role","teacher"),"remove Teacher role");
    expectDenied(await studentA.client.rpc("create_checkout_order",{p_product_slug:teacherProduct.public_slug,p_quantity:1,p_idempotency_key:randomUUID()}),"role-removed checkout",["P0001"]);
    expectDenied(await teacherA.client.rpc("update_own_draft_product",{p_product_id:draft.id,p_name:"Denied",p_short_description:"Denied",p_description:"Denied"}),"role-removed mutation",["42501"]);
    requireData(await service.from("user_roles").insert({user_id:teacherA.userId,role:"teacher"}),"restore Teacher role");
    requireData(await teacherA.client.rpc("update_own_draft_product",{p_product_id:draft.id,p_name:"Restored Fake Draft",p_short_description:"Restored",p_description:"Restored"}),"restored Teacher mutation");
    await checkout(studentA,teacherProduct,randomUUID(),1);
    return "checkout and mutation denied without role; restored after role assignment";
  });

  await run(22, "Teacher archive", async () => {
    const product=await createProduct({slugSuffix:"archive",owner:"teacher",teacher:teacherA,price:1800});
    requireData(await service.from("product_publication_requests").insert({product_id:product.id,teacher_user_id:teacherA.userId,status:"pending",note:RUN_TAG+" fake request"}),"publication fixture");
    expectDenied(await teacherB.client.rpc("archive_own_product",{p_product_id:product.id}),"cross-Teacher archive",["42501"]);
    requireData(await teacherA.client.rpc("archive_own_product",{p_product_id:product.id}),"Teacher archive");
    const row=requireData(await service.from("products").select("status,is_public,is_purchasable").eq("id",product.id).single(),"archived Product");
    const request=requireData(await service.from("product_publication_requests").select("status").eq("product_id",product.id).single(),"archive request");
    assert(row.status==="archived"&&!row.is_public&&!row.is_purchasable&&request.status==="cancelled","archive state mismatch");
    assert(requireData(await anon.from("product_public_catalog").select("public_slug").eq("public_slug",product.public_slug),"archive catalog").length===0,"archived Product public");
    expectDenied(await studentA.client.rpc("create_checkout_order",{p_product_slug:product.public_slug,p_quantity:1,p_idempotency_key:randomUUID()}),"archived checkout",["P0001"]);
    assert(await exactCount("audit_logs",(query)=>query.eq("target_id",product.id).eq("action","teacher_archive_product"),"archive audit")===1,"archive audit missing");
    return "ownership enforced; state/request/catalog/checkout/audit consistent";
  });

  await run(23, "RLS and finance isolation", async () => {
    const privateTables=["payments","payment_submissions","refunds","audit_logs","order_fulfillment_events"];
    for(const [label,client] of [["anon",anon],["Student",studentA.client],["Teacher",teacherA.client]]) {
      for(const table of privateTables) expectDenied(await client.from(table).select("*"),label+" "+table);
    }
    expectDenied(await anon.from("orders").select("id"),"anon Orders"); expectDenied(await anon.from("order_items").select("id"),"anon Items");
    const own=requireData(await studentA.client.from("orders").select("id").eq("id",mainOrderId),"Student own Order"); assert(own.length===1,"Student own Order hidden");
    const other=requireData(await studentB.client.from("orders").select("id").eq("id",mainOrderId),"Student B Order"); assert(other.length===0,"cross-buyer Order visible");
    const otherItems=requireData(await studentB.client.from("order_items").select("id").eq("order_id",mainOrderId),"Student B Items"); assert(otherItems.length===0,"cross-buyer Items visible");
    const otherDto=requireData(await studentB.client.rpc("get_own_payment_summaries",{p_order_id:mainOrderId}),"Student B Payment DTO"); assert(otherDto.length===0,"cross-buyer DTO visible");
    const ownProducts=requireData(await teacherA.client.from("products").select("id").eq("id",teacherProduct.id),"Teacher own Product"); assert(ownProducts.length===1,"Teacher own Product hidden");
    const crossProducts=requireData(await teacherB.client.from("products").select("id").eq("id",teacherProduct.id),"Teacher cross Product"); assert(crossProducts.length===0,"Teacher cross Product visible");
    return "anon/private finance denied; own reads work; cross-buyer/Teacher reads empty";
  });

  await run(24, "Private helper denial", async () => {
    for(const [label,client] of [["anon",anon],["Student",studentA.client],["Teacher",teacherA.client],["Admin",adminA.client]]) {
      expectDenied(await client.rpc("teacher_owner_is_active",{teacher_user_id:teacherA.userId}),label+" private helper");
    }
    return "anon and all authenticated sessions denied direct helper execution";
  });

  await run(25, "One-paid-Payment and outbox invariants", async () => {
    await collectFixtureIds();
    const orders=requireData(await service.from("orders").select("id,status,payment_status").in("id",[...orderIds]),"all fixture Orders");
    for(const order of orders){
      const paid=await exactCount("payments",(query)=>query.eq("order_id",order.id).eq("status","paid"),"paid count");
      const events=await exactCount("order_fulfillment_events",(query)=>query.eq("order_id",order.id).eq("event_type","order.paid"),"outbox count");
      assert(paid<=1,"Order has multiple paid Payments: "+order.id);
      if(order.status==="paid")assert(paid===1&&events===1,"paid Order invariant failed: "+order.id);
      else assert(events===0,"unpaid Order has paid outbox: "+order.id);
    }
    return orders.length+" Orders checked: paid<=1; paid=>outbox 1; unpaid=>outbox 0";
  });

  await run(26, "Audit sanity", async () => {
    const users=identities.map((identity)=>identity.userId); const rows=requireData(await service.from("audit_logs").select("action,before_snapshot,after_snapshot,reason,target_id").in("actor_user_id",users),"fixture audits");
    const serialized=JSON.stringify(rows).toLowerCase();
    for(const forbidden of ["access_token","refresh_token","service_role","password","transfer_last5","provider_payload","channel_secret"]) assert(!serialized.includes(forbidden),"audit contains forbidden field: "+forbidden);
    assert(rows.some((row)=>row.action==="payment.confirmed"),"payment audit missing"); assert(rows.some((row)=>row.action==="buyer_cancel_order"),"Buyer audit missing"); assert(rows.some((row)=>row.action==="teacher_archive_product"),"archive audit missing");
    return rows.length+" minimal audits inspected; no secret/bank/token fields";
  });
} finally {
  await run(27, "Cleanup and residue", async () => {
    await cleanup(); const counts=await residueCounts();
    assert(Object.values(counts).every((value)=>value===0),"residue remains: "+JSON.stringify(counts));
    return JSON.stringify(counts);
  });

  for(const result of results) console.log("TEST "+result.number+" ["+result.status+"] "+result.name+": "+result.detail);
  console.log("CONCURRENCY 40P01="+concurrency.deadlock+" 23505="+concurrency.unique+" unexpected23xxx="+concurrency.integrity+" domain="+concurrency.domain+" partial="+concurrency.partial);
  console.log("RESULTS "+JSON.stringify(results));
  if(results.some((result)=>result.status==="FAIL")||concurrency.deadlock!==0||concurrency.unique!==0||concurrency.integrity!==0||concurrency.partial!==0) process.exitCode=1;
}
