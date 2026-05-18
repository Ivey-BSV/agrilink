import type { NextConfig } from "next";
import path from "node:path";

const nextConfig: NextConfig = {
  turbopack: {
    root: path.resolve(__dirname),
  },
  async redirects() {
    return [
      { source: "/dashboard/feed", destination: "/platform/feed", permanent: false },
      { source: "/dashboard/directory", destination: "/platform/directory", permanent: false },
      { source: "/dashboard/hub", destination: "/dashboard", permanent: false },
      { source: "/dashboard/profile", destination: "/platform/profile", permanent: false },
    ];
  },
};

export default nextConfig;
