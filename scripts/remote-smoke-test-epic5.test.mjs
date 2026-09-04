import { readFile } from "node:fs/promises";

import { describe, expect, it } from "vitest";

import {
  CASES,
  EXPECTED_MIGRATION,
  parseArgs,
  validateCaseManifest,
  validateEvidence,
  validatePreflight,
  validateResidue,
  validateSqlTemplate,
  validateTargetGate,
} from "./remote-smoke-test-epic5.mjs";

describe("Epic5 remote smoke safety contract", () => {
  it("has all 15 required meaningful case IDs", () => {
    expect(validateCaseManifest()).toBe(true);
    expect(CASES).toHaveLength(15);
  });

  it("shares the explicit target and environment gate", () => {
    const ref = "abcdefghijklmnopqrst";
    const options = parseArgs([
      "--execute", `--project-ref=${ref}`, `--expected-project-ref=${ref}`,
      "--environment=staging", "--backup-confirmed", "--operator-approved",
    ]);
    expect(validateTargetGate(options, ref)).toEqual({ environment: "staging", projectRef: ref });
    expect(() => validateTargetGate(options, "xxxxxxxxxxxxxxxxxxxx")).toThrow(/identity mismatch/i);
    expect(() => validateTargetGate(parseArgs(["--execute"]), ref)).toThrow(/project refs are required/i);
  });

  it("denies production by default", () => {
    const ref = "abcdefghijklmnopqrst";
    const base = [
      "--execute", `--project-ref=${ref}`, `--expected-project-ref=${ref}`,
      "--environment=production", "--backup-confirmed", "--operator-approved",
    ];
    expect(() => validateTargetGate(parseArgs(base), ref)).toThrow(/denied by default/i);
    expect(validateTargetGate(parseArgs([...base, "--allow-production"]), ref).environment).toBe("production");
  });

  it("requires an allowed environment, backup confirmation, and operator approval", () => {
    const ref = "abcdefghijklmnopqrst";
    const base = ["--execute", `--project-ref=${ref}`, `--expected-project-ref=${ref}`];
    expect(() => validateTargetGate(parseArgs([...base, "--environment=development"]), ref)).toThrow(/environment must be/i);
    expect(() => validateTargetGate(parseArgs([...base, "--environment=staging"]), ref)).toThrow(/backup confirmation/i);
    expect(() => validateTargetGate(parseArgs([...base, "--environment=staging", "--backup-confirmed"]), ref)).toThrow(/operator approval/i);
  });

  it("fails closed on migration and every security preflight", () => {
    const good = {
      migration_latest: EXPECTED_MIGRATION,
      required_rpc_missing: 0,
      rls_missing: 0,
      authenticated_raw_mutation_grants: 0,
      service_role_high_risk_raw_mutation_grants: 0,
      private_helper_application_execute: 0,
      unsafe_security_definer_search_path: 0,
    };
    expect(validatePreflight(good)).toBe(true);
    expect(() => validatePreflight({ ...good, migration_latest: "20260904001000" })).toThrow(/migration latest mismatch/i);
    expect(() => validatePreflight({ ...good, service_role_high_risk_raw_mutation_grants: 1 })).toThrow(/raw_mutation_grants=1/i);
  });

  it("enforces operational, bounded immutable, and unexpected residue policy", () => {
    const good = {
      operational_residue: { total: 0 }, immutable_expected: { total: 12 }, unexpected: { total: 0 },
    };
    expect(validateResidue(good)).toBe(true);
    expect(() => validateResidue({ ...good, operational_residue: { total: 1 } })).toThrow(/operational residue/i);
    expect(() => validateResidue({ ...good, immutable_expected: { total: 65 } })).toThrow(/unbounded/i);
    expect(() => validateResidue({ ...good, unexpected: { total: 1 } })).toThrow(/unexpected evidence/i);
  });

  it("requires the unified evidence schema", () => {
    const evidence = Object.fromEntries([
      "run_id", "project_ref", "environment", "git_sha", "migration_latest",
      "security", "cleanup", "operational_residue", "immutable_expected",
      "unexpected", "timestamps",
    ].map((key) => [key, {}]));
    evidence.cases = [];
    evidence.errors = [];
    expect(validateEvidence(evidence)).toBe(true);
    delete evidence.cleanup;
    expect(() => validateEvidence(evidence)).toThrow(/cleanup/i);
  });

  it("rejects forbidden SQL, broad cleanup, and foreign machine paths", async () => {
    const sql = await readFile("supabase/tests/remote/epic5_remote_smoke.sql.template", "utf8");
    expect(validateSqlTemplate(sql)).toBe(true);
    expect(() => validateSqlTemplate(sql + "\nset session_replication_role='replica';")).toThrow(/forbidden sql marker/i);
    expect(() => validateSqlTemplate(sql + "\ndelete from public.entitlements;")).toThrow(/forbidden sql marker|raw domain mutation/i);
    expect(() => validateSqlTemplate(sql + "\n-- C:\\\\Users\\\\foreign\\\\node.exe")).toThrow(/foreign machine path/i);
  });

  it("uses repository-relative wrappers without secrets", async () => {
    const wrapper = await readFile("scripts/remote-smoke-test-epic5.ps1", "utf8");
    expect(wrapper).toContain("$PSScriptRoot");
    expect(wrapper.replaceAll(/\\+/g, "/")).not.toMatch(/[A-Z]:\/Users\//i);
    expect(wrapper.toLowerCase()).not.toContain("service_role");
  });
});
