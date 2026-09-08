import { isMockDataMode } from "./mode";
export function previewBuildMeta() {
  if (!isMockDataMode()) return null;
  const candidate = process.env.NEXT_PUBLIC_PREVIEW_SHA ?? "";
  const sha = /^[a-f0-9]{40}(?:-dirty)?$/.test(candidate) ? candidate : "unavailable";
  return { application: "The One 2.0", environment: "preview", dataMode: "mock", sha, shortSha: sha === "unavailable" ? sha : sha.slice(0,7)+(sha.endsWith("-dirty") ? "-dirty" : "") };
}
