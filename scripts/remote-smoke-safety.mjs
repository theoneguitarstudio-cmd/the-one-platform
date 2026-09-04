export const EXPECTED_REMOTE_MIGRATION = "20260904001100";

const ALLOWED_ENVIRONMENTS = new Set(["staging", "recovery", "production"]);

export function parseRemoteSmokeArgs(argv) {
  const options = {
    allowProduction: false,
    backupConfirmed: false,
    environment: undefined,
    execute: false,
    expectedProjectRef: undefined,
    local: false,
    operatorApproved: false,
    projectRef: undefined,
    validateOnly: false,
  };
  for (const argument of argv) {
    if (argument === "--allow-production") options.allowProduction = true;
    else if (argument === "--backup-confirmed") options.backupConfirmed = true;
    else if (argument === "--execute") options.execute = true;
    else if (argument === "--local") options.local = true;
    else if (argument === "--operator-approved") options.operatorApproved = true;
    else if (argument === "--validate-only") options.validateOnly = true;
    else if (argument.startsWith("--environment=")) options.environment = argument.slice(14);
    else if (argument.startsWith("--expected-project-ref=")) options.expectedProjectRef = argument.slice(23);
    else if (argument.startsWith("--project-ref=")) options.projectRef = argument.slice(14);
    else throw new Error(`Unknown argument: ${argument}`);
  }
  return options;
}

export function validateRemoteSmokeTarget(options, linkedProjectRef) {
  if (options.validateOnly) return { environment: "validate-only", projectRef: "none" };
  if (options.local) {
    if (!options.execute) throw new Error("Local validation requires --execute.");
    return { environment: "local-validation", projectRef: "local" };
  }
  if (!options.execute) throw new Error("Remote execution requires explicit --execute.");
  if (!options.projectRef || !options.expectedProjectRef) {
    throw new Error("Both supplied and expected project refs are required.");
  }
  if (!/^[a-z0-9]{20}$/.test(options.projectRef) || !/^[a-z0-9]{20}$/.test(options.expectedProjectRef)) {
    throw new Error("Project refs must be 20 lowercase alphanumeric characters.");
  }
  if (!ALLOWED_ENVIRONMENTS.has(options.environment)) {
    throw new Error("Environment must be staging, recovery, or production.");
  }
  if (options.environment === "production" && !options.allowProduction) {
    throw new Error("Production is denied by default; --allow-production is required.");
  }
  if (!options.backupConfirmed) throw new Error("Backup confirmation is required.");
  if (!options.operatorApproved) throw new Error("Explicit operator approval is required.");
  if (!linkedProjectRef) throw new Error("No linked project ref was found; the harness will not relink automatically.");
  if (options.projectRef !== options.expectedProjectRef || options.projectRef !== linkedProjectRef) {
    throw new Error(`Project identity mismatch: supplied=${options.projectRef} expected=${options.expectedProjectRef} linked=${linkedProjectRef}.`);
  }
  return { environment: options.environment, projectRef: options.projectRef };
}
