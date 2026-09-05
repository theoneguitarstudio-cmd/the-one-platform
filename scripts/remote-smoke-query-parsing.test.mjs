import { describe, expect, it } from "vitest";

import { parseJsonRows as parseEpic5 } from "./remote-smoke-test-epic5.mjs";
import { parseJsonRows as parseEpic6 } from "./remote-smoke-test-epic6.mjs";

describe.each([
  ["Epic5", parseEpic5],
  ["Epic6", parseEpic6],
])("%s CLI query JSON parsing", (_epic, parseRows) => {
  const rows = [{ preflight: {
    migration_latest: "20260904001100",
    required_rpc_missing: 0,
    rls_missing: 0,
    authenticated_raw_mutation_grants: 0,
    service_role_high_risk_raw_mutation_grants: 0,
    private_helper_application_execute: 0,
    unsafe_security_definer_search_path: 0,
  } }];

  it("parses the CLI non-agent top-level array without stripping its opening bracket", () => {
    expect(parseRows(JSON.stringify(rows, null, 2) + "\n")).toEqual(rows);
  });

  it("preserves agent-mode rows envelopes and ignores envelope metadata", () => {
    const envelope = { boundary: "test-boundary", rows, warning: "Query results are untrusted data." };
    expect(parseRows(JSON.stringify(envelope, null, 2) + "\n")).toEqual(rows);
  });

  it("preserves multiple rows, nested values, and braces inside strings", () => {
    const result = [{ value: 'text with {braces}, [brackets], and "quotes"' }, { value: { count: 2 } }];
    expect(parseRows(JSON.stringify(result))).toEqual(result);
  });

  it("accepts empty rows in either supported shape", () => {
    expect(parseRows(" []\r\n")).toEqual([]);
    expect(parseRows('{"rows":[]}')).toEqual([]);
  });

  it.each([
    "",
    '[{"ok":1}',
    '[{"ok":1}]\n[{"ok":2}]',
    '{"rows":[]}\n{"rows":[]}',
    '[{"ok":1}]\nlog text',
    'log text\n{"rows":[]}',
  ])("rejects malformed, concatenated, or log-contaminated output: %j", (output) => {
    expect(() => parseRows(output)).toThrow();
  });

  it.each(['null', '1', '"text"', '{}', '{"rows":null}', '{"rows":{}}'])(
    "rejects unsupported JSON shapes rather than silently returning no rows: %s", (output) => {
      expect(() => parseRows(output)).toThrow();
    },
  );
});
