import {readFileSync} from "node:fs";
import {join} from "node:path";
import {describe,expect,it} from "vitest";

const migration=readFileSync(join(process.cwd(),"supabase/migrations/20260901000300_resolve_role_helper_overload_ambiguity.sql"),"utf8");

describe("role helper compatibility migration",()=>{
  it("adds the preferred string-category signature",()=>expect(migration).toContain("current_user_has_role(expected_role text)"));
  it("keeps security-definer search_path empty",()=>expect(migration).toMatch(/security definer\s+set search_path = ''/i));
  it("revokes default execution before scoped grants",()=>{expect(migration).toContain("from public, anon, authenticated");expect(migration).toContain("to authenticated, service_role")});
  it("does not remove either typed production signature",()=>expect(migration).not.toMatch(/drop function/i));
});
