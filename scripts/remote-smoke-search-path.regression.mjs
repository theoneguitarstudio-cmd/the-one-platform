// Run explicitly with: node scripts/remote-smoke-search-path.regression.mjs
// Requires the existing LOCAL Supabase DB container. Only SELECT/VALUES run;
// no functions, triggers, fixtures, or schemas are created or modified.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";

import { preflightSql as epic5Sql, validatePreflight as validateEpic5 } from "./remote-smoke-test-epic5.mjs";
import { preflightSql as epic6Sql, validatePreflight as validateEpic6 } from "./remote-smoke-test-epic6.mjs";

const reviewed = {
  schema: "public", name: "rls_auto_enable", owner: "postgres",
  returns: "event_trigger", nargs: 0, config: ["search_path=pg_catalog"],
  triggerName: "ensure_rls", event: "ddl_command_end", enabled: "O",
  bound: true, tags: ["CREATE TABLE", "CREATE TABLE AS", "SELECT INTO"],
};
const cases = [
  ["reviewed remote RLS event trigger", {}, 0],
  ["application function with empty search_path", { name: "app_rpc", returns: "void", config: ['search_path=""'], bound: false }, 0],
  ["application pg_catalog path is still rejected", { name: "app_rpc", returns: "void" }, 1],
  ["unknown event trigger", { name: "other_event_trigger" }, 1],
  ["wrong schema", { schema: "private" }, 1],
  ["wrong owner", { owner: "authenticated" }, 1],
  ["ordinary function using the same name", { returns: "void" }, 1],
  ["overloaded function", { nargs: 1 }, 1],
  ["missing config", { config: null }, 1],
  ["empty config array", { config: [] }, 1],
  ["public path", { config: ["search_path=public"] }, 1],
  ["mixed path", { config: ["search_path=pg_catalog, public"] }, 1],
  ["additional config", { config: ["search_path=pg_catalog", "row_security=off"] }, 1],
  ["missing trigger binding", { bound: false }, 1],
  ["wrong trigger name", { triggerName: "other_trigger" }, 1],
  ["wrong trigger event", { event: "ddl_command_start" }, 1],
  ["disabled trigger", { enabled: "D" }, 1],
  ["unexpected trigger tags", { tags: ["ALTER TABLE"] }, 1],
];
const literal = (value) => `'${value.replaceAll("'", "''")}'`;
const array = (values) => values === null ? "null::text[]" : `array[${values.map(literal).join(",")}]::text[]`;
const queries = [];
for (const [epic, buildSql] of [["Epic5", epic5Sql], ["Epic6", epic6Sql]]) {
  // Exercise the actual generated SQL predicate, not a JavaScript imitation.
  const countSql = buildSql().match(/'unsafe_security_definer_search_path',\((select count\(\*\) from pg_proc p[\s\S]+?)\)\s*\) as preflight;/)?.[1];
  assert.ok(countSql, `${epic}: search_path count query must be present`);
  for (const [name, overrides, expected] of cases) {
    const f = { ...reviewed, ...overrides };
    queries.push(`with pg_proc(oid,pronamespace,proname,proowner,prorettype,pronargs,prosecdef,proconfig) as (
      values (1::oid,${literal(f.schema)}::regnamespace,${literal(f.name)},${literal(f.owner)}::regrole,
        ${literal(f.returns)}::regtype,${f.nargs},true,${array(f.config)})
    ), pg_event_trigger(evtfoid,evtname,evtevent,evtenabled,evttags) as (
      values (${f.bound ? 1 : 2}::oid,${literal(f.triggerName)},${literal(f.event)},${literal(f.enabled)},${array(f.tags)})
    ) select jsonb_build_object('epic',${literal(epic)},'case',${literal(name)},
      'expected',${expected},'actual',(${countSql}));`);
  }
}
const result = spawnSync("docker", ["exec", "-i", "supabase_db_the-one-platform",
  "psql", "-X", "-U", "postgres", "-d", "postgres", "-v", "ON_ERROR_STOP=1", "-At"], {
  input: queries.join("\n"), encoding: "utf8", timeout: 30000,
});
assert.equal(result.error, undefined, result.error?.message);
assert.equal(result.status, 0, result.stderr);
const rows = result.stdout.trim().split(/\r?\n/).map((line) => JSON.parse(line));
assert.equal(rows.length, queries.length);
const failures = rows.filter((row) => row.actual !== row.expected);
assert.deepEqual(failures, [], "search_path SQL regression failures");
for (const validate of [validateEpic5, validateEpic6]) {
  const good = {
    migration_latest: "20260904001100", required_rpc_missing: 0, rls_missing: 0,
    authenticated_raw_mutation_grants: 0, service_role_high_risk_raw_mutation_grants: 0,
    service_role_commerce_raw_mutation_grants: 0, private_helper_application_execute: 0,
    unsafe_security_definer_search_path: 0,
  };
  assert.equal(validate(good), true);
  assert.throws(() => validate({ ...good, unsafe_security_definer_search_path: 1 }),
    { message: "Security preflight unsafe_security_definer_search_path=1." });
}
console.log(`PASS: ${rows.length} read-only PostgreSQL predicate cases; both validators still reject the exact production error.`);
