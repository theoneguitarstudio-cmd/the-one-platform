import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

const directory = join(process.cwd(), "supabase/migrations");
// Follow replacements across the migration chain, so an additive corrective
// migration can satisfy this contract without editing applied migrations.
const definitions = readdirSync(directory)
  .filter((file) => /^\d+_.*\.sql$/.test(file))
  .sort()
  .flatMap((file) => {
    const sql = readFileSync(join(directory, file), "utf8")
      .replace(/\/\*[\s\S]*?\*\//g, " ")
      .replace(/--[^\r\n]*/g, " ");
    return Array.from(sql.matchAll(
      /create\s+(?:or\s+replace\s+)?function\s+public\.consume_lesson_credit\s*\(\s*p_reservation_id\s+uuid\s*,\s*p_lesson_id\s+uuid\s*\)[\s\S]*?\bas\s+\$(\w*)\$([\s\S]*?)\$\1\$/gi,
    ), (match) => ({ file, body: match[2] }));
  });

describe("P1-2 consume_lesson_credit Teacher role authority", () => {
  it("revalidates the current Teacher role before delegating credit consumption", () => {
    const latest = definitions.at(-1);
    expect(latest, "The final public.consume_lesson_credit(uuid,uuid) definition must exist").toBeDefined();
    const body = latest!.body;
    const coreCall = body.search(/\bprivate\.consume_lesson_credit_core\s*\(/i);
    expect(coreCall, "The public RPC must delegate to the shared credit core").toBeGreaterThan(-1);

    // This is a static guard for the existing role helper convention, not a
    // proof of control flow. The companion pgTAP test verifies actual denial
    // after role removal, plus successful consumption by an authorized Teacher.
    expect(
      body.slice(0, coreCall),
      `${latest!.file}: non-Admin consumption must revalidate Teacher role; ` +
        "active teaching_status and historical Lesson assignment are insufficient",
    ).toMatch(/private\.current_user_has_role\s*\(\s*(?:array\s*\[\s*)?'teacher'\s*::\s*public\.app_role\s*\]?\s*\)/i);
  });
});
