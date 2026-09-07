import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  async redirects() {
    return [
      { source: "/authoring", destination: "/", permanent: true },
      { source: "/authoring/:path*", destination: "/:path*", permanent: true },
    ];
  },
};

export default nextConfig;
