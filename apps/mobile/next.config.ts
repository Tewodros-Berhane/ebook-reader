import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "export",
  trailingSlash: true,
  images: {
    unoptimized: true,
  },
  transpilePackages: ["@lumina/ui", "@lumina/core"],
};

export default nextConfig;
