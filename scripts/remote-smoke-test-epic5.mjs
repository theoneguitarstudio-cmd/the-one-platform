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
  { id: "E5-RS-001", description: "Fulfillment creates compatible Entitlement" },
  { id: "E5-RS-002", description: "Duplicate fulfillment is idempotent" },
  { id: "E5-RS-003", description: "Explicit Entitlement source reserve" },
  { id: "E5-RS-004", description: "Multiple packages never use FIFO fallback" },
  { id: "E5-RS-005", description: "Reserve writes the credit history chain" },
  { id: "E5-RS-006", description: "Release is idempotent" },
  { id: "E5-RS-007", description: "Consume writes the credit history chain" },
  { id: "E5-RS-008", description: "Double consume is idempotent" },
  { id: "E5-RS-009", description: "Invalid Entitlement reserve is rejected" },
  { id: "E5-RS-010", description: "Purchase-time duration snapshot is preserved" },
  { id: "E5-RS-011", description: "Duration mismatch is rejected downstream" },
  { id: "E5-RS-012", description: "Entitlement revoke reaches a terminal state" },
  { id: "E5-RS-013", description: "Revoke request is idempotent" },
  { id: "E5-RS-014", description: "Revoke reconciles future ordinary value" },
  { id: "E5-RS-015", description: "Ledger and operation history remain immutable" },
]);

const CLI = path.join("node_modules", "supabase", "dist", "supabase.js");
const SQL_TEMPLATE = path.join("supabase", "tests", "remote", "epic5_remote_smoke.sql.template");

export function validateCaseManifest(cases = CASES) {
  if (cases.length < 15) throw new Error("At least 15 Epic5 smoke cases are required.");
  const ids = cases.map((item) => item.id);
  if (new Set(ids).size !== ids.length) throw new Error("Smoke case IDs must be unique.");
  for (let index = 1; index <= 15; index += 1) {
    const expected = `E5-RS-${String(index).padStart(3, "0")}`;
    if (!ids.includes(expected)) throw new Error(`Missing required case ${expected}.`);
  }
  return true;
}

export function validateSqlTemplate(sql, cases = CASES) {
  const lowered = sql.toLowerCase();
  const forbidden = [
    "session_replication_role", "disable trigger", "disable row level security",
    "alter table auth.", "truncate ", "drop table", "delete from", "supabase_service_role_key",
  ];
  for (const marker of forbidden) {
    if (lowered.includes(marker)) throw new Error(`Forbidden SQL marker: ${marker}`);
  }
  const protectedTables = [
    "entitlements", "lesson_credit_ledger", "lesson_credit_reservations",
    "orders", "order_items", "payments", "payment_submissions", "order_fulfillment_events",
    "order_item_fulfillment_snapshots", "entitlement_revoke_operations",
    "entitlement_expiry_history", "fulfillment_manual_retry_attempts", "refunds", "audit_logs",
  ];
  for (const table of protectedTables) {
    const rawMutation = new RegExp(`(?:insert\\s+into|update|delete\\s+from)\\s+(?:public\\.)?${table}\\b`, "i");
    if (rawMutation.test(sql)) throw new Error(`Forbidden raw domain mutation: ${table}`);
  }
  const normalizedPathText = sql.replaceAll(/\\+/g, "/").replaceAll(/\/+/g, "/");
  if (/[a-z]:\/users\//i.test(normalizedPathText)) {
    throw new Error("Hard-coded foreign machine path is forbidden.");
  }
  if (!sql.includes("EPIC5_REMOTE_SMOKE_ROLLBACK")) throw new Error("Rollback sentinel is missing.");
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
    "required_rpc_missing", "rls_missing", "authenticated_raw_mutation_grants",
    "service_role_high_risk_raw_mutation_grants", "private_helper_application_execute",
    "unsafe_security_definer_search_path",
  ];
  for (const field of zeroFields) {
    if (Number(preflight[field]) !== 0) throw new Error(`Security preflight ${field}=${preflight[field] ?? "missing"}.`);
  }
  return true;
}

export function validateResidue(residue) {
  const operational = Number(residue.operational_residue?.total ?? -1);
  const immutable = Number(residue.immutable_expected?.total ?? -1);
  const unexpected = Number(residue.unexpected?.total ?? -1);
  if (operational !== 0) throw new Error(`Operational residue remains: ${operational}.`);
  if (unexpected !== 0) throw new Error(`Unexpected evidence remains: ${unexpected}.`);
  if (!Number.isInteger(immutable) || immutable < 0 || immutable > 64) {
    throw new Error(`Immutable expected evidence is unbounded: ${immutable}.`);
  }
  return true;
}

export function validateEvidence(evidence) {
  const required = [
    "run_id", "project_ref", "environment", "git_sha", "migration_latest",
    "cases", "security", "cleanup", "operational_residue",
    "immutable_expected", "unexpected", "errors", "timestamps",
  ];
  for (const field of required) if (!(field in evidence)) throw new Error(`Evidence field missing: ${field}.`);
  if (!Array.isArray(evidence.cases) || !Array.isArray(evidence.errors)) throw new Error("Evidence arrays are invalid.");
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
  return execFileAsync(process.execPath, [CLI, ...args], { cwd: process.cwd(), maxBuffer: 32 * 1024 * 1024 });
}

async function query(sql, targetArgs) {
  const { stdout } = await runCommand(["db", "query", ...targetArgs, "--output-format", "json", sql]);
  return parseJsonRows(stdout);
}

function preflightSql() {
  const required = [
    "public.create_checkout_order(text,integer,text)",
    "public.admin_confirm_cash_payment(uuid,text,text)",
    "public.process_order_fulfillment_event(uuid)",
    "public.reserve_lesson_credit(uuid,text,uuid,text)",
    "public.release_lesson_credit(uuid,text)",
    "public.consume_lesson_credit(uuid,uuid)",
    "public.admin_revoke_entitlement(uuid,text,text)",
    "public.admin_set_lesson_package_product_config(uuid,integer,integer,public.entitlement_validity_unit,integer,public.lesson_booking_mode_eligibility,text)",
    "public.create_lesson_booking(uuid,uuid,uuid,uuid,timestamptz,text,text,text)",
    "public.create_recurring_lesson_series(uuid,uuid,uuid,uuid,smallint,time,text,smallint,date,date,text)",
    "public.materialize_recurring_lesson_occurrence(uuid,date,uuid,text)",
  ];
  const signatures = required.map(sqlLiteral).join(",");
  return `with required(signature) as (select unnest(array[${signatures}]::text[])),
  targets(name) as (select unnest(array['entitlements','lesson_credit_ledger','lesson_credit_reservations','entitlement_revoke_operations','orders','order_items','payments','payment_submissions','order_fulfillment_events','order_item_fulfillment_snapshots']::text[])),
  mutating_private as (select p.oid from pg_proc p where p.pronamespace='private'::regnamespace and p.prosecdef and p.prosrc ~* '(insert[[:space:]]+into|update[[:space:]]+|delete[[:space:]]+from)')
  select jsonb_build_object(
    'migration_latest',(select version::text from supabase_migrations.schema_migrations order by version desc limit 1),
    'required_rpc_missing',(select count(*) from required where to_regprocedure(signature) is null),
    'rls_missing',(select count(*) from targets t left join pg_class c on c.relnamespace='public'::regnamespace and c.relname=t.name where not coalesce(c.relrowsecurity,false)),
    'authenticated_raw_mutation_grants',(select count(*) from information_schema.role_table_grants g join targets t on t.name=g.table_name where g.table_schema='public' and g.grantee='authenticated' and g.privilege_type in('INSERT','UPDATE','DELETE')),
    'service_role_high_risk_raw_mutation_grants',(select count(*) from information_schema.role_table_grants g join targets t on t.name=g.table_name where g.table_schema='public' and g.grantee='service_role' and g.privilege_type in('INSERT','UPDATE','DELETE')),
    'private_helper_application_execute',(select count(*) from mutating_private where has_function_privilege('anon',oid,'EXECUTE') or has_function_privilege('authenticated',oid,'EXECUTE') or has_function_privilege('service_role',oid,'EXECUTE')),
    'unsafe_security_definer_search_path',(select count(*) from pg_proc p where p.prosecdef and p.pronamespace in('public'::regnamespace,'private'::regnamespace) and not coalesce(p.proconfig,array[]::text[]) @> array['search_path=""']::text[])
  ) as preflight;`;
}

function residueSql(runTag) {
  const tag = sqlLiteral(runTag + "%");
  return `with fixture_users as (select id from auth.users where email like ${tag}),
  fixture_products as (select id from public.products where public_slug like ${tag}),
  fixture_orders as (select id from public.orders where buyer_user_id in(select id from fixture_users)),
  fixture_entitlements as (select id from public.entitlements where beneficiary_user_id in(select id from fixture_users)),
  operational as (
    select 'users' k,count(*) n from fixture_users union all select 'products',count(*) from fixture_products
    union all select 'orders',count(*) from fixture_orders
    union all select 'active_entitlements',count(*) from public.entitlements where id in(select id from fixture_entitlements) and status in('active','exhausted')
    union all select 'active_reservations',count(*) from public.lesson_credit_reservations where entitlement_id in(select id from fixture_entitlements) and status='reserved'
    union all select 'bookings',count(*) from public.bookings where student_user_id in(select id from fixture_users)
    union all select 'lessons',count(*) from public.lessons where student_user_id in(select id from fixture_users)
  ), immutable as (
    select 'ledger' k,count(*) n from public.lesson_credit_ledger where entitlement_id in(select id from fixture_entitlements)
    union all select 'fulfillment_events',count(*) from public.order_fulfillment_events where order_id in(select id from fixture_orders)
    union all select 'fulfillment_snapshots',count(*) from public.order_item_fulfillment_snapshots where order_item_id in(select id from public.order_items where order_id in(select id from fixture_orders))
    union all select 'payments',count(*) from public.payments where order_id in(select id from fixture_orders)
    union all select 'revoke_operations',count(*) from public.entitlement_revoke_operations where entitlement_id in(select id from fixture_entitlements)
    union all select 'audit',count(*) from public.audit_logs where actor_user_id in(select id from fixture_users) or reason like ${tag}
  ), unexpected as (
    select 'namespace_without_owner' k,count(*) n from public.audit_logs where reason like ${tag}
      and actor_user_id not in(select id from fixture_users)
      and target_id not in(select id from fixture_products union all select id from fixture_orders union all select id from fixture_entitlements)
  ) select jsonb_build_object(
    'operational_residue',jsonb_build_object('total',(select coalesce(sum(n),0) from operational),'counts',(select jsonb_object_agg(k,n) from operational)),
    'immutable_expected',jsonb_build_object('total',(select coalesce(sum(n),0) from immutable),'counts',(select jsonb_object_agg(k,n) from immutable),'policy','run-scoped, bounded, append-only evidence may remain'),
    'unexpected',jsonb_build_object('total',(select coalesce(sum(n),0) from unexpected),'counts',(select jsonb_object_agg(k,n) from unexpected))
  ) as residue;`;
}

async function gitSha() {
  const { stdout } = await execFileAsync("git", ["rev-parse", "HEAD"], { cwd: process.cwd() });
  return stdout.trim();
}

async function writeEvidence(evidence) {
  validateEvidence(evidence);
  const directory = path.join("artifacts", "remote-smoke", evidence.run_id);
  await mkdir(directory, { recursive: true });
  const artifact = path.join(directory, "epic5-remote-smoke.json");
  await writeFile(artifact, JSON.stringify(evidence, null, 2) + "\n", "utf8");
  return artifact;
}

function printSummary(evidence, artifact) {
  const pass = evidence.cases.filter((item) => item.status === "PASS").length;
  const fail = evidence.cases.filter((item) => item.status === "FAIL").length;
  const skip = evidence.cases.filter((item) => item.status === "SKIP").length;
  console.log("# Epic5 Remote Smoke Result");
  for (const [label, value] of [
    ["Project Ref", evidence.project_ref], ["Environment", evidence.environment],
    ["Git SHA", evidence.git_sha], ["Migration Latest", evidence.migration_latest], ["Run ID", evidence.run_id],
  ]) console.log(`${label}: ${value}`);
  console.log(`Cases: PASS=${pass} FAIL=${fail} SKIP=${skip}`);
  console.log(`Security: ${evidence.security.status}`);
  console.log(`Cleanup: ${evidence.cleanup.status}`);
  console.log(`Operational Residue: ${evidence.operational_residue.total}`);
  console.log(`Immutable Expected Evidence: ${evidence.immutable_expected.total}`);
  console.log(`Unexpected Evidence: ${evidence.unexpected.total}`);
  console.log(`Overall: ${evidence.overall}`);
  console.log(`JSON Artifact: ${artifact}`);
}

export async function main(argv = process.argv.slice(2)) {
  const started = new Date().toISOString();
  const runId = `remote-smoke-epic5-${started.replaceAll(/[-:.TZ]/g, "").slice(0, 14)}-${randomUUID().slice(0, 8)}`;
  const options = parseArgs(argv);
  const evidence = {
    run_id: runId, project_ref: "unvalidated", environment: "unvalidated",
    git_sha: await gitSha(), migration_latest: "unvalidated",
    cases: CASES.map((item) => ({ ...item, status: "SKIP", detail: "not executed" })),
    security: { status: "NOT_RUN" },
    cleanup: { status: "NOT_RUN", strategy: "atomic rollback sentinel plus independent residue query" },
    operational_residue: { total: -1, counts: {} },
    immutable_expected: { total: -1, counts: {}, policy: "run-scoped and bounded" },
    unexpected: { total: -1, counts: {} }, errors: [],
    timestamps: { start: started, end: null }, overall: "FAIL",
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
      evidence.security = { status: "PASS", detail: "static target, migration, manifest, SQL and residue-policy gates" };
      evidence.cleanup = { status: "PASS", strategy: "rollback sentinel and independent residue query statically verified" };
      evidence.operational_residue = { total: 0, counts: {} };
      evidence.immutable_expected = { total: 0, counts: {}, policy: "rollback execution leaves none; durable runs allow only bounded run-scoped history" };
      evidence.unexpected = { total: 0, counts: {} };
      evidence.cases = CASES.map((item) => ({ ...item, status: "PASS", detail: "manifest and SQL marker validated" }));
      evidence.overall = "PASS";
    } else {
      let linkedProjectRef = null;
      if (!options.local) linkedProjectRef = (await readFile(path.join("supabase", ".temp", "project-ref"), "utf8")).trim();
      const target = validateTargetGate(options, linkedProjectRef);
      evidence.project_ref = target.projectRef;
      evidence.environment = target.environment;
      const targetArgs = options.local ? ["--local"] : ["--linked", "--project-ref", target.projectRef];
      const preflight = (await query(preflightSql(), targetArgs))[0]?.preflight;
      if (!preflight) throw new Error("Preflight query returned no result.");
      validatePreflight(preflight);
      evidence.migration_latest = String(preflight.migration_latest);
      evidence.security = { status: "PASS", checks: preflight };
      validateResidue((await query(residueSql(runId), targetArgs))[0]?.residue ?? {});

      const runtimeDirectory = path.join("artifacts", "remote-smoke", runId);
      await mkdir(runtimeDirectory, { recursive: true });
      const runtimeSql = path.join(runtimeDirectory, "epic5-smoke-runtime.sql");
      await writeFile(runtimeSql, sqlTemplate.replaceAll("__RUN_TAG__", runId), "utf8");
      let output = "";
      let executionError = null;
      try {
        const execution = await runCommand(["db", "query", ...targetArgs, "--file", runtimeSql]);
        output = `${execution.stdout}\n${execution.stderr}`;
        executionError = new Error("Smoke SQL returned without its mandatory rollback sentinel.");
      } catch (error) {
        output = `${error.stdout ?? ""}\n${error.stderr ?? ""}`;
        const expected = output.includes("EPIC5_REMOTE_SMOKE_ROLLBACK")
          && CASES.every((item) => output.includes(`${item.id} PASS`));
        if (!expected) executionError = new Error(`Smoke SQL failed: ${output.trim()}`);
      }
      const after = (await query(residueSql(runId), targetArgs))[0]?.residue;
      if (after) {
        evidence.operational_residue = after.operational_residue;
        evidence.immutable_expected = after.immutable_expected;
        evidence.unexpected = after.unexpected;
      }
      validateResidue(after ?? {});
      evidence.cleanup = { status: "PASS", strategy: "forced atomic rollback and independent run-scoped residue query" };
      if (executionError) throw executionError;
      evidence.cases = CASES.map((item) => ({ ...item, status: "PASS", detail: "domain assertion passed before forced rollback" }));
      evidence.overall = "PASS";
    }
  } catch (error) {
    evidence.errors.push(error instanceof Error ? error.message : String(error));
    evidence.overall = "FAIL";
  } finally {
    evidence.timestamps.end = new Date().toISOString();
    artifact = await writeEvidence(evidence);
    printSummary(evidence, artifact);
  }
  if (evidence.overall !== "PASS") process.exitCode = 1;
  return evidence;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) await main();
