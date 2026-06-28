import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { GoogleAuth } from "npm:google-auth-library@9.15.1";

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

async function getFcmAccessToken(
  serviceAccount: Record<string, unknown>,
): Promise<{ token: string; projectId: string }> {
  const auth = new GoogleAuth({
    credentials: serviceAccount as never,
    scopes: [
      "https://www.googleapis.com/auth/firebase.messaging",
      "https://www.googleapis.com/auth/cloud-platform",
    ],
  });
  const client = await auth.getClient();
  const res = await client.getAccessToken();
  const token = typeof res === "string" ? res : res?.token;
  if (!token) throw new Error("Failed to obtain FCM access token");
  const projectId = serviceAccount.project_id as string;
  if (!projectId) throw new Error("Service account missing project_id");
  return { token, projectId };
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json(405, { error: "Method not allowed" });
  }

  const expected = Deno.env.get("PUSH_WEBHOOK_SECRET");
  const headerSecret =
    req.headers.get("x-cap-push-secret") ?? req.headers.get("X-Cap-Push-Secret");
  const authz = req.headers.get("authorization") ?? "";
  const bearer = authz.startsWith("Bearer ") ? authz.slice(7).trim() : "";
  const secretOk =
    !!expected && (headerSecret === expected || bearer === expected);
  if (!secretOk) {
    return new Response("Unauthorized", { status: 401 });
  }

  let payload: Record<string, unknown>;
  try {
    payload = (await req.json()) as Record<string, unknown>;
  } catch {
    return json(400, { error: "Invalid JSON" });
  }

  const record = payload["record"] as Record<string, unknown> | undefined;
  if (!record || typeof record !== "object") {
    return json(200, { skipped: "no_record" });
  }

  if (payload["table"] && payload["table"] !== "user_notifications") {
    return json(200, { skipped: "wrong_table" });
  }

  const userId = record["user_id"] as string | undefined;
  if (!userId) {
    return json(200, { skipped: "no_user_id" });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRole) {
    return json(500, { error: "Missing Supabase env" });
  }

  const admin = createClient(supabaseUrl, serviceRole);

  const { data: settings } = await admin
    .from("user_notification_settings")
    .select("push_enabled")
    .eq("user_id", userId)
    .maybeSingle();

  if (settings && settings.push_enabled !== true) {
    return json(200, { skipped: "push_disabled" });
  }

  const { data: profile, error: profileError } = await admin
    .from("user_profiles")
    .select("fcm_token")
    .eq("id", userId)
    .maybeSingle();

  if (profileError) {
    return json(500, { error: profileError.message });
  }

  const fcmToken = profile?.fcm_token as string | null | undefined;
  if (!fcmToken) {
    return json(200, { skipped: "no_device_token" });
  }

  const saRaw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
  if (!saRaw) {
    return json(500, { error: "FIREBASE_SERVICE_ACCOUNT_JSON not set" });
  }

  let serviceAccount: Record<string, unknown>;
  try {
    serviceAccount = JSON.parse(saRaw) as Record<string, unknown>;
  } catch {
    return json(500, { error: "Invalid FIREBASE_SERVICE_ACCOUNT_JSON" });
  }

  let accessToken: string;
  let projectId: string;
  try {
    const t = await getFcmAccessToken(serviceAccount);
    accessToken = t.token;
    projectId = t.projectId;
  } catch (e) {
    return json(500, { error: String(e) });
  }

  const title = String(record["title"] ?? "AgriLink");
  const bodyText = String(record["body"] ?? "");
  const type = String(record["type"] ?? "");
  const id = String(record["id"] ?? "");
  const rawData = record["data"];
  const data: Record<string, string> = {
    type,
    notification_id: id,
    payload: typeof rawData === "object" && rawData !== null
      ? JSON.stringify(rawData)
      : "{}",
  };

  const fcmRes = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token: fcmToken,
          notification: { title, body: bodyText },
          data,
        },
      }),
    },
  );

  const fcmText = await fcmRes.text();
  if (!fcmRes.ok) {
    console.error("FCM error", fcmRes.status, fcmText);
    return json(502, { error: "FCM send failed", detail: fcmText });
  }

  let fcmJson: unknown = {};
  try {
    fcmJson = fcmText ? JSON.parse(fcmText) : {};
  } catch {
    fcmJson = { raw: fcmText };
  }
  return json(200, { ok: true, fcm: fcmJson });
});
