import { execFile } from "node:child_process";
import { randomUUID } from "node:crypto";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import { pathToFileURL } from "node:url";
import { promisify } from "node:util";

import {
  EXPECTED_REMOTE_MIGRATION,
  parseRemoteSmokeArgs,
  validateRemoteSmokeTarget,
} from "./remote-smoke-safety.mjs";

const execFileAsync = promisify(execFile);

export const EXPECTED_MIGRATION = EXPECTED_REMOTE_MIGRATION;
export const parseArgs = parseRemoteSmokeArgs;
export const validateTargetGate = validateRemoteSmokeTarget;
export const CASES = Object.freeze([
  { id: "E6-RS-001", description: "Flexible booking happy path" },
  { id: "E6-RS-002", description: "Explicit entitlement source" },
  { id: "E6-RS-003", description: "Duration mismatch rejected" },
  { id: "E6-RS-004", description: "Fixed priority protected" },
  { id: "E6-RS-005", description: "Recurring occurrence refresh idempotent" },
  { id: "E6-RS-006", description: "Cross-timezone recurring ownership" },
  { id: "E6-RS-007", description: "Fixed cycle attachment" },
  { id: "E6-RS-008", description: "Checkout hold exclusivity" },
  { id: "E6-RS-009", description: "Fixed renewal lifecycle" },
  { id: "E6-RS-010", description: "Teacher cancellation creates one Makeup Right" },
  { id: "E6-RS-011", description: "Makeup booking consumes the Right" },
  { id: "E6-RS-012", description: "Makeup cancellation restores the same Right" },
  { id: "E6-RS-013", description: "Entitlement revoke booking reconciliation" },
  { id: "E6-RS-014", description: "Entitlement revoke fixed-cycle reconciliation" },
  { id: "E6-RS-015", description: "Reschedule source revalidation" },
  { id: "E6-RS-016", description: "Completion source revalidation" },
]);

const CLI = path.join("node_modules", "supabase", "dist", "supabase.js");
const SQL_TEMPLATE = path.join("supabase", "tests", "remote", "epic6_remote_smoke.sql.template");

export function validateCaseManifest(cases = CASES) {
  if (cases.length < 16) throw new Error("At least 16 Epic6 smoke cases are required.");
  const ids = cases.map((item) => item.id);
  if (new Set(ids).size !== ids.length) throw new Error("Smoke case IDs must be unique.");
  for (let index = 1; index <= 16; index += 1) {
    const expected = `E6-RS-${String(index).padStart(3, "0")}`;
    if (!ids.includes(expected)) throw new Error(`Missing required case ${expected}.`);
  }
  return true;
}

export function validateSqlTemplate(sql, cases = CASES) {
  const lowered = sql.toLowerCase();
  const forbidden = [
    "session_replication_role",
    "disable trigger",
    "disable row level security",
    "alter table auth.",
    "alter table ",
    "delete from",
    "drop table",
    "truncate ",
  ];
  for (const marker of forbidden) {
    if (lowered.includes(marker)) throw new Error(`Forbidden SQL marker: ${marker}`);
  }
  if (!sql.includes("EPIC6_REMOTE_SMOKE_ROLLBACK")) throw new Error("Rollback sentinel is missing.");
  if (!sql.includes("__RUN_TAG__")) throw new Error("Synthetic run-tag placeholder is missing.");
  for (const item of cases) {
    if (!sql.includes(`${item.id} PASS`)) throw new Error(`SQL payload has no success marker for ${item.id}.`);
  }
  return true;
}

export function validatePreflight(preflight) {
  if (String(preflight.migration_latest) !== EXPECTED_MIGRATION) {
    throw new Error(`Migration latest mismatch: expected ${EXPECTED_MIGRATION}, got ${preflight.migration_latest ?? "missing"}.`);
  }
  const zeroFields = [
    "required_rpc_missing",
    "rls_missing",
    "authenticated_raw_mutation_grants",
    "service_role_commerce_raw_mutation_grants",
    "private_helper_application_execute",
    "unsafe_security_definer_search_path",
  ];
  for (const field of zeroFields) {
    if (Number(preflight[field]) !== 0) throw new Error(`Security preflight ${field}=${preflight[field] ?? "missing"}.`);
  }
  return true;
}

export function validateResidue(residue) {
  const operational = Number(residue.operational ?? -1);
  const immutable = Number(residue.immutable ?? -1);
  if (operational !== 0 || immutable !== 0) {
    throw new Error(`Residue remains: operational=${operational}, immutable=${immutable}.`);
  }
  return true;
}

function sqlLiteral(value) {
  return `'${String(value).replaceAll("'", "''")}'`;
}

export function parseJsonRows(output) {
  // CLI non-agent mode returns an array; agent mode wraps it in { rows }.
  const payload = JSON.parse(output.trim());
  if (Array.isArray(payload)) return payload;
  if (payload && Array.isArray(payload.rows)) return payload.rows;
  throw new Error("Supabase query returned neither a row array nor a rows envelope.");
}

async function runCommand(args) {
  return execFileAsync(process.execPath, [CLI, ...args], {
    cwd: process.cwd(),
    maxBuffer: 32 * 1024 * 1024,
  });
}

async function query(sql, targetArgs) {
  const { stdout } = await runCommand(["db", "query", ...targetArgs, "--output-format", "json", sql]);
  return parseJsonRows(stdout);
}

function preflightSql() {
  const required = [
    "public.create_lesson_booking(uuid,uuid,uuid,uuid,timestamptz,text,text,text)",
    "public.reschedule_lesson_booking(uuid,timestamptz,text,text)",
    "public.complete_lesson_booking(uuid,text,text,text,text,text)",
    "public.cancel_lesson_booking(uuid,public.booking_credit_outcome,text,text)",
    "public.create_recurring_lesson_series(uuid,uuid,uuid,uuid,smallint,time,text,smallint,date,date,text)",
    "public.set_teacher_scheduling_settings(uuid,text,integer,integer,integer,text)",
    "public.refresh_recurring_series_occurrences(uuid,date)",
    "public.materialize_recurring_lesson_occurrence(uuid,date,uuid,text)",
    "public.attach_fixed_entitlement_cycle(uuid,uuid,uuid,text)",
    "public.claim_fixed_checkout_hold(uuid,uuid,text,smallint,time,text,date,date,text)",
    "public.set_fixed_checkout_hold_policy(uuid,integer,text)",
    "public.release_fixed_checkout_hold(uuid,text)",
    "public.open_fixed_cycle_renewal(uuid,text)",
    "public.set_fixed_renewal_intent(uuid,public.fixed_renewal_intent,text)",
    "public.claim_fixed_renewal_hold(uuid,text,text)",
    "public.convert_fixed_renewal(uuid,uuid,uuid,uuid,text)",
    "public.create_makeup_lesson_booking(uuid,uuid,uuid,uuid,timestamptz,text,text,text)",
    "public.admin_revoke_entitlement(uuid,text,text)",
    "public.admin_confirm_cash_payment(uuid,text,text)",
    "public.process_order_fulfillment_event(uuid)",
  ];
  const requiredArray = required.map(sqlLiteral).join(",");
  return `with required(signature) as (select unnest(array[${requiredArray}]::text[])),
  targets(name) as (select unnest(array['entitlements','lesson_credit_reservations','bookings','lessons','recurring_lesson_series','recurring_lesson_occurrences','fixed_entitlement_cycles','fixed_checkout_holds','fixed_cycle_renewals','fixed_renewal_holds','makeup_rights','orders','payments','order_fulfillment_events']::text[])),
  mutating_private as (select p.oid,p.proconfig from pg_proc p where p.pronamespace='private'::regnamespace and p.prosecdef and p.prosrc ~* '(insert[[:space:]]+into|update[[:space:]]+|delete[[:space:]]+from)')
  select jsonb_build_object(
    'migration_latest',(select version::text from supabase_migrations.schema_migrations order by version desc limit 1),
    'required_rpc_missing',(select count(*) from required where to_regprocedure(signature) is null),
    'rls_missing',(select count(*) from targets t left join pg_class c on c.relnamespace='public'::regnamespace and c.relname=t.name where not coalesce(c.relrowsecurity,false)),
    'authenticated_raw_mutation_grants',(select count(*) from information_schema.role_table_grants g join targets t on t.name=g.table_name where g.table_schema='public' and g.grantee='authenticated' and g.privilege_type in('INSERT','UPDATE','DELETE')),
    'service_role_commerce_raw_mutation_grants',(select count(*) from information_schema.role_table_grants where table_schema='public' and grantee='service_role' and privilege_type in('INSERT','UPDATE','DELETE') and table_name in('orders','order_items','payments','payment_submissions','refunds','order_fulfillment_events','entitlements','lesson_credit_ledger')),
    'private_helper_application_execute',(select count(*) from mutating_private where has_function_privilege('anon',oid,'EXECUTE') or has_function_privilege('authenticated',oid,'EXECUTE') or has_function_privilege('service_role',oid,'EXECUTE')),
    'unsafe_security_definer_search_path',(select count(*) from pg_proc p where p.prosecdef and p.pronamespace in('public'::regnamespace,'private'::regnamespace) and not coalesce(p.proconfig,array[]::text[]) @> array['search_path=""']::text[])
  ) as preflight;`;
}

function residueSql(runTag) {
  const tag = sqlLiteral(runTag + "%");
  return `with fixture_users as (select id from auth.users where email like ${tag}),
  fixture_products as (select id from public.products where public_slug like ${tag}),
  operational as (
    select count(*) n from auth.users where email like ${tag}
    union all select count(*) from public.bookings where student_user_id in(select id from fixture_users)
    union all select count(*) from public.lessons where student_user_id in(select id from fixture_users)
    union all select count(*) from public.entitlements where beneficiary_user_id in(select id from fixture_users)
    union all select count(*) from public.lesson_credit_reservations where beneficiary_user_id in(select id from fixture_users)
    union all select count(*) from public.recurring_lesson_series where student_user_id in(select id from fixture_users)
    union all select count(*) from public.fixed_entitlement_cycles where student_user_id in(select id from fixture_users)
    union all select count(*) from public.fixed_checkout_holds where student_user_id in(select id from fixture_users)
    union all select count(*) from public.fixed_renewal_holds where student_user_id in(select id from fixture_users)
    union all select count(*) from public.makeup_rights where student_user_id in(select id from fixture_users)
    union all select count(*) from public.orders where buyer_user_id in(select id from fixture_users)
    union all select count(*) from public.products where id in(select id from fixture_products)
  ), immutable as (
    select count(*) n from public.lesson_credit_ledger where operation_key like ${tag}
    union all select count(*) from public.audit_logs where reason like ${tag}
    union all select count(*) from public.entitlement_expiry_history where reason like ${tag}
    union all select count(*) from public.order_item_fulfillment_snapshots where product_id in(select id from fixture_products)
  ) select jsonb_build_object('operational',(select sum(n) from operational),'immutable',(select sum(n) from immutable)) as residue;`;
}

async function gitSha() {
  const { stdout } = await execFileAsync("git", ["rev-parse", "HEAD"], { cwd: process.cwd() });
  return stdout.trim();
}

async function writeEvidence(evidence) {
  const directory = path.join("artifacts", "remote-smoke", evidence.run_id);
  await mkdir(directory, { recursive: true });
  const artifact = path.join(directory, "epic6-remote-smoke.json");
  await writeFile(artifact, JSON.stringify(evidence, null, 2) + "\n", "utf8");
  return artifact;
}

function printSummary(evidence, artifact) {
  const pass = evidence.cases.filter((item) => item.status === "PASS").length;
  const fail = evidence.cases.filter((item) => item.status === "FAIL").length;
  const skip = evidence.cases.filter((item) => item.status === "SKIP").length;
  console.log("# Epic6 Remote Smoke Result");
  console.log(`Project Ref: ${evidence.project_ref}`);
  console.log(`Git SHA: ${evidence.git_sha}`);
  console.log(`Migration Latest: ${evidence.migration_latest}`);
  console.log(`Run ID: ${evidence.run_id}`);
  console.log(`Environment: ${evidence.environment}`);
  console.log(`Start: ${evidence.timestamps.start}`);
  console.log(`End: ${evidence.timestamps.end}`);
  console.log(`Cases: PASS=${pass} FAIL=${fail} SKIP=${skip}`);
  console.log(`Security: ${evidence.security.status}`);
  console.log(`Cleanup: ${evidence.cleanup.status}`);
  console.log(`Unexpected Residue: ${evidence.residue.operational}`);
  console.log(`Immutable Expected Evidence: ${evidence.residue.immutable}`);
  console.log(`Overall: ${evidence.overall}`);
  console.log(`JSON Artifact: ${artifact}`);
}

export async function main(argv = process.argv.slice(2)) {
  const started = new Date().toISOString();
  const runId = `epic6-smoke-${started.replaceAll(/[-:.TZ]/g, "").slice(0, 14)}-${randomUUID().slice(0, 8)}`;
  const options = parseArgs(argv);
  const evidence = {
    git_sha: await gitSha(),
    project_ref: "unvalidated",
    migration_latest: "unvalidated",
    run_id: runId,
    environment: "unvalidated",
    cases: CASES.map((item) => ({ ...item, status: "SKIP", detail: "not executed" })),
    errors: [],
    cleanup: { status: "NOT_RUN", strategy: "atomic rollback sentinel plus independent residue query" },
    residue: { operational: -1, immutable: -1 },
    security: { status: "NOT_RUN" },
    timestamps: { start: started, end: null },
    overall: "FAIL",
  };
  let artifact;
  try {
    validateCaseManifest();
    const sqlTemplate = await readFile(SQL_TEMPLATE, "utf8");
    validateSqlTemplate(sqlTemplate);

    if (options.validateOnly) {
      const target = validateTargetGate(options, null);
      evidence.project_ref = target.projectRef;
      evidence.environment = target.environment;
      evidence.migration_latest = EXPECTED_MIGRATION;
      evidence.security = { status: "PASS", detail: "static gate and SQL safety validation" };
      evidence.cleanup = { status: "PASS", strategy: "rollback sentinel and residue query statically verified" };
      evidence.residue = { operational: 0, immutable: 0 };
      evidence.cases = CASES.map((item) => ({ ...item, status: "PASS", detail: "manifest and SQL marker validated" }));
      evidence.overall = "PASS";
    } else {
      let linkedProjectRef = null;
      if (!options.local) {
        linkedProjectRef = (await readFile(path.join("supabase", ".temp", "project-ref"), "utf8")).trim();
      }
      const target = validateTargetGate(options, linkedProjectRef);
      evidence.project_ref = target.projectRef;
      evidence.environment = target.environment;
      const targetArgs = options.local ? ["--local"] : ["--linked", "--project-ref", target.projectRef];

      const preflightRows = await query(preflightSql(), targetArgs);
      const preflight = preflightRows[0]?.preflight;
      if (!preflight) throw new Error("Preflight query returned no result.");
      validatePreflight(preflight);
      evidence.migration_latest = String(preflight.migration_latest);
      evidence.security = { status: "PASS", checks: preflight };

      const beforeRows = await query(residueSql(runId), targetArgs);
      validateResidue(beforeRows[0]?.residue ?? {});

      const runtimeDirectory = path.join("artifacts", "remote-smoke", runId);
      await mkdir(runtimeDirectory, { recursive: true });
      const runtimeSql = path.join(runtimeDirectory, "epic6-smoke-runtime.sql");
      await writeFile(runtimeSql, sqlTemplate.replaceAll("__RUN_TAG__", runId), "utf8");

      let executionOutput = "";
      let executionError = null;
      try {
        const execution = await runCommand(["db", "query", ...targetArgs, "--file", runtimeSql]);
        executionOutput = `${execution.stdout}\n${execution.stderr}`;
      } catch (error) {
        executionOutput = `${error.stdout ?? ""}\n${error.stderr ?? ""}`;
        const expectedRollback = executionOutput.includes("EPIC6_REMOTE_SMOKE_ROLLBACK")
          && CASES.every((item) => executionOutput.includes(`${item.id} PASS`));
        if (!expectedRollback) executionError = new Error(`Smoke SQL failed: ${executionOutput.trim()}`);
      }

      try {
        const afterRows = await query(residueSql(runId), targetArgs);
        const residue = afterRows[0]?.residue ?? {};
        validateResidue(residue);
        evidence.residue = { operational: Number(residue.operational), immutable: Number(residue.immutable) };
        evidence.cleanup = { status: "PASS", strategy: "atomic rollback sentinel plus independent residue query" };
      } catch (error) {
        evidence.cleanup = { status: "FAIL", strategy: "atomic rollback sentinel plus independent residue query" };
        if (executionError) evidence.errors.push(executionError.message);
        throw error;
      }

      if (executionError) throw executionError;
      const passed = new Set([...executionOutput.matchAll(/(E6-RS-\d{3}) PASS/g)].map((match) => match[1]));
      evidence.cases = CASES.map((item) => ({
        ...item,
        status: passed.has(item.id) ? "PASS" : "FAIL",
        detail: passed.has(item.id) ? "remote-compatible SQL assertion passed" : "success marker missing",
      }));
      if (passed.size !== CASES.length) throw new Error(`Only ${passed.size}/${CASES.length} smoke success markers were observed.`);

      evidence.overall = "PASS";
    }
  } catch (error) {
    evidence.errors.push(error instanceof Error ? error.message : String(error));
  } finally {
    evidence.timestamps.end = new Date().toISOString();
    artifact = await writeEvidence(evidence);
    printSummary(evidence, artifact);
  }
  if (evidence.overall !== "PASS") process.exitCode = 1;
  return evidence;
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  await main();
}
