const ALLOWED_REDIRECT_PATHS = new Set([
  "/student",
  "/teacher",
  "/admin",
  "/auth/reset-password",
]);

export function getSafeRedirectPath(
  candidate: string | null | undefined,
  fallback = "/student",
): string {
  if (!candidate || !candidate.startsWith("/") || candidate.startsWith("//")) {
    return fallback;
  }

  try {
    const parsed = new URL(candidate, "https://the-one.invalid");
    if (
      parsed.origin !== "https://the-one.invalid" ||
      !ALLOWED_REDIRECT_PATHS.has(parsed.pathname)
    ) {
      return fallback;
    }

    return parsed.pathname;
  } catch {
    return fallback;
  }
}
