import { previewBuildMeta } from "@/lib/preview/build-meta";
export function PreviewFingerprint() {
  const meta=previewBuildMeta();
  if (!meta) return null;
  return <footer className="preview-fingerprint"><a href="/__preview-meta">Preview · {meta.shortSha}</a></footer>;
}
