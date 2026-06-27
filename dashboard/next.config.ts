import type { NextConfig } from "next";
import fs from "node:fs";
import path from "node:path";

function loadRootEnvFile() {
  const envPath = path.resolve(__dirname, "..", ".env");
  if (!fs.existsSync(envPath)) return;

  const content = fs.readFileSync(envPath, "utf8");
  for (const line of content.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const eq = trimmed.indexOf("=");
    if (eq === -1) continue;
    const key = trimmed.slice(0, eq).trim();
    const value = trimmed.slice(eq + 1).trim();
    if (key && process.env[key] === undefined) {
      process.env[key] = value;
    }
  }
}

loadRootEnvFile();

const supabaseUrl = process.env.SUPABASE_URL ?? "";
const supabaseAnonKey = process.env.SUPABASE_ANON_KEY ?? "";

// Firebase web push — values come from the root .env file.
// Register a web app in the ivey-cap Firebase Console to get
// FIREBASE_WEB_APP_ID, then add a Web Push certificate to get
// FIREBASE_VAPID_KEY.
const firebaseWebAppId = process.env.FIREBASE_WEB_APP_ID ?? "";
const firebaseVapidKey = process.env.FIREBASE_VAPID_KEY ?? "";

const nextConfig: NextConfig = {
  env: {
    NEXT_PUBLIC_SUPABASE_URL: supabaseUrl,
    NEXT_PUBLIC_SUPABASE_ANON_KEY: supabaseAnonKey,
    NEXT_PUBLIC_FIREBASE_WEB_APP_ID: firebaseWebAppId,
    NEXT_PUBLIC_FIREBASE_VAPID_KEY: firebaseVapidKey,
  },
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
