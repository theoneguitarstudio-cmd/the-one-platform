import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

const migrationsDirectory = join(process.cwd(), "supabase/migrations");
const tables = ["lessons", "lesson_records"] as const;
const operations = ["insert", "update", "delete"] as const;

// Offline guard for explicit table ACLs in this repository, not a PostgreSQL
// privilege evaluator. The companion pgTAP test checks effective privileges,
// including column grants and role inheritance, against the actual database.
// Replay in migration order so a NEW corrective migration can make this pass;
// never require removing the historical GRANT from an applied migration.
const aclChanges = readdirSync(migrationsDirectory)
  .filter((file) => /^\d+_.*\.sql$/.test(file))
  .sort()
  .flatMap((file) => {
    const sql = readFileSync(join(migrationsDirectory, file), "utf8")
      .replace(/\$(\w*)\$[\s\S]*?\$\1\$/g, " ")
      .replace(/\/\*[\s\S]*?\*\//g, " ")
      .replace(/--[^\r\n]*/g, " ");

    return Array.from(sql.matchAll(
      /\b(grant|revoke)\s+([^;]+?)\s+on\s+(?:table\s+)?([^;]+?)\s+(?:to|from)\s+([^;]+);/gi,
    ), (match) => ({
      file,
      action: match[1].toLowerCase(),
      privileges: match[2].toLowerCase().trim(),
      tables: match[3].toLowerCase().split(",").map((table) => table.trim()),
      roles: match[4].toLowerCase().split(",").map((role) => role.trim()),
      statement: match[0].replace(/\s+/g, " "),
    }));
  });

describe("P1 Lesson raw DML authority contract", () => {
  for (const table of tables) {
    it.each(operations)(`service_role must not have raw %s on public.${table}`, (operation) => {
      const outstandingGrants = new Map<string, string>();

      for (const change of aclChanges) {
        if (!change.tables.includes(`public.${table}`)) continue;
        // Column ACLs are deliberately left to pgTAP; a column-only REVOKE
        // must not accidentally erase a still-active table-level GRANT here.
        const privileges = change.privileges
          .replace(/\b\w+\s*\([^)]*\)/g, "")
          .split(",")
          .map((privilege) => privilege.trim());
        if (!privileges.some((privilege) =>
          privilege === operation || /^all(?: privileges)?$/.test(privilege))) continue;

        for (const role of ["service_role", "public"]) {
          if (!change.roles.includes(role)) continue;
          if (change.action === "grant") {
            outstandingGrants.set(role, `${change.file}: ${change.statement}`);
          } else {
            outstandingGrants.delete(role);
          }
        }
      }

      expect(
        [...outstandingGrants.values()],
        `Raw ${operation.toUpperCase()} on public.${table} bypasses Lesson domain authorization, ` +
          "Booking lifecycle, credit consumption, and domain audit. Revoke the privilege in a new migration.",
      ).toEqual([]);
    });
  }
});
