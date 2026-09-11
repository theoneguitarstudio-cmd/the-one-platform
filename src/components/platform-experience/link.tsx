"use client";

import NextLink from "next/link";
import { useRouter as useNextRouter } from "next/navigation";
import { createContext, useContext, useMemo, type ComponentProps, type ReactNode } from "react";

const LocalRoutes = createContext(false);
export function PlatformRoutes({ enabled, children }: { enabled: boolean; children: ReactNode }) {
  return <LocalRoutes.Provider value={enabled}>{children}</LocalRoutes.Provider>;
}
export function localHref(href: string, enabled: boolean) {
  if (!enabled || !/^\/ux-prototype(?:\/|\?|#|$)/.test(href)) return href;
  const path = href.slice("/ux-prototype".length);
  if (path.startsWith("//") || path.includes("\\")) return "/";
  return path.startsWith("/") ? path : `/${path}`;
}
export default function Link({ href, ...props }: ComponentProps<typeof NextLink>) {
  const enabled = useContext(LocalRoutes);
  return <NextLink {...props} href={typeof href === "string" ? localHref(href, enabled) : href} />;
}
export function useRouter() {
  const router = useNextRouter();
  const enabled = useContext(LocalRoutes);
  return useMemo(() => ({ ...router,
    push: (href: string, options?: Parameters<typeof router.push>[1]) => router.push(localHref(href, enabled), options),
    replace: (href: string, options?: Parameters<typeof router.replace>[1]) => router.replace(localHref(href, enabled), options),
  }), [router, enabled]);
}
