import { describe, expect, it } from "vitest";

import { normalizeMeetingUrl } from "../src/modules/trials/meeting-url";

describe("trial meeting URL validation", () => {
  it("accepts canonical Google Meet and Zoom meeting URLs", () => {
    expect(
      normalizeMeetingUrl(
        "manual_google_meet",
        "https://meet.google.com/abc-defg-hij",
      ),
    ).toBe("https://meet.google.com/abc-defg-hij");
    expect(
      normalizeMeetingUrl(
        "manual_zoom",
        "https://us02web.zoom.us/j/123456789",
      ),
    ).toBe("https://us02web.zoom.us/j/123456789");
  });

  it.each([
    ["manual_google_meet", "https://meet.google.com.evil.example/room"],
    ["manual_google_meet", "https://meet.google.com@evil.example/room"],
    ["manual_google_meet", "https://evil.example/room"],
    ["manual_google_meet", "https://localhost/room"],
    ["manual_google_meet", "https://127.0.0.1/room"],
    ["manual_google_meet", "https://10.0.0.1/room"],
    ["manual_google_meet", "http://meet.google.com/room"],
    ["manual_google_meet", "javascript:alert(1)"],
    ["manual_google_meet", "data:text/html,unsafe"],
    ["manual_google_meet", "file:///tmp/unsafe"],
    ["manual_google_meet", "https://meet.google.com:8443/room"],
    ["manual_google_meet", "https://meet.google.com\\@evil.example/room"],
    ["manual_zoom", "https://zoom.us.evil.example/j/123"],
    ["manual_zoom", "https://evil.example/j/123"],
    ["manual_zoom", "https://meet.google.com/abc-defg-hij"],
    ["manual_url", "https://example.com/room"],
  ])("rejects unsafe or provider-mismatched URL %s %s", (provider, url) => {
    expect(normalizeMeetingUrl(provider, url)).toBeNull();
  });

  it("rejects literal control characters and surrounding whitespace", () => {
    expect(
      normalizeMeetingUrl(
        "manual_google_meet",
        "https://meet.google.com/room\nheader",
      ),
    ).toBeNull();
    expect(
      normalizeMeetingUrl(
        "manual_google_meet",
        " https://meet.google.com/room",
      ),
    ).toBeNull();
  });
});
