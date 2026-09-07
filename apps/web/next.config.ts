import type { NextConfig } from "next";

export function getAuthoringRedirects(authoringUrl = process.env.NEXT_PUBLIC_AUTHORING_URL) {
  const destination = authoringUrl?.trim().replace(/\/+$/, "");
  if (!destination) return [];

  return [
    { source: "/authoring", destination, permanent: false },
    { source: "/authoring/:path*", destination: `${destination}/:path*`, permanent: false },
  ];
}

const nextConfig: NextConfig = {
  redirects: getAuthoringRedirects,
};

export default nextConfig;
