export type ResourceScope = "workshop" | "repository";

export type ResourceFolder = {
  id: string;
  scope: ResourceScope;
  name: string;
  description: string | null;
  sort_order: number;
  legacy_workshop_id: string | null;
  created_by: string | null;
  created_at: string;
};

export const RESOURCE_FOLDER_SELECT =
  "id, scope, name, description, sort_order, legacy_workshop_id, created_by, created_at";

export function buildResourceStoragePath(folderId: string, userId: string, fileName: string): string {
  const safeName = fileName.replaceAll("/", "_");
  return `${folderId}/${userId}/${Date.now()}_${safeName}`;
}
