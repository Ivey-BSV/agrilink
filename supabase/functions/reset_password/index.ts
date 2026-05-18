import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const RESET_CODE = "1234";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const jsonHeaders = { ...corsHeaders, "Content-Type": "application/json" };

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: jsonHeaders,
    });
  }

  try {
    const body = await req.json();
    const { code, new_password } = body;
    let email = body.email ?? body.usernameOrEmail ?? "";
    if (!email || !code || !new_password) {
      return new Response(JSON.stringify({ error: "Missing email/username, code, or new_password" }), {
        status: 400,
        headers: jsonHeaders,
      });
    }
    if (code !== RESET_CODE) {
      return new Response(JSON.stringify({ error: "Invalid code" }), {
        status: 400,
        headers: jsonHeaders,
      });
    }
    if (new_password.length < 6) {
      return new Response(JSON.stringify({ error: "Password must be at least 6 characters" }), {
        status: 400,
        headers: jsonHeaders,
      });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false },
    });

    if (!email.includes("@")) {
      try {
        const { data: rpcEmail } = await supabaseAdmin.rpc("get_email_by_username", {
          username_param: String(email).toLowerCase(),
        });
        if (rpcEmail && String(rpcEmail).length > 0) email = String(rpcEmail);
      } catch (_) {}
    }

    const {
      data: { users },
      error: listError,
    } = await supabaseAdmin.auth.admin.listUsers({ perPage: 1000 });
    if (listError) {
      return new Response(JSON.stringify({ error: "List users: " + listError.message }), {
        status: 500,
        headers: jsonHeaders,
      });
    }
    const user = users?.find(
      (u: { email?: string }) =>
        u.email?.toLowerCase() === String(email).toLowerCase()
    );
    if (!user) {
      return new Response(JSON.stringify({ error: "No account found for that email or username" }), {
        status: 404,
        headers: jsonHeaders,
      });
    }

    const { error: updateError } = await supabaseAdmin.auth.admin.updateUserById(
      user.id,
      { password: new_password }
    );
    if (updateError) {
      return new Response(JSON.stringify({ error: "Update failed: " + updateError.message }), {
        status: 500,
        headers: jsonHeaders,
      });
    }

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: jsonHeaders,
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: jsonHeaders,
    });
  }
});
