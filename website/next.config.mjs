/** @type {import('next').NextConfig} */
const nextConfig = {
  // Static export → Cloudflare Pages. The single dynamic endpoint
  // (Buy-me-a-coffee checkout) lives in functions/api/coffee.ts as a
  // Cloudflare Pages Function, deployed alongside out/.
  output: 'export',
  images: { unoptimized: true },
};

export default nextConfig;
