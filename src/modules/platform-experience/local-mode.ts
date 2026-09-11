/** A local-only transport selection. Never enables a production Auth bypass. */
export function isLocalExperience(environment: string | undefined, flag: string | undefined, hostname: string) {
  return environment === "development" && flag === "1" && ["127.0.0.1", "localhost", "[::1]"].includes(hostname);
}
