const CONTROL_OR_WHITESPACE = /[\u0000-\u0020\u007f]/;

export const SUPPORTED_MEETING_PROVIDERS = [
  "manual_google_meet",
  "manual_zoom",
] as const;

export type SupportedMeetingProvider =
  (typeof SUPPORTED_MEETING_PROVIDERS)[number];

export function normalizeMeetingUrl(
  provider: unknown,
  rawUrl: unknown,
): string | null {
  if (
    !SUPPORTED_MEETING_PROVIDERS.includes(
      provider as SupportedMeetingProvider,
    ) ||
    typeof rawUrl !== "string" ||
    rawUrl.length === 0 ||
    rawUrl.length > 2048 ||
    rawUrl !== rawUrl.trim() ||
    CONTROL_OR_WHITESPACE.test(rawUrl) ||
    rawUrl.includes("\\")
  ) {
    return null;
  }

  let parsed: URL;
  try {
    parsed = new URL(rawUrl);
  } catch {
    return null;
  }

  if (
    parsed.protocol !== "https:" ||
    parsed.username !== "" ||
    parsed.password !== "" ||
    parsed.port !== ""
  ) {
    return null;
  }

  const hostname = parsed.hostname.toLowerCase();
  if (provider === "manual_google_meet" && hostname !== "meet.google.com") {
    return null;
  }
  if (
    provider === "manual_zoom" &&
    hostname !== "zoom.us" &&
    !hostname.endsWith(".zoom.us")
  ) {
    return null;
  }

  return parsed.href;
}
