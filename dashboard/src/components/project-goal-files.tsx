"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { supabase } from "@/lib/supabase";
import { formatDate } from "@/lib/format";
import { extractStoragePathFromPublicUrl } from "@/lib/storage";
import { splitGalleryAndDocuments } from "@/lib/file-browse-layout";
import { FileBrowseGalleryDocumentsTabs } from "@/components/file-browse-gallery-documents-tabs";
import { FileGalleryGrid } from "@/components/file-gallery-grid";
import { FileRowThumb } from "@/components/file-row-thumb";
import { MotionListItem } from "@/components/motion-list";
import { getEffectiveStaffAccess, isModeratorPlusEffective, type EffectiveStaffAccess } from "@/lib/staff-profile";

const MAX_BYTES = 50 * 1024 * 1024;

type GoalDocRow = {
  id: string;
  goal_id: string;
  user_id: string;
  title: string;
  file_name: string;
  file_url: string;
  mime_type?: string | null;
  created_at: string;
  approval_status?: string | null;
  _profile?: { full_name?: string | null; username?: string | null };
};

function contributorLabel(row: GoalDocRow): string {
  const p = row._profile;
  if (p) {
    const n = p.full_name?.trim();
    if (n) return n;
    const u = p.username?.trim();
    if (u) return `@${u}`;
  }
  return "Member";
}

export function ProjectGoalFiles({
  goalId,
  canUpload,
  completed,
}: {
  goalId: string;
  canUpload: boolean;
  completed?: boolean;
}) {
  const [rows, setRows] = useState<GoalDocRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [uploadTitle, setUploadTitle] = useState("");
  const [uploadFiles, setUploadFiles] = useState<File[]>([]);
  const [uploading, setUploading] = useState(false);
  const [staffAccess, setStaffAccess] = useState<EffectiveStaffAccess | null>(null);
  const [currentUserId, setCurrentUserId] = useState<string | null>(null);

  const isStaff = isModeratorPlusEffective(staffAccess);
  const allowUpload = canUpload && !completed;

  const load = useCallback(async () => {
    if (!goalId) return;
    setLoading(true);
    setError(null);
    try {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      setCurrentUserId(user?.id ?? null);
      const access = user ? await getEffectiveStaffAccess(user.id, user.email ?? undefined) : null;
      setStaffAccess(access);

      const { data, error: fetchError } = await supabase
        .from("goal_documents")
        .select("id, goal_id, user_id, title, file_name, file_url, mime_type, created_at, approval_status")
        .eq("goal_id", goalId)
        .order("created_at", { ascending: false });

      if (fetchError) {
        setError(fetchError.message);
        setRows([]);
        return;
      }

      const raw = (data as GoalDocRow[]) ?? [];
      const ids = [...new Set(raw.map((r) => r.user_id))];
      const profileById: Record<string, { full_name?: string | null; username?: string | null }> = {};
      if (ids.length > 0) {
        const { data: profs } = await supabase.from("user_profiles").select("id, full_name, username").in("id", ids);
        for (const p of (profs as { id: string; full_name?: string | null; username?: string | null }[]) ?? []) {
          profileById[p.id] = { full_name: p.full_name, username: p.username };
        }
      }
      for (const r of raw) {
        r._profile = profileById[r.user_id];
      }
      setRows(raw);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
      setRows([]);
    } finally {
      setLoading(false);
    }
  }, [goalId]);

  useEffect(() => {
    void load();
  }, [load]);

  const { gallery, documents } = useMemo(() => splitGalleryAndDocuments(rows), [rows]);

  const canDeleteRow = (row: GoalDocRow) =>
    currentUserId != null && (row.user_id === currentUserId || isStaff);

  const upload = async () => {
    setError(null);
    setSuccess(null);
    if (!allowUpload) {
      setError("You can’t upload to this project.");
      return;
    }
    if (!uploadTitle.trim()) {
      setError("Enter a title for the file.");
      return;
    }
    if (uploadFiles.length === 0) {
      setError("Choose one or more files.");
      return;
    }

    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      setError("Not signed in.");
      return;
    }

    for (const file of uploadFiles) {
      if (file.size > MAX_BYTES) {
        setError("Each file must be 50 MB or smaller.");
        return;
      }
    }

    setUploading(true);
    const access = await getEffectiveStaffAccess(user.id, user.email ?? undefined);
    const staff = isModeratorPlusEffective(access);

    const uploaded: GoalDocRow[] = [];
    try {
      for (const file of uploadFiles) {
        const safeName = file.name.replaceAll("/", "_");
        const filePath = `${goalId}/${user.id}/${Date.now()}_${safeName}`;

        const { error: storageError } = await supabase.storage.from("goal-repository").upload(filePath, file, {
          cacheControl: "3600",
          upsert: false,
          contentType: file.type || "application/octet-stream",
        });
        if (storageError) {
          setError(storageError.message);
          setUploading(false);
          return;
        }

        const publicUrl = supabase.storage.from("goal-repository").getPublicUrl(filePath).data.publicUrl;

        const { data: inserted, error: insertError } = await supabase
          .from("goal_documents")
          .insert({
            goal_id: goalId,
            user_id: user.id,
            title: uploadFiles.length > 1 ? `${uploadTitle.trim()} — ${file.name}` : uploadTitle.trim(),
            file_name: file.name,
            file_url: publicUrl,
            mime_type: file.type || null,
            approval_status: staff ? "approved" : "pending",
            consent_agreed_at: staff ? null : new Date().toISOString(),
            visibility_rules: {},
          })
          .select("id, goal_id, user_id, title, file_name, file_url, mime_type, created_at, approval_status")
          .single();

        if (insertError) {
          setError(insertError.message);
          setUploading(false);
          return;
        }
        uploaded.push(inserted as GoalDocRow);
      }

      const { data: me } = await supabase.from("user_profiles").select("full_name, username").eq("id", user.id).maybeSingle();
      if (me) {
        const prof = me as { full_name?: string | null; username?: string | null };
        for (const row of uploaded) {
          row._profile = { full_name: prof.full_name, username: prof.username };
        }
      }

      setRows((prev) => [...uploaded, ...prev]);
      setUploadTitle("");
      setUploadFiles([]);
      setSuccess(
        uploaded.length === 1
          ? staff
            ? "File uploaded."
            : "Upload submitted; staff may review before it’s fully published."
          : `${uploaded.length} files uploaded.`
      );
    } finally {
      setUploading(false);
    }
  };

  const remove = async (id: string) => {
    if (!confirm("Remove this file from the project?")) return;
    const row = rows.find((r) => r.id === id);
    if (!row) return;
    if (!canDeleteRow(row)) {
      setError("You can’t delete this file.");
      return;
    }
    const storagePath = extractStoragePathFromPublicUrl(row.file_url, "goal-repository");
    if (storagePath) {
      await supabase.storage.from("goal-repository").remove([storagePath]);
    }
    const { error: deleteError } = await supabase.from("goal_documents").delete().eq("id", id);
    if (deleteError) {
      setError(deleteError.message);
      return;
    }
    setRows((prev) => prev.filter((p) => p.id !== id));
    setSuccess("File removed.");
  };

  const setApproval = async (id: string, status: "approved" | "rejected") => {
    if (!isStaff) return;
    const { error: uErr } = await supabase.from("goal_documents").update({ approval_status: status }).eq("id", id);
    if (uErr) {
      setError(uErr.message);
      return;
    }
    setRows((prev) => prev.map((r) => (r.id === id ? { ...r, approval_status: status } : r)));
    setSuccess(status === "approved" ? "Marked approved." : "Marked rejected.");
  };

  return (
    <div className="content-card stack" style={{ gap: 14 }}>
      <h3 className="section-title" style={{ fontSize: "1.1rem", margin: 0 }}>
        Project files
      </h3>
      <p className="subtle" style={{ margin: 0 }}>
        {allowUpload
          ? "Photos and documents you upload here match the mobile app (same gallery and documents tabs)."
          : "Files shared by the project owner and joined members. Join the community project (or open your own farm project) to upload."}
      </p>

      {error ? (
        <p className="subtle" style={{ color: "var(--danger, #b91c1c)" }}>
          {error}
        </p>
      ) : null}
      {success ? (
        <p className="subtle" style={{ color: "var(--ok, #15803d)" }}>
          {success}
        </p>
      ) : null}

      {allowUpload ? (
        <div className="workshop-toolbar" style={{ flexWrap: "wrap" }}>
          <div className="field" style={{ flex: "2 1 200px", minWidth: "180px" }}>
            <label htmlFor={`goal-file-title-${goalId}`}>Title</label>
            <input
              id={`goal-file-title-${goalId}`}
              value={uploadTitle}
              onChange={(e) => setUploadTitle(e.target.value)}
              placeholder="e.g. Soil test results"
              autoComplete="off"
            />
          </div>
          <div className="field">
            <label htmlFor={`goal-file-input-${goalId}`}>File</label>
            <input
              id={`goal-file-input-${goalId}`}
              type="file"
              multiple
              onChange={(e) => setUploadFiles(Array.from(e.target.files ?? []))}
            />
          </div>
          <div style={{ alignSelf: "flex-end" }}>
            <button type="button" className="btn btn-primary" onClick={() => void upload()} disabled={uploading}>
              {uploading ? "Uploading…" : "Upload"}
            </button>
          </div>
        </div>
      ) : null}

      {loading ? <p className="subtle">Loading files…</p> : null}
      {!loading && rows.length === 0 ? <p className="empty subtle">No files shared on this project yet.</p> : null}

      {!loading && rows.length > 0 ? (
        <FileBrowseGalleryDocumentsTabs
          galleryCount={gallery.length}
          documentCount={documents.length}
          tabListAriaLabel="Project gallery and documents"
          galleryDescription="Image uploads — click a tile for a larger preview."
          documentsDescription="PDFs, slides, and other files — open or remove from the row actions."
          galleryPanel={
            gallery.length === 0 ? (
              <p className="empty subtle">No image files yet.</p>
            ) : (
              <FileGalleryGrid
                items={gallery}
                subtitle={(item) => contributorLabel(item as GoalDocRow)}
                renderFooter={(item) => {
                  const r = item as GoalDocRow;
                  return (
                    <>
                      <a href={r.file_url} target="_blank" rel="noreferrer" className="pill">
                        Open
                      </a>
                      {isStaff ? (
                        <>
                          <button type="button" className="btn btn-secondary" onClick={() => void setApproval(r.id, "approved")}>
                            Approve
                          </button>
                          <button type="button" className="btn btn-secondary" onClick={() => void setApproval(r.id, "rejected")}>
                            Reject
                          </button>
                        </>
                      ) : null}
                      {canDeleteRow(r) ? (
                        <button type="button" className="btn btn-danger" onClick={() => void remove(r.id)}>
                          Delete
                        </button>
                      ) : null}
                    </>
                  );
                }}
              />
            )
          }
          documentsPanel={
            documents.length === 0 ? (
              <p className="empty subtle">No document-type files in this view.</p>
            ) : (
              <div className="list">
                {documents.map((item, index) => (
                  <MotionListItem key={item.id} index={index} className="list-item file-list-row">
                    <FileRowThumb fileUrl={item.file_url} fileName={item.file_name} mimeType={item.mime_type} editing={false} />
                    <div className="stack workshop-file-body" style={{ gap: 6 }}>
                      <div className="workshop-line-title">{item.title}</div>
                      <div className="workshop-line-meta">
                        {contributorLabel(item)} · {formatDate(item.created_at)}
                      </div>
                      {isStaff ? (
                        <div className="workshop-line-meta">
                          Status: {item.approval_status ?? "pending"}
                        </div>
                      ) : null}
                      <div className="workshop-line-meta">{item.file_name}</div>
                      <a href={item.file_url} target="_blank" rel="noreferrer" className="pill">
                        Open file
                      </a>
                    </div>
                    <div className="actions">
                      {isStaff ? (
                        <>
                          <button type="button" className="btn btn-secondary" onClick={() => void setApproval(item.id, "approved")}>
                            Approve
                          </button>
                          <button type="button" className="btn btn-secondary" onClick={() => void setApproval(item.id, "rejected")}>
                            Reject
                          </button>
                        </>
                      ) : null}
                      {canDeleteRow(item) ? (
                        <button type="button" className="btn btn-danger" onClick={() => void remove(item.id)}>
                          Delete
                        </button>
                      ) : null}
                    </div>
                  </MotionListItem>
                ))}
              </div>
            )
          }
        />
      ) : null}
    </div>
  );
}
