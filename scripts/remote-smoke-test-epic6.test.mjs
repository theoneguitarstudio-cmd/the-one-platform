import { readFile } from "node:fs/promises";

import { describe, expect, it } from "vitest";

import {
  CASES,
  EXPECTED_MIGRATION,
  parseArgs,
  validateCaseManifest,
  validatePreflight,
  validateResidue,
  validateSqlTemplate,
  validateTargetGate,
} from "./remote-smoke-test-epic6.mjs";

describe("Epic6 remote smoke safety contract", () => {
  it("has all 16 required meaningful case IDs", () => {
    expect(validateCaseManifest()).toBe(true);
    expect(CASES).toHaveLength(16);
  });

  it("requires matching supplied, expected, and linked refs", () => {
    const ref = "abcdefghijklmnopqrst";
    const options = parseArgs([
      "--execute",
      `--project-ref=${ref}`,
      `--expected-project-ref=${ref}`,
      "--environment=staging",
      "--backup-confirmed",
      "--operator-approved",
    ]);
    expect(validateTargetGate(options, ref)).toEqual({ environment: "staging", projectRef: ref });
    expect(() => validateTargetGate(options, "xxxxxxxxxxxxxxxxxxxx")).toThrow(/identity mismatch/i);
  });

  it("denies production unless separately allowed", () => {
    const ref = "abcdefghijklmnopqrst";
    const base = [
      "--execute",
      `--project-ref=${ref}`,
      `--expected-project-ref=${ref}`,
      "--environment=production",
      "--backup-confirmed",
      "--operator-approved",
    ];
    expect(() => validateTargetGate(parseArgs(base), ref)).toThrow(/denied by default/i);
    expect(validateTargetGate(parseArgs([...base, "--allow-production"]), ref).environment).toBe("production");
  });

  it("fails closed on migration, security, and residue mismatches", () => {
    const good = {
      migration_latest: EXPECTED_MIGRATION,
      required_rpc_missing: 0,
      rls_missing: 0,
      authenticated_raw_mutation_grants: 0,
      service_role_commerce_raw_mutation_grants: 0,
      private_helper_application_execute: 0,
      unsafe_security_definer_search_path: 0,
    };
    expect(validatePreflight(good)).toBe(true);
    expect(() => validatePreflight({ ...good, migration_latest: "20260904001000" })).toThrow(/migration latest mismatch/i);
    expect(() => validatePreflight({ ...good, rls_missing: 1 })).toThrow(/rls_missing=1/i);
    expect(validateResidue({ operational: 0, immutable: 0 })).toBe(true);
    expect(() => validateResidue({ operational: 1, immutable: 0 })).toThrow(/residue remains/i);
  });

  it("statically rejects dangerous cleanup and requires every SQL marker", async () => {
    const sql = await readFile("supabase/tests/remote/epic6_remote_smoke.sql.template", "utf8");
    expect(validateSqlTemplate(sql)).toBe(true);
    expect(() => validateSqlTemplate(sql + "\nset session_replication_role='replica';")).toThrow(/forbidden sql marker/i);
    expect(() => validateSqlTemplate(sql + "\ndelete from public.bookings;")).toThrow(/forbidden sql marker/i);
  });
});
