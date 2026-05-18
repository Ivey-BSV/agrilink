import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { purgeUserData } from "./purge_user.ts";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const jsonHeaders = { ...corsHeaders, "Content-Type": "application/json" };

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders });
}

function err(message: string, status = 400) {
  return json({ error: message }, status);
}

type Profile = {
  account_kind: string | null;
  app_role: string | null;
};

async function loadProfile(admin: ReturnType<typeof createClient>, userId: string): Promise<Profile | null> {
  const { data, error } = await admin.from("user_profiles").select("account_kind, app_role").eq("id", userId).maybeSingle();
  if (error || !data) return null;
  return data as Profile;
}

function isSuper(p: Profile | null) {
  return p?.account_kind === "staff" && p?.app_role === "super_admin";
}

function isAdminPlus(p: Profile | null) {
  return p?.account_kind === "staff" && (p?.app_role === "admin" || p?.app_role === "super_admin");
}

function isStaff(p: Profile | null) {
  return (
    p?.account_kind === "staff" &&
    (p?.app_role === "moderator" || p?.app_role === "admin" || p?.app_role === "super_admin")
  );
}

function usernameFromEmail(email: string) {
  const local = email.split("@")[0] ?? "user";
  const safe = local.toLowerCase().replace(/[^a-z0-9_]/g, "_").replace(/_+/g, "_").slice(0, 24);
  return (safe.length >= 3 ? safe : "user") + "_" + Math.floor(1000 + Math.random() * 8999);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return err("Method not allowed", 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return err("Missing authorization", 401);

  const supabaseUser = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });

  const {
    data: { user },
    error: userError,
  } = await supabaseUser.auth.getUser();
  if (userError || !user) return err("Unauthorized", 401);

  const admin = createServiceClient(supabaseUrl, serviceRoleKey);

  let body: Record<string, unknown>;
  try {
    body = (await req.json()) as Record<string, unknown>;
  } catch {
    return err("Invalid JSON", 400);
  }

  const action = String(body.action ?? "");
  const callerProfile = await loadProfile(admin, user.id);
  if (!isStaff(callerProfile)) {
    return err("Staff access required in user_profiles", 403);
  }

  try {
    switch (action) {
      case "create_staff": {
        if (!isSuper(callerProfile)) return err("Super admin only", 403);
        const email = String(body.email ?? "").trim().toLowerCase();
        const password = String(body.password ?? "");
        const app_role = String(body.app_role ?? "moderator");
        if (!email || !password) return err("email and password required");
        if (password.length < 8) return err("password min 8 chars");
        if (!["moderator", "admin", "super_admin"].includes(app_role)) return err("invalid app_role");

        const { data: created, error: cErr } = await admin.auth.admin.createUser({
          email,
          password,
          email_confirm: true,
        });
        if (cErr || !created.user) return err(cErr?.message ?? "createUser failed", 400);

        const username = usernameFromEmail(email);
        const { error: pErr } = await admin.from("user_profiles").upsert(
          {
            id: created.user.id,
            username,
            full_name: String(body.full_name ?? ""),
            account_kind: "staff",
            app_role,
            registration_status: "active",
            updated_at: new Date().toISOString(),
          },
          { onConflict: "id" },
        );
        if (pErr) {
          await admin.auth.admin.deleteUser(created.user.id);
          return err(pErr.message, 500);
        }
        return json({ success: true, user_id: created.user.id });
      }

      case "invite_farmer": {
        if (!isAdminPlus(callerProfile)) return err("Admin access required", 403);
        const email = String(body.email ?? "").trim().toLowerCase();
        const password = String(body.password ?? "");
        if (!email || !password) return err("email and password required");
        if (password.length < 8) return err("password min 8 chars");

        const { data: created, error: cErr } = await admin.auth.admin.createUser({
          email,
          password,
          email_confirm: true,
        });
        if (cErr || !created.user) return err(cErr?.message ?? "createUser failed", 400);

        const username = usernameFromEmail(email);
        const { error: pErr } = await admin.from("user_profiles").upsert(
          {
            id: created.user.id,
            username,
            full_name: String(body.full_name ?? ""),
            account_kind: "farmer",
            app_role: "end_user",
            registration_status: String(body.registration_status ?? "pending"),
            access_tier: body.access_tier ? String(body.access_tier) : null,
            updated_at: new Date().toISOString(),
          },
          { onConflict: "id" },
        );
        if (pErr) {
          await admin.auth.admin.deleteUser(created.user.id);
          return err(pErr.message, 500);
        }
        return json({ success: true, user_id: created.user.id });
      }

      case "revoke_staff_access": {
        if (!isSuper(callerProfile)) return err("Super admin only", 403);
        const target_user_id = String(body.target_user_id ?? "");
        if (!target_user_id) return err("target_user_id required");
        if (target_user_id === user.id) return err("Cannot revoke yourself", 400);
        const { error: uErr } = await admin
          .from("user_profiles")
          .update({
            account_kind: "farmer",
            app_role: "end_user",
            updated_at: new Date().toISOString(),
          })
          .eq("id", target_user_id);
        if (uErr) return err(uErr.message, 500);
        return json({ success: true });
      }

      case "update_user_password": {
        const target_user_id = String(body.target_user_id ?? "");
        const new_password = String(body.new_password ?? "");
        if (!target_user_id || !new_password) return err("target_user_id and new_password required");
        if (new_password.length < 8) return err("password min 8 chars");

        const target = await loadProfile(admin, target_user_id);
        if (!target) return err("Target profile not found", 404);

        if (isSuper(callerProfile)) {
        } else if (isAdminPlus(callerProfile)) {
          if (target.account_kind === "staff") return err("Only super admin can reset staff passwords", 403);
        } else {
          return err("Forbidden", 403);
        }

        const { error: uErr } = await admin.auth.admin.updateUserById(target_user_id, {
          password: new_password,
        });
        if (uErr) return err(uErr.message, 500);
        return json({ success: true });
      }

      case "delete_auth_user": {
        const target_user_id = String(body.target_user_id ?? "");
        if (!target_user_id) return err("target_user_id required");
        if (target_user_id === user.id) return err("Cannot delete yourself here", 400);

        const target = await loadProfile(admin, target_user_id);
        if (!target) return err("Target profile not found", 404);

        if (isSuper(callerProfile)) {
        } else if (isAdminPlus(callerProfile)) {
          if (target.account_kind === "staff") return err("Only super admin can delete staff accounts", 403);
        } else {
          return err("Forbidden", 403);
        }

        await purgeUserData(admin, target_user_id);
        const { error: dErr } = await admin.auth.admin.deleteUser(target_user_id);
        if (dErr) return err(dErr.message, 500);
        return json({ success: true });
      }

      case "multi_table_export": {
        if (!isSuper(callerProfile)) return err("Super admin only", 403);
        const limit = Math.min(Number(body.limit ?? 2000), 5000);
        const tables = [
          "user_profiles",
          "events",
          "event_registrations",
          "knowledge_repository_documents",
          "workshop_documents",
          "goal_documents",
          "broadcast_campaigns",
          "audit_logs",
        ] as const;
        const out: Record<string, unknown[]> = {};
        const exportErrors: Record<string, string> = {};
        for (const t of tables) {
          const { data, error } = await admin.from(t).select("*").limit(limit);
          if (error) {
            exportErrors[t] = error.message;
            out[t] = [];
          } else {
            out[t] = data ?? [];
          }
        }
        return json({
          success: true,
          data: out,
          errors: exportErrors,
          exported_at: new Date().toISOString(),
        });
      }

      default:
        return err("Unknown action", 400);
    }
  } catch (e) {
    return err(String(e), 500);
  }
});

function createServiceClient(url: string, serviceKey: string) {
  return createClient(url, serviceKey, { auth: { persistSession: false } });
}
