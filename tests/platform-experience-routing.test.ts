import { describe, expect, it } from "vitest";
import { localHref } from "../src/components/platform-experience/link";

describe("local navigation mapping",()=>{
  it("maps the same native surfaces without discarding query or anchors",()=>{
    expect(localHref("/ux-prototype",true)).toBe("/");
    expect(localHref("/ux-prototype/teachers/t1?tab=private#packages",true)).toBe("/teachers/t1?tab=private#packages");
    expect(localHref("/ux-prototype#p5-teacher",true)).toBe("/#p5-teacher");
    expect(localHref("/ux-prototype/teacher",false)).toBe("/ux-prototype/teacher");
  });
  it("cannot turn an internal path into a protocol-relative external URL",()=>{
    expect(localHref("/ux-prototype//example.test",true)).toBe("/");
    expect(localHref("/ux-prototype/\\example.test",true)).toBe("/");
    expect(localHref("/ux-prototype-other",true)).toBe("/ux-prototype-other");
  });
});
