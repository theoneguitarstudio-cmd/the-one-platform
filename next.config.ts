import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  devIndicators: false,
  distDir: process.env.THE_ONE_UX_BUILD_CHECK === "1" ? ".next/ux-prototype-build" : ".next",
};

export default nextConfig;
