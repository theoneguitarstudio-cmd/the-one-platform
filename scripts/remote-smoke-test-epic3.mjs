import { randomUUID } from "node:crypto";
import { readFile } from "node:fs/promises";
import process from "node:process";

import { createClient } from "@supabase/supabase-js";

const PROJECT_REF = "ygxeihtcolpiulupieeq";
const RUN_TAG =
  "epic3-smoke-" +
  new Date().toISOString().replaceAll(/[-:.TZ]/g, "").slice(0, 14) +
  "-" +
  randomUUID().slice(0, 8);
const PASSWORD = "Smoke-" + randomUUID() + "-Aa1!";
const APP_BASE_URL =
  process.argv
    .find((argument) => argument.startsWith("--app-base-url="))
    ?.slice("--app-base-url=".length) ?? "http://127.0.0.1:3103";

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
const results = [];
const cleanupLessonIds = [];

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

function expectDenied(result, label, acceptedCodes = ["42501"]) {
  assert(result.error, label + " unexpectedly succeeded");
  if (acceptedCodes.length > 0) {
    assert(
      acceptedCodes.includes(result.error.code),
      label + " returned " + describeError(result.error),
    );
  }
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

async function createIdentity(label, extraRoles = []) {
  const email = RUN_TAG + "-" + label + "@example.invalid";
  const created = await service.auth.admin.createUser({
    email,
    email_confirm: true,
    password: PASSWORD,
    user_metadata: { display_name: "Epic3 Smoke " + label },
  });
  const user = requireData(created, "create " + label).user;
  assert(user?.id, "Auth user ID missing for " + label);
  const identity = { label, email, userId: user.id, client: null, session: null };
  identities.push(identity);

  for (const role of extraRoles) {
    requireData(
      await service
        .from("user_roles")
        .upsert({ role, user_id: user.id }, { onConflict: "user_id,role" }),
      "assign " + role + " to " + label,
    );
  }

  const client = createClient(supabaseUrl, publishableKey, clientOptions);
  const signedIn = await client.auth.signInWithPassword({
    email,
    password: PASSWORD,
  });
  const authData = requireData(signedIn, "sign in " + label);
  assert(authData.session?.access_token, "Session missing for " + label);
  identity.client = client;
  identity.session = authData.session;
  return identity;
}

async function createTeacher(identity, suffix) {
  const slug = RUN_TAG + "-" + suffix;
  const row = requireData(
    await service
      .from("teacher_profiles")
      .insert({
        bio: "Remote smoke teacher " + suffix,
        default_meeting_provider: "manual_google_meet",
        default_meeting_url: "https://meet.google.com/abc-defg-hij",
        is_public: true,
        location_text: "Remote smoke location",
        public_slug: slug,
        teaching_modes: ["online", "onsite"],
        teaching_status: "active",
        trial_price_twd: 1000,
        user_id: identity.userId,
        years_experience: 5,
      })
      .select("id,public_slug")
      .single(),
    "create teacher " + suffix,
  );
  identity.teacherProfileId = row.id;
  identity.slug = row.public_slug;
  return row;
}

async function createStudentProfile(identity) {
  requireData(
    await service.from("student_profiles").upsert({
      learning_goal: "Remote smoke learning goal",
      onboarding_status: "complete",
      preferred_mode: "online",
      user_id: identity.userId,
    }),
    "create student profile " + identity.label,
  );
}

function trialRequest(identity, teacher, key, startsAt) {
  return identity.client.rpc("request_trial_checkout", {
    p_idempotency_key: key,
    p_learning_goal: "Remote smoke trial goal",
    p_preferred_location: null,
    p_preferred_mode: "online",
    p_proposed_starts_at: startsAt,
    p_teacher_slug: teacher.slug,
    p_timezone: "America/Los_Angeles",
  });
}

function completionPayload(lessonId) {
  return {
    p_assessment_summary: "Remote smoke assessment summary",
    p_homework: "Remote smoke homework",
    p_lesson_id: lessonId,
    p_next_goal: "Remote smoke next goal",
    p_performance_summary: "Remote smoke performance summary",
    p_private_teacher_notes: "Remote smoke private teacher notes",
    p_recommendation_type: "one_to_one",
    p_stage_number: 1,
    p_student_visible_notes: "Remote smoke student-visible notes",
  };
}

function sessionCookie(session) {
  const encoded =
    "base64-" + Buffer.from(JSON.stringify(session), "utf8").toString("base64url");
  const baseName = "sb-" + PROJECT_REF + "-auth-token";
  const chunkSize = 3180;
  if (encoded.length <= chunkSize) return baseName + "=" + encoded;
  const chunks = [];
  for (let offset = 0; offset < encoded.length; offset += chunkSize) {
    chunks.push(
      baseName +
        "." +
        chunks.length +
        "=" +
        encoded.slice(offset, offset + chunkSize),
    );
  }
  return chunks.join("; ");
}

async function joinLocation(lessonId, identity = null) {
  const response = await fetch(
    APP_BASE_URL + "/lesson/" + lessonId + "/join",
    {
      headers: identity ? { cookie: sessionCookie(identity.session) } : undefined,
      redirect: "manual",
    },
  );
  return { status: response.status, location: response.headers.get("location") };
}

async function updateProfile(identity, values) {
  requireData(
    await service.from("profiles").update(values).eq("user_id", identity.userId),
    "update profile " + identity.label,
  );
}

async function cleanupRace(users, orderIds) {
  await service.from("lessons").delete().in("trial_order_id", orderIds);
  await service.from("trial_orders").delete().in("id", orderIds);
  await service
    .from("student_teacher_relationships")
    .delete()
    .in("student_user_id", users.map((user) => user.userId));
}

async function concurrentConfirm(adminA, adminB, firstOrder, secondOrder) {
  return Promise.all([
    adminA.client.rpc("confirm_trial_payment", {
      p_order_id: firstOrder,
      p_starts_at: null,
    }),
    adminB.client.rpc("confirm_trial_payment", {
      p_order_id: secondOrder,
      p_starts_at: null,
    }),
  ]);
}

async function cleanup() {
  const userIds = identities.map((identity) => identity.userId).filter(Boolean);
  if (userIds.length === 0) return;
  const participantFilter =
    "student_user_id.in.(" +
    userIds.join(",") +
    "),teacher_user_id.in.(" +
    userIds.join(",") +
    ")";
  const lessons = requireData(
    await service.from("lessons").select("id").or(participantFilter),
    "list cleanup lessons",
  );
  const lessonIds = lessons.map((lesson) => lesson.id);
  cleanupLessonIds.push(...lessonIds);
  if (lessonIds.length > 0) {
    await service.from("assessments").delete().in("lesson_id", lessonIds);
    await service.from("lesson_records").delete().in("lesson_id", lessonIds);
    await service.from("lessons").delete().in("id", lessonIds);
  }
  await service.from("student_teacher_relationships").delete().or(participantFilter);
  await service.from("trial_orders").delete().or(participantFilter);
  const teacherRows = requireData(
    await service.from("teacher_profiles").select("id").in("user_id", userIds),
    "list cleanup teachers",
  );
  const teacherIds = teacherRows.map((teacher) => teacher.id);
  if (teacherIds.length > 0) {
    await service
      .from("teacher_stage_capabilities")
      .delete()
      .in("teacher_profile_id", teacherIds);
    await service
      .from("teacher_specialties")
      .delete()
      .in("teacher_profile_id", teacherIds);
    await service.from("teacher_profiles").delete().in("id", teacherIds);
  }
  await service.from("student_profiles").delete().in("user_id", userIds);
  await service.from("public_profiles").delete().in("user_id", userIds);
  await service.from("user_roles").delete().in("user_id", userIds);
  await service.from("profiles").delete().in("user_id", userIds);
  for (const identity of identities) {
    await service.auth.admin.deleteUser(identity.userId);
  }
}

async function remainingCounts() {
  const userIds = identities.map((identity) => identity.userId).filter(Boolean);
  if (userIds.length === 0) return {};
  const count = async (table, column = "user_id") => {
    const result = await service
      .from(table)
      .select("*", { count: "exact", head: true })
      .in(column, userIds);
    if (result.error) throw new Error(table + ": " + describeError(result.error));
    return result.count ?? 0;
  };
  const counts = {
    authUsers: 0,
    profiles: await count("profiles"),
    studentProfiles: await count("student_profiles"),
    teacherProfiles: await count("teacher_profiles"),
  };
  for (const identity of identities) {
    const user = await service.auth.admin.getUserById(identity.userId);
    if (user.data?.user) counts.authUsers += 1;
  }
  for (const [key, table] of [
    ["lessons", "lessons"],
    ["relationships", "student_teacher_relationships"],
    ["trialOrders", "trial_orders"],
    ["assessments", "assessments"],
  ]) {
    const result = await service
      .from(table)
      .select("*", { count: "exact", head: true })
      .or(
        "student_user_id.in.(" +
          userIds.join(",") +
          "),teacher_user_id.in.(" +
          userIds.join(",") +
          ")",
      );
    if (result.error) throw new Error(table + ": " + describeError(result.error));
    counts[key] = result.count ?? 0;
  }
  if (cleanupLessonIds.length > 0) {
    counts.lessonRecords = await (async () => {
      const result = await service
        .from("lesson_records")
        .select("*", { count: "exact", head: true })
        .in("lesson_id", cleanupLessonIds);
      if (result.error) {
        throw new Error("lesson_records: " + describeError(result.error));
      }
      return result.count ?? 0;
    })();
  } else {
    counts.lessonRecords = 0;
  }
  return counts;
}

let studentA;
let studentB;
let teacherA;
let teacherB;
let adminA;
let mainOrderId;
let mainLessonId;
let mainRelationshipId;
let teacherBLessonId;
let adjacentLessonId;
let studentCollisionOrder;
const mainStart = new Date(Date.now() + 72 * 60 * 60 * 1000);
mainStart.setUTCSeconds(0, 0);
const mainStartIso = mainStart.toISOString();

console.log("RUN_TAG " + RUN_TAG);

try {
  await run(1, "Create identities and domain fixtures", async () => {
    studentA = await createIdentity("student-a");
    studentB = await createIdentity("student-b");
    teacherA = await createIdentity("teacher-a", ["teacher"]);
    teacherB = await createIdentity("teacher-b", ["teacher"]);
    adminA = await createIdentity("admin-a", ["admin"]);
    await Promise.all([
      createStudentProfile(studentA),
      createStudentProfile(studentB),
      createTeacher(teacherA, "teacher-a"),
      createTeacher(teacherB, "teacher-b"),
      updateProfile(studentA, { timezone: "America/Los_Angeles" }),
      updateProfile(teacherA, { timezone: "Asia/Taipei" }),
    ]);
    const specialties = requireData(
      await anon.from("specialties").select("id").limit(1),
      "read specialties catalog",
    );
    assert(specialties.length === 1, "specialty catalog is empty");
    for (const teacher of [teacherA, teacherB]) {
      requireData(
        await service.from("teacher_specialties").insert({
          specialty_id: specialties[0].id,
          teacher_profile_id: teacher.teacherProfileId,
        }),
        "assign teacher specialty",
      );
      requireData(
        await service.from("teacher_stage_capabilities").insert({
          capability_status: "certified",
          stage_number: 1,
          teacher_profile_id: teacher.teacherProfileId,
        }),
        "assign teacher stage",
      );
    }
    return "5 authenticated identities and all required domain fixtures created";
  });

  await run(2, "Anonymous privacy and public discovery", async () => {
    for (const table of [
      "student_profiles",
      "student_teacher_relationships",
      "trial_orders",
      "lessons",
      "lesson_records",
      "assessments",
    ]) {
      const result = await anon.from(table).select("*").limit(1);
      assert(result.error, "anonymous unexpectedly read " + table);
    }
    const publicRows = requireData(
      await anon
        .from("teacher_public_profiles")
        .select("*")
        .eq("public_slug", teacherA.slug),
      "anonymous Teacher discovery",
    );
    assert(publicRows.length === 1, "public Teacher A was not discoverable");
    const serialized = JSON.stringify(publicRows[0]).toLowerCase();
    for (const forbidden of [
      "email",
      "phone",
      "meeting",
      "private",
      "account_status",
      "idempotency",
    ]) {
      assert(!serialized.includes(forbidden), "public payload exposed " + forbidden);
    }
    assert(
      publicRows[0].teacher_profile_id !== teacherA.userId,
      "public payload exposed auth UUID",
    );
    return "private tables denied; minimal public Teacher projection visible";
  });

  await run(3, "Student checkout", async () => {
    mainOrderId = requireData(
      await trialRequest(
        studentA,
        teacherA,
        RUN_TAG + "-checkout-main",
        mainStartIso,
      ),
      "request checkout",
    );
    const order = requireData(
      await service
        .from("trial_orders")
        .select("*")
        .eq("id", mainOrderId)
        .single(),
      "read pending order",
    );
    assert(order.payment_status === "pending", "trial order was not pending");
    const relationships = requireData(
      await service
        .from("student_teacher_relationships")
        .select("id")
        .eq("student_user_id", studentA.userId)
        .eq("teacher_user_id", teacherA.userId),
      "check pre-payment relationship",
    );
    const lessons = requireData(
      await service.from("lessons").select("id").eq("trial_order_id", mainOrderId),
      "check pre-payment lesson",
    );
    assert(
      relationships.length === 0 && lessons.length === 0,
      "checkout created premature domain rows",
    );
    return "pending order only; no relationship or lesson";
  });

  await run(4, "Checkout idempotency", async () => {
    const retry = requireData(
      await trialRequest(
        studentA,
        teacherA,
        RUN_TAG + "-checkout-main",
        mainStartIso,
      ),
      "retry checkout",
    );
    assert(retry === mainOrderId, "retry returned a different order ID");
    const rows = requireData(
      await service
        .from("trial_orders")
        .select("id")
        .eq("student_user_id", studentA.userId)
        .eq("idempotency_key", RUN_TAG + "-checkout-main"),
      "count retry orders",
    );
    assert(rows.length === 1, "idempotent retry created duplicate rows");
    return "same order ID; one pending row";
  });

  await run(5, "Same pair second intent", async () => {
    const second = await trialRequest(
      studentA,
      teacherA,
      RUN_TAG + "-checkout-second",
      mainStartIso,
    );
    expectDenied(second, "second active Trial intent", ["23514"]);
    return "stable domain rejection without duplicate order";
  });

  await run(6, "Non-admin payment confirmation denied", async () => {
    for (const identity of [studentA, teacherA]) {
      expectDenied(
        await identity.client.rpc("confirm_trial_payment", {
          p_order_id: mainOrderId,
          p_starts_at: null,
        }),
        identity.label + " payment confirmation",
      );
    }
    return "Student and Teacher sessions both denied";
  });

  await run(7, "Admin payment confirmation", async () => {
    mainLessonId = requireData(
      await adminA.client.rpc("confirm_trial_payment", {
        p_order_id: mainOrderId,
        p_starts_at: null,
      }),
      "Admin confirm payment",
    );
    const order = requireData(
      await service.from("trial_orders").select("*").eq("id", mainOrderId).single(),
      "read paid order",
    );
    const lessons = requireData(
      await service.from("lessons").select("*").eq("id", mainLessonId),
      "read created lesson",
    );
    const relationships = requireData(
      await service
        .from("student_teacher_relationships")
        .select("*")
        .eq("student_user_id", studentA.userId)
        .eq("teacher_user_id", teacherA.userId),
      "read created relationship",
    );
    assert(order.payment_status === "paid", "order did not become paid");
    assert(lessons.length === 1, "payment did not create exactly one lesson");
    assert(
      relationships.length === 1,
      "payment did not create exactly one relationship",
    );
    const lesson = lessons[0];
    mainRelationshipId = relationships[0].id;
    assert(relationships[0].relationship_status === "trial", "relationship is not trial");
    assert(
      lesson.lesson_type === "trial" &&
        lesson.status === "scheduled" &&
        lesson.duration_minutes === 50,
      "created lesson invariant mismatch",
    );
    assert(
      Date.parse(lesson.ends_at) - Date.parse(lesson.starts_at) ===
        50 * 60 * 1000,
      "lesson duration instant mismatch",
    );
    return "paid; one Trial relationship; one scheduled 50-minute lesson";
  });

  await run(8, "Timezone and UTC instant", async () => {
    const lesson = requireData(
      await service
        .from("lessons")
        .select("starts_at,ends_at,timezone_anchor")
        .eq("id", mainLessonId)
        .single(),
      "read lesson timezone",
    );
    assert(
      Date.parse(lesson.starts_at) === Date.parse(mainStartIso),
      "stored instant differs from requested UTC instant",
    );
    assert(
      lesson.timezone_anchor === "America/Los_Angeles",
      "timezone anchor mismatch",
    );
    const instant = new Date(lesson.starts_at);
    const studentLocal = new Intl.DateTimeFormat("en-CA", {
      dateStyle: "short",
      timeStyle: "short",
      timeZone: "America/Los_Angeles",
    }).format(instant);
    const teacherLocal = new Intl.DateTimeFormat("en-CA", {
      dateStyle: "short",
      timeStyle: "short",
      timeZone: "Asia/Taipei",
    }).format(instant);
    assert(studentLocal !== teacherLocal, "IANA timezone displays were not distinct");
    return "UTC instant preserved; Los Angeles and Taipei rendered via IANA zones";
  });

  await run(9, "Meeting URL validation", async () => {
    for (const [provider, url] of [
      ["manual_google_meet", "https://meet.google.com/abc-defg-hij"],
      ["manual_zoom", "https://zoom.us/j/123456789"],
      ["manual_zoom", "https://us02web.zoom.us/j/123456789"],
    ]) {
      requireData(
        await teacherA.client.rpc("update_own_teacher_meeting_defaults", {
          p_provider: provider,
          p_url: url,
        }),
        "valid meeting " + url,
      );
    }
    for (const [provider, url] of [
      ["manual_google_meet", "https://meet.google.com.evil.example/room"],
      ["manual_google_meet", "https://meet.google.com@evil.example/room"],
      ["manual_google_meet", "http://meet.google.com/room"],
      ["manual_google_meet", "https://127.0.0.1/room"],
      ["manual_google_meet", "https://localhost/room"],
      ["manual_url", "https://example.com/room"],
      ["manual_zoom", "https://zoom.us.evil.example/j/123"],
      ["manual_zoom", "https://meet.google.com/abc-defg-hij"],
    ]) {
      expectDenied(
        await teacherA.client.rpc("update_own_teacher_meeting_defaults", {
          p_provider: provider,
          p_url: url,
        }),
        "invalid meeting " + url,
        ["23514"],
      );
    }
    requireData(
      await teacherA.client.rpc("update_own_teacher_meeting_defaults", {
        p_provider: "manual_google_meet",
        p_url: "https://meet.google.com/abc-defg-hij",
      }),
      "restore Google Meet",
    );
    return "allowlists accepted; spoof, HTTP, loopback, manual_url and mismatch denied";
  });
  await run(10, "Join authorization", async () => {
    for (const identity of [studentA, teacherA]) {
      const response = await joinLocation(mainLessonId, identity);
      assert(
        response.status >= 300 &&
          response.status < 400 &&
          response.location?.startsWith("https://meet.google.com/"),
        identity.label + " did not receive authorized meeting redirect",
      );
    }
    for (const identity of [studentB, teacherB]) {
      const response = await joinLocation(mainLessonId, identity);
      assert(
        response.status >= 300 &&
          response.status < 400 &&
          response.location?.includes("/auth/access-denied"),
        identity.label + " received unauthorized join access",
      );
    }
    const anonymous = await joinLocation(mainLessonId);
    assert(
      anonymous.status >= 300 &&
        anonymous.status < 400 &&
        anonymous.location?.includes("/auth/sign-in"),
      "anonymous join did not redirect to sign-in",
    );
    return "participants redirected to Meet; outsiders denied; anonymous sent to sign-in";
  });

  await run(11, "Student privacy", async () => {
    const ownRelationship = requireData(
      await studentA.client
        .from("student_teacher_relationships")
        .select("id,relationship_status,preferred_mode,notes"),
      "Student A relationships",
    );
    const ownOrders = requireData(
      await studentA.client
        .from("trial_orders")
        .select("id,delivery_mode,proposed_starts_at,timezone,price_twd,payment_status"),
      "Student A orders",
    );
    const ownLessons = requireData(
      await studentA.client
        .from("lessons")
        .select("id,lesson_type,starts_at,ends_at,status"),
      "Student A lessons",
    );
    assert(
      ownRelationship.length === 1 &&
        ownOrders.length === 1 &&
        ownLessons.length === 1,
      "Student A own-data scope mismatch",
    );
    const studentBProfile = requireData(
      await studentA.client
        .from("student_profiles")
        .select("*")
        .eq("user_id", studentB.userId),
      "Student A cross-profile query",
    );
    assert(studentBProfile.length === 0, "Student A read Student B profile");
    for (const [table, columns] of [
      ["student_teacher_relationships", "id,internal_notes"],
      ["trial_orders", "id,idempotency_key"],
      ["lesson_records", "id,private_teacher_notes"],
      ["lesson_records", "id,completed_by"],
    ]) {
      const forbidden = await studentA.client.from(table).select(columns).limit(1);
      assert(forbidden.error, "Student read forbidden columns from " + table);
    }
    return "own rows only; cross-student/private/internal/technical data denied";
  });

  await run(12, "Teacher privacy", async () => {
    const teacherBOrder = requireData(
      await trialRequest(
        studentB,
        teacherB,
        RUN_TAG + "-teacher-b-private",
        new Date(mainStart.getTime() + 24 * 60 * 60 * 1000).toISOString(),
      ),
      "create Teacher B privacy order",
    );
    teacherBLessonId = requireData(
      await adminA.client.rpc("confirm_trial_payment", {
        p_order_id: teacherBOrder,
        p_starts_at: null,
      }),
      "confirm Teacher B privacy lesson",
    );
    const dto = requireData(
      await teacherA.client.rpc("get_own_teacher_trials"),
      "Teacher A Trial DTO",
    );
    assert(
      dto.length === 1 && dto[0].lesson_id === mainLessonId,
      "Teacher A saw another Teacher Trial",
    );
    const serialized = JSON.stringify(dto).toLowerCase();
    for (const forbidden of [
      "payment",
      "email",
      "auth",
      "idempotency",
      studentB.userId.toLowerCase(),
    ]) {
      assert(!serialized.includes(forbidden), "Teacher DTO exposed " + forbidden);
    }
    const crossProfile = requireData(
      await teacherA.client
        .from("student_profiles")
        .select("*")
        .eq("user_id", studentB.userId),
      "Teacher cross-profile query",
    );
    assert(crossProfile.length === 0, "Teacher A read Student B private profile");
    return "own necessary DTO only; payment/auth/cross-teacher/private profile absent";
  });

  let teacherCollisionOrder;
  await run(13, "Teacher schedule collision", async () => {
    teacherCollisionOrder = requireData(
      await trialRequest(
        studentB,
        teacherA,
        RUN_TAG + "-teacher-collision",
        mainStartIso,
      ),
      "create Teacher collision order",
    );
    const collision = await adminA.client.rpc("confirm_trial_payment", {
      p_order_id: teacherCollisionOrder,
      p_starts_at: null,
    });
    expectDenied(collision, "Teacher collision", ["23P01"]);
    const order = requireData(
      await service
        .from("trial_orders")
        .select("payment_status")
        .eq("id", teacherCollisionOrder)
        .single(),
      "read Teacher collision order",
    );
    const lessons = requireData(
      await service
        .from("lessons")
        .select("id")
        .eq("trial_order_id", teacherCollisionOrder),
      "read Teacher collision lesson",
    );
    assert(
      order.payment_status === "pending" && lessons.length === 0,
      "Teacher collision left partial state",
    );
    return "23P01; pending order preserved; no lesson or partial payment";
  });

  await run(14, "Student schedule collision", async () => {
    studentCollisionOrder = requireData(
      await trialRequest(
        studentA,
        teacherB,
        RUN_TAG + "-student-collision",
        mainStartIso,
      ),
      "create Student collision order",
    );
    const collision = await adminA.client.rpc("confirm_trial_payment", {
      p_order_id: studentCollisionOrder,
      p_starts_at: null,
    });
    expectDenied(collision, "Student collision", ["23P01"]);
    const lessons = requireData(
      await service
        .from("lessons")
        .select("id")
        .eq("trial_order_id", studentCollisionOrder),
      "read Student collision lesson",
    );
    assert(lessons.length === 0, "Student collision created a lesson");
    return "23P01; no deadlock, double booking, or partial lesson";
  });

  await run(15, "Adjacent lesson range", async () => {
    requireData(
      await service
        .from("trial_orders")
        .update({ payment_status: "cancelled" })
        .eq("id", teacherCollisionOrder),
      "retire failed Teacher collision intent",
    );
    const adjacentStart = new Date(
      mainStart.getTime() + 50 * 60 * 1000,
    ).toISOString();
    const adjacentOrder = requireData(
      await trialRequest(
        studentB,
        teacherA,
        RUN_TAG + "-adjacent",
        adjacentStart,
      ),
      "create adjacent order",
    );
    adjacentLessonId = requireData(
      await adminA.client.rpc("confirm_trial_payment", {
        p_order_id: adjacentOrder,
        p_starts_at: null,
      }),
      "confirm adjacent lesson",
    );
    const lesson = requireData(
      await service.from("lessons").select("*").eq("id", adjacentLessonId).single(),
      "read adjacent lesson",
    );
    assert(
      Date.parse(lesson.starts_at) ===
        Date.parse(mainStartIso) + 50 * 60 * 1000,
      "adjacent lesson did not start at prior end",
    );
    return "[start,end) semantics allowed the exact boundary";
  });

  await run(16, "Premature completion denied", async () => {
    expectDenied(
      await teacherA.client.rpc(
        "complete_trial_lesson",
        completionPayload(adjacentLessonId),
      ),
      "premature completion",
      ["23514"],
    );
    return "future scheduled Trial cannot be completed";
  });

  let assessmentId;
  await run(17, "Trial completion", async () => {
    const startedAt = new Date(Date.now() - 60 * 60 * 1000);
    const endedAt = new Date(startedAt.getTime() + 50 * 60 * 1000);
    requireData(
      await service
        .from("lessons")
        .update({
          ends_at: endedAt.toISOString(),
          starts_at: startedAt.toISOString(),
        })
        .eq("id", mainLessonId),
      "backdate fake smoke Trial",
    );
    assessmentId = requireData(
      await teacherA.client.rpc(
        "complete_trial_lesson",
        completionPayload(mainLessonId),
      ),
      "complete Trial",
    );
    const lesson = requireData(
      await service.from("lessons").select("status").eq("id", mainLessonId).single(),
      "read completed lesson",
    );
    const relationship = requireData(
      await service
        .from("student_teacher_relationships")
        .select("relationship_status")
        .eq("id", mainRelationshipId)
        .single(),
      "read completed relationship",
    );
    const records = requireData(
      await service.from("lesson_records").select("id").eq("lesson_id", mainLessonId),
      "read lesson record",
    );
    const assessments = requireData(
      await service.from("assessments").select("id").eq("lesson_id", mainLessonId),
      "read assessment",
    );
    assert(lesson.status === "completed", "lesson was not completed");
    assert(
      relationship.relationship_status === "awaiting_conversion",
      "relationship did not transition",
    );
    assert(
      records.length === 1 && assessments.length === 1,
      "completion artifacts are not singular",
    );
    return "completed; awaiting_conversion; one lesson_record and one assessment";
  });

  await run(18, "Completion idempotency", async () => {
    const retry = requireData(
      await teacherA.client.rpc(
        "complete_trial_lesson",
        completionPayload(mainLessonId),
      ),
      "retry Trial completion",
    );
    assert(retry === assessmentId, "completion retry returned another assessment");
    const records = requireData(
      await service.from("lesson_records").select("id").eq("lesson_id", mainLessonId),
      "count completion records",
    );
    const assessments = requireData(
      await service.from("assessments").select("id").eq("lesson_id", mainLessonId),
      "count completion assessments",
    );
    assert(
      records.length === 1 && assessments.length === 1,
      "completion retry duplicated artifacts",
    );
    return "same assessment ID; no duplicate record or assessment";
  });
  await run(19, "Student result visibility", async () => {
    const dto = requireData(
      await studentA.client.rpc("get_own_student_trial_results"),
      "Student result DTO",
    );
    const result = dto.find((row) => row.lesson_id === mainLessonId);
    assert(result, "Student result was not returned");
    for (const field of [
      "primary_stage",
      "student_visible_notes",
      "performance_summary",
      "next_goal",
      "homework",
      "recommendation",
    ]) {
      assert(
        result[field] !== undefined && result[field] !== null,
        "missing " + field,
      );
    }
    const serialized = JSON.stringify(result).toLowerCase();
    assert(!serialized.includes("private_teacher_notes"), "private notes exposed");
    assert(!serialized.includes("completed_by"), "completed_by exposed");
    return "student-visible results present; private notes/internal completer absent";
  });

  await run(20, "No financial side effects", async () => {
    for (const table of [
      "credit_ledger",
      "lesson_credits",
      "teacher_earnings",
      "mentor_earnings",
      "review_rewards",
      "student_rewards",
    ]) {
      const probe = await service.from(table).select("*").limit(1);
      assert(probe.error, "out-of-scope future table unexpectedly exists: " + table);
    }
    return "no credit, earning, mentor, review, or student reward domain exists";
  });

  await run(21, "Suspended Teacher behavior", async () => {
    await updateProfile(teacherA, { account_status: "suspended" });
    expectDenied(
      await teacherA.client.rpc("update_own_teacher_meeting_defaults", {
        p_provider: "manual_google_meet",
        p_url: "https://meet.google.com/abc-defg-hij",
      }),
      "suspended Teacher mutation",
    );
    const hidden = requireData(
      await anon
        .from("teacher_public_profiles")
        .select("public_slug")
        .eq("public_slug", teacherA.slug),
      "suspended discovery",
    );
    assert(hidden.length === 0, "suspended Teacher remained public");
    await updateProfile(teacherA, { account_status: "active" });
    const restored = requireData(
      await anon
        .from("teacher_public_profiles")
        .select("public_slug")
        .eq("public_slug", teacherA.slug),
      "restored discovery",
    );
    assert(restored.length === 1, "reactivated Teacher did not become public");
    return "mutation denied and hidden while suspended; restored when active";
  });

  await run(22, "Removed Teacher role behavior", async () => {
    requireData(
      await service
        .from("user_roles")
        .delete()
        .eq("user_id", teacherA.userId)
        .eq("role", "teacher"),
      "remove Teacher role",
    );
    expectDenied(
      await teacherA.client.rpc("update_own_teacher_meeting_defaults", {
        p_provider: "manual_google_meet",
        p_url: "https://meet.google.com/abc-defg-hij",
      }),
      "role-revoked Teacher mutation",
    );
    requireData(
      await service.from("user_roles").insert({
        role: "teacher",
        user_id: teacherA.userId,
      }),
      "restore Teacher role",
    );
    requireData(
      await teacherA.client.rpc("update_own_teacher_meeting_defaults", {
        p_provider: "manual_google_meet",
        p_url: "https://meet.google.com/abc-defg-hij",
      }),
      "post-restore Teacher mutation",
    );
    return "new mutation denied after revocation and allowed after restoration";
  });

  await run(23, "Admin authorization", async () => {
    for (const [rpc, args] of [
      [
        "confirm_trial_payment",
        { p_order_id: studentCollisionOrder, p_starts_at: null },
      ],
      [
        "admin_reschedule_trial_lesson",
        {
          p_lesson_id: adjacentLessonId,
          p_starts_at: new Date(
            mainStart.getTime() + 3 * 60 * 60 * 1000,
          ).toISOString(),
        },
      ],
      ["admin_cancel_trial_lesson", { p_lesson_id: teacherBLessonId }],
    ]) {
      expectDenied(await studentA.client.rpc(rpc, args), "non-admin " + rpc);
    }
    const movedStart = new Date(
      mainStart.getTime() + 3 * 60 * 60 * 1000,
    ).toISOString();
    requireData(
      await adminA.client.rpc("admin_reschedule_trial_lesson", {
        p_lesson_id: adjacentLessonId,
        p_starts_at: movedStart,
      }),
      "Admin reschedule",
    );
    requireData(
      await adminA.client.rpc("admin_cancel_trial_lesson", {
        p_lesson_id: teacherBLessonId,
      }),
      "Admin cancel",
    );
    return "ordinary user denied; Admin confirmed, rescheduled, and cancelled";
  });

  await run(24, "Remote schedule locking sanity", async () => {
    const raceStudent1 = await createIdentity("race-student-1");
    const raceStudent2 = await createIdentity("race-student-2");
    const raceStudent3 = await createIdentity("race-student-3");
    const raceTeacher1 = await createIdentity("race-teacher-1", ["teacher"]);
    const raceTeacher2 = await createIdentity("race-teacher-2", ["teacher"]);
    const raceTeacher3 = await createIdentity("race-teacher-3", ["teacher"]);
    const adminB = await createIdentity("admin-b", ["admin"]);
    await Promise.all([
      createStudentProfile(raceStudent1),
      createStudentProfile(raceStudent2),
      createStudentProfile(raceStudent3),
      createTeacher(raceTeacher1, "race-teacher-1"),
      createTeacher(raceTeacher2, "race-teacher-2"),
      createTeacher(raceTeacher3, "race-teacher-3"),
    ]);
    const stats = { collision: 0, deadlock: 0, partial: 0, unique: 0 };

    for (let round = 1; round <= 5; round += 1) {
      const startsAt = new Date(
        mainStart.getTime() + (10 + round) * 24 * 60 * 60 * 1000,
      ).toISOString();
      const first = requireData(
        await trialRequest(
          raceStudent1,
          raceTeacher1,
          RUN_TAG + "-race-teacher-a-" + round,
          startsAt,
        ),
        "Teacher race order A",
      );
      const second = requireData(
        await trialRequest(
          raceStudent2,
          raceTeacher1,
          RUN_TAG + "-race-teacher-b-" + round,
          startsAt,
        ),
        "Teacher race order B",
      );
      const outcomes = await concurrentConfirm(adminA, adminB, first, second);
      const successes = outcomes.filter((outcome) => !outcome.error);
      const failures = outcomes.filter((outcome) => outcome.error);
      stats.collision += failures.filter(
        (outcome) => outcome.error.code === "23P01",
      ).length;
      stats.deadlock += failures.filter(
        (outcome) => outcome.error.code === "40P01",
      ).length;
      stats.unique += failures.filter(
        (outcome) => outcome.error.code === "23505",
      ).length;
      assert(
        successes.length === 1 && failures.length === 1,
        "Teacher race outcome mismatch",
      );
      const rows = requireData(
        await service
          .from("lessons")
          .select("id")
          .in("trial_order_id", [first, second]),
        "Teacher race lessons",
      );
      const paid = requireData(
        await service
          .from("trial_orders")
          .select("id")
          .in("id", [first, second])
          .eq("payment_status", "paid"),
        "Teacher race paid orders",
      );
      if (rows.length !== 1 || paid.length !== 1) stats.partial += 1;
      await cleanupRace([raceStudent1, raceStudent2], [first, second]);
    }

    for (let round = 1; round <= 5; round += 1) {
      const startsAt = new Date(
        mainStart.getTime() + (20 + round) * 24 * 60 * 60 * 1000,
      ).toISOString();
      const first = requireData(
        await trialRequest(
          raceStudent3,
          raceTeacher2,
          RUN_TAG + "-race-student-a-" + round,
          startsAt,
        ),
        "Student race order A",
      );
      const second = requireData(
        await trialRequest(
          raceStudent3,
          raceTeacher3,
          RUN_TAG + "-race-student-b-" + round,
          startsAt,
        ),
        "Student race order B",
      );
      const outcomes = await concurrentConfirm(adminA, adminB, first, second);
      const successes = outcomes.filter((outcome) => !outcome.error);
      const failures = outcomes.filter((outcome) => outcome.error);
      stats.collision += failures.filter(
        (outcome) => outcome.error.code === "23P01",
      ).length;
      stats.deadlock += failures.filter(
        (outcome) => outcome.error.code === "40P01",
      ).length;
      stats.unique += failures.filter(
        (outcome) => outcome.error.code === "23505",
      ).length;
      assert(
        successes.length === 1 && failures.length === 1,
        "Student race outcome mismatch",
      );
      const rows = requireData(
        await service
          .from("lessons")
          .select("id")
          .in("trial_order_id", [first, second]),
        "Student race lessons",
      );
      const paid = requireData(
        await service
          .from("trial_orders")
          .select("id")
          .in("id", [first, second])
          .eq("payment_status", "paid"),
        "Student race paid orders",
      );
      if (rows.length !== 1 || paid.length !== 1) stats.partial += 1;
      await cleanupRace([raceStudent3], [first, second]);
    }
    assert(stats.collision === 10, "expected 10 stable collision rejections");
    assert(stats.deadlock === 0, "remote production exposed 40P01");
    assert(stats.unique === 0, "remote production exposed 23505");
    assert(stats.partial === 0, "remote production left partial race state");
    return "10 races: 23P01=10, 40P01=0, 23505=0, partial=0";
  });

  await run(25, "Security function catalog and live grants", async () => {
    const hardening = (
      await readFile(
        "supabase/migrations/20260831000500_harden_trial_security_and_integrity.sql",
        "utf8",
      )
    ).toLowerCase();
    const locking = (
      await readFile(
        "supabase/migrations/20260901000100_serialize_lesson_schedule_mutations.sql",
        "utf8",
      )
    ).toLowerCase();
    for (const functionName of [
      "request_trial_checkout",
      "confirm_trial_payment",
      "update_own_teacher_meeting_defaults",
      "complete_trial_lesson",
      "admin_reschedule_trial_lesson",
      "admin_cancel_trial_lesson",
      "get_own_teacher_trials",
      "get_own_student_trial_results",
      "get_trial_teacher_context",
    ]) {
      assert(
        hardening.includes("function public." + functionName),
        "missing " + functionName,
      );
    }
    assert(hardening.includes("owner to postgres"), "owner pinning missing");
    assert(hardening.includes("set search_path = ''"), "safe search_path missing");
    assert(hardening.includes("from public, anon"), "PUBLIC/anon revoke missing");
    assert(hardening.includes("to authenticated"), "authenticated grants missing");
    assert(
      locking.includes(
        "revoke all on function private.lock_lesson_schedule_resources(uuid, uuid)",
      ) && locking.includes("from public, anon, authenticated"),
      "private schedule lock execute revoke missing",
    );
    const anonProbe = await anon.rpc("get_own_student_trial_results");
    assert(anonProbe.error, "anonymous executed authenticated result RPC");
    const privateProbe = await fetch(
      supabaseUrl + "/rest/v1/rpc/lock_lesson_schedule_resources",
      {
        method: "POST",
        headers: {
          apikey: publishableKey,
          "content-type": "application/json",
        },
        body: JSON.stringify({
          p_student_user_id: studentA.userId,
          p_teacher_user_id: teacherA.userId,
        }),
      },
    );
    assert(!privateProbe.ok, "private schedule lock was directly executable");
    requireData(
      await studentA.client.rpc("get_own_student_trial_results"),
      "authenticated grant probe",
    );
    return "applied migration pins postgres/search_path/grants; live grant probes passed";
  });
} finally {
  await run(26, "Cleanup", async () => {
    await cleanup();
    const counts = await remainingCounts();
    const total = Object.values(counts).reduce((sum, count) => sum + count, 0);
    assert(total === 0, "remaining fixture count: " + JSON.stringify(counts));
    return "all Auth users and Epic 3 rows for " + RUN_TAG + " removed; remaining=0";
  });
}

for (const result of results.sort((left, right) => left.number - right.number)) {
  console.log(
    "TEST " +
      result.number +
      " [" +
      result.status +
      "] " +
      result.name +
      ": " +
      result.detail,
  );
}
const failed = results.filter((result) => result.status === "FAIL");
console.log(
  "SUMMARY " +
    JSON.stringify({
      failed: failed.length,
      passed: results.length - failed.length,
      runTag: RUN_TAG,
      total: results.length,
    }),
);
process.exitCode = failed.length === 0 ? 0 : 1;
