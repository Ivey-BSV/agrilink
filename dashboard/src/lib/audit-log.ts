import type { SupabaseClient } from "@supabase/supabase-js";

export async function insertAuditLog(
  client: SupabaseClient,
  row: {
    actorId: string;
    action: string;
    entityType: string;
    entityId?: string | null;
    metadata?: Record<string, unknown>;
  },
) {
  const { error } = await client.from("audit_logs").insert({
    actor_id: row.actorId,
    action: row.action,
    entity_type: row.entityType,
    entity_id: row.entityId ?? null,
    metadata: row.metadata ?? {},
  });
  return error;
}
