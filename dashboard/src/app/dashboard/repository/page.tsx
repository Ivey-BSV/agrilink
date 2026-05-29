"use client";

import { motion } from "framer-motion";
import { useEffect, useMemo, useState } from "react";
import { supabase } from "@/lib/supabase";
import { formatDate } from "@/lib/format";
import { extractStoragePathFromPublicUrl } from "@/lib/storage";
import { getEffectiveStaffAccess, isModeratorPlusEffective, type EffectiveStaffAccess } from "@/lib/staff-profile";
import { splitGalleryAndDocuments, isGalleryImageFile } from "@/lib/file-browse-layout";
import { FileBrowseGalleryDocumentsTabs } from "@/components/file-browse-gallery-documents-tabs";
import { FileGalleryGrid } from "@/components/file-gallery-grid";
import { FileRowThumb } from "@/components/file-row-thumb";
import { MotionListItem } from "@/components/motion-list";
import { PageSectionHeader } from "@/components/page-section-header";
import { fetchUploaderLabelByUserIds } from "@/lib/document-owner-profiles";

type RepoDocRow = {
  id: string;
  user_id: string;
  title: string;
  file_name: string;
  file_url: string;
  mime_type?: string | null;
  created_at: string;
  approval_status?: string | null;
  visibility_rules?: Record<string, unknown> | null;
};

type SortKey = "created_desc" | "created_asc" | "title_asc" | "title_desc";

const REPOSITORY_LIST_SELECT =
  "id, user_id, title, file_name, file_url, mime_type, created_at, approval_status, visibility_rules";

export default function RepositoryFilesPage() {
  const [items, setItems] = useState<RepoDocRow[]>([]);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [draftTitle, setDraftTitle] = useState("");
  const [uploadTitle, setUploadTitle] = useState("");
  const [uploadFiles, setUploadFiles] = useState<File[]>([]);
  const [uploading, setUploading] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [staffAccess, setStaffAccess] = useState<EffectiveStaffAccess | null>(null);
  const [accessResolved, setAccessResolved] = useState(false);
  const [currentUserId, setCurrentUserId] = useState<string | null>(null);
  const [uploaderLabels, setUploaderLabels] = useState<Record<string, string>>({});

  const [sortKey, setSortKey] = useState<SortKey>("created_desc");
  const [approvalFilter, setApprovalFilter] = useState<string>("all");
  const [ownerFilter, setOwnerFilter] = useState<"all" | "mine">("all");
  const [search, setSearch] = useState("");

  const isStaff = isModeratorPlusEffective(staffAccess);
  const heading =
    !accessResolved || isStaff ? "Repository Files" : "My Repository Files";
  const repositoryInfo = isStaff
    ? "Shared reference files live in a gallery for images and a document list for everything else. Filter by approval, owner, or filename when you are curating what the cohort can see."
    : "Store guides, PDFs, and reference images for your farm or cohort. The gallery highlights pictures; longer documents sit in the list below with preview and open-in-new-tab where supported.";

  useEffect(() => {
    let cancelled = false;
    const boot = async () => {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) {
        if (!cancelled) {
          setError("Not signed in.");
          setLoading(false);
        }
        return;
      }
      if (!cancelled) setCurrentUserId(user.id);
      const access = await getEffectiveStaffAccess(user.id, user.email);
      if (cancelled) return;
      setStaffAccess(access);
      setAccessResolved(true);

      let q = supabase
        .from("knowledge_repository_documents")
        .select(REPOSITORY_LIST_SELECT)
        .order("created_at", { ascending: false });
      if (!isModeratorPlusEffective(access)) {
        q = q.eq("user_id", user.id);
      } else {
        q = q.limit(400);
      }
      const { data, error: fetchError } = await q;
      if (cancelled) return;
      if (fetchError) setError(fetchError.message);
      setItems((data as RepoDocRow[]) || []);
      setLoading(false);
    };
    void boot();
    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    const ids = items.map((i) => i.user_id);
    if (ids.length === 0) return;
    let cancelled = false;
    void (async () => {
      const labels = await fetchUploaderLabelByUserIds(supabase, ids);
      if (!cancelled) setUploaderLabels((prev) => ({ ...prev, ...labels }));
    })();
    return () => {
      cancelled = true;
    };
  }, [items]);

  const visibleItems = useMemo(() => {
    let out = [...items];

    if (isStaff && ownerFilter === "mine" && currentUserId) {
      out = out.filter((r) => r.user_id === currentUserId);
    }

    if (isStaff && approvalFilter !== "all") {
      out = out.filter((r) => {
        const raw = (r.approval_status ?? "").trim().toLowerCase();
        const norm = raw === "" ? "pending" : raw;
        return norm === approvalFilter;
      });
    }

    const q = search.trim().toLowerCase();
    if (q) {
      out = out.filter(
        (r) => r.title.toLowerCase().includes(q) || r.file_name.toLowerCase().includes(q)
      );
    }

    const byCreated = (a: RepoDocRow, b: RepoDocRow) =>
      new Date(a.created_at).getTime() - new Date(b.created_at).getTime();
    const byTitle = (a: RepoDocRow, b: RepoDocRow) => a.title.localeCompare(b.title, undefined, { sensitivity: "base" });

    out.sort((a, b) => {
      switch (sortKey) {
        case "created_asc":
          return byCreated(a, b);
        case "created_desc":
          return byCreated(b, a);
        case "title_asc":
          return byTitle(a, b);
        case "title_desc":
          return byTitle(b, a);
        default:
          return 0;
      }
    });

    return out;
  }, [items, sortKey, approvalFilter, search, isStaff, ownerFilter, currentUserId]);

  const { gallery: galleryFromFilter, documents: documentFromFilter } = useMemo(
    () => splitGalleryAndDocuments(visibleItems),
    [visibleItems]
  );

  const editingItem = editingId ? visibleItems.find((i) => i.id === editingId) ?? null : null;
  const editingIsGallery =
    editingItem != null &&
    isGalleryImageFile(
      editingItem.file_name,
      editingItem.mime_type,
      editingItem.file_url,
      editingItem.title
    );

  const galleryItems = useMemo(
    () => (editingIsGallery ? galleryFromFilter.filter((g) => g.id !== editingId) : galleryFromFilter),
    [galleryFromFilter, editingIsGallery, editingId]
  );

  const documentListItems = useMemo(() => {
    const d = [...documentFromFilter];
    if (editingIsGallery && editingItem) d.unshift(editingItem);
    return d;
  }, [documentFromFilter, editingIsGallery, editingItem]);

  const upload = async () => {
    setError(null);
    setSuccess(null);
    if (!uploadTitle.trim()) {
      setError("Please enter a title for the file.");
      return;
    }
    if (uploadFiles.length === 0) {
      setError("Please choose one or more files to upload.");
      return;
    }

    setUploading(true);
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      setError("Not signed in.");
      setUploading(false);
      return;
    }

    const access = await getEffectiveStaffAccess(user.id, user.email);
    const staff = isModeratorPlusEffective(access);

    const uploadedRows: RepoDocRow[] = [];
    for (const file of uploadFiles) {
      const safeName = file.name.replaceAll("/", "_");
      const filePath = `${user.id}/${Date.now()}_${safeName}`;

      const { error: storageError } = await supabase.storage
        .from("knowledge-repository")
        .upload(filePath, file, {
          cacheControl: "3600",
          upsert: false,
          contentType: file.type || "application/octet-stream",
        });

      if (storageError) {
        setError(storageError.message);
        setUploading(false);
        return;
      }

      const publicUrl = supabase.storage.from("knowledge-repository").getPublicUrl(filePath).data.publicUrl;

      const { data: inserted, error: insertError } = await supabase
        .from("knowledge_repository_documents")
        .insert({
          user_id: user.id,
          title: uploadFiles.length > 1 ? `${uploadTitle.trim()} - ${file.name}` : uploadTitle.trim(),
          file_name: file.name,
          file_url: publicUrl,
          mime_type: file.type || null,
          approval_status: staff ? "approved" : "pending",
          visibility_rules: {},
        })
        .select(REPOSITORY_LIST_SELECT)
        .single();

      if (insertError) {
        setError(insertError.message);
        setUploading(false);
        return;
      }
      uploadedRows.push(inserted as RepoDocRow);
    }

    setItems((prev) => [...uploadedRows, ...prev]);
    setUploadTitle("");
    setUploadFiles([]);
    setSuccess(
      uploadedRows.length === 1
        ? staff
          ? "Repository file uploaded (approved)."
          : "Upload queued for admin review."
        : `${uploadedRows.length} repository files uploaded.`
    );
    setUploading(false);
  };

  const remove = async (id: string) => {
    if (!confirm("Delete this repository file?")) return;
    const row = items.find((i) => i.id === id);
    if (row) {
      const storagePath = extractStoragePathFromPublicUrl(row.file_url, "knowledge-repository");
      if (storagePath) {
        await supabase.storage.from("knowledge-repository").remove([storagePath]);
      }
    }
    const { error: deleteError } = await supabase.from("knowledge_repository_documents").delete().eq("id", id);
    if (deleteError) {
      setError(deleteError.message);
      return;
    }
    setItems((prev) => prev.filter((p) => p.id !== id));
  };

  const startEdit = (row: RepoDocRow) => {
    setEditingId(row.id);
    setDraftTitle(row.title);
  };

  const saveEdit = async (id: string) => {
    const { error: updateError } = await supabase
      .from("knowledge_repository_documents")
      .update({ title: draftTitle })
      .eq("id", id);
    if (updateError) {
      setError(updateError.message);
      return;
    }
    setItems((prev) => prev.map((p) => (p.id === id ? { ...p, title: draftTitle } : p)));
    setEditingId(null);
  };

  const setApproval = async (row: RepoDocRow, approval_status: string) => {
    setError(null);
    const {
      data: { user },
    } = await supabase.auth.getUser();
    const { error: uErr } = await supabase
      .from("knowledge_repository_documents")
      .update({
        approval_status,
        reviewed_by: user?.id ?? null,
        reviewed_at: new Date().toISOString(),
      })
      .eq("id", row.id);
    if (uErr) setError(uErr.message);
    else setItems((prev) => prev.map((p) => (p.id === row.id ? { ...p, approval_status } : p)));
  };

  return (
    <motion.div
      className="content-card stack"
      initial={{ opacity: 0, y: 6 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.2 }}
    >
      <PageSectionHeader
        title={heading}
        description={repositoryInfo}
        action={
          <button
            type="submit"
            form="repo-upload-form"
            className="btn btn-primary btn-primary-compact"
            disabled={uploading}
          >
            {uploading ? "Uploading…" : "Upload file"}
          </button>
        }
      />
      {error ? <p className="error">{error}</p> : null}
      {success ? <p className="success">{success}</p> : null}

      <div className="list-item">
        <form
          id="repo-upload-form"
          className="stack"
          style={{ width: "100%" }}
          onSubmit={(e) => {
            e.preventDefault();
            void upload();
          }}
        >
          <div style={{ fontWeight: 600 }}>Upload repository file</div>
          <div className="field">
            <label>Title</label>
            <input
              value={uploadTitle}
              onChange={(e) => setUploadTitle(e.target.value)}
              placeholder="e.g., Community reference guide"
            />
          </div>
          <div className="field">
            <label>File</label>
            <input type="file" multiple onChange={(e) => setUploadFiles(Array.from(e.target.files ?? []))} />
          </div>
        </form>
      </div>

      {!loading && items.length > 0 ? (
        <div className="list-item stack" style={{ gap: 14 }}>
          <div style={{ fontWeight: 600 }}>Browse uploads (gallery &amp; documents)</div>
          <div className="workshop-toolbar">
            <div className="field">
              <label htmlFor="repo-sort">Sort</label>
              <select id="repo-sort" value={sortKey} onChange={(e) => setSortKey(e.target.value as SortKey)}>
                <option value="created_desc">Newest first</option>
                <option value="created_asc">Oldest first</option>
                <option value="title_asc">Title A–Z</option>
                <option value="title_desc">Title Z–A</option>
              </select>
            </div>
            {isStaff ? (
              <>
                <div className="field">
                  <label htmlFor="repo-approval">Approval</label>
                  <select id="repo-approval" value={approvalFilter} onChange={(e) => setApprovalFilter(e.target.value)}>
                    <option value="all">All statuses</option>
                    <option value="pending">Pending</option>
                    <option value="approved">Approved</option>
                    <option value="rejected">Rejected</option>
                  </select>
                </div>
                <div className="field">
                  <label htmlFor="repo-owner">Uploader</label>
                  <select
                    id="repo-owner"
                    value={ownerFilter}
                    onChange={(e) => setOwnerFilter(e.target.value as "all" | "mine")}
                  >
                    <option value="all">Everyone</option>
                    <option value="mine">My uploads only</option>
                  </select>
                </div>
              </>
            ) : null}
            <div className="field" style={{ flex: "2 1 220px", minWidth: "200px" }}>
              <label htmlFor="repo-search">Search</label>
              <input
                id="repo-search"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder="Title or file name…"
                autoComplete="off"
              />
            </div>
            <div className="workshop-toolbar-meta">
              Showing {visibleItems.length} of {items.length}
            </div>
          </div>
        </div>
      ) : null}

      {loading ? <p className="subtle">Loading repository files…</p> : null}
      {!loading && items.length === 0 ? <p className="empty">No repository files uploaded yet.</p> : null}
      {!loading && items.length > 0 && visibleItems.length === 0 ? (
        <p className="empty">No files match your filters. Try clearing search or widening approval / uploader scope.</p>
      ) : null}

      {!loading && visibleItems.length > 0 ? (
        <FileBrowseGalleryDocumentsTabs
          galleryCount={galleryFromFilter.length}
          documentCount={documentListItems.length}
          preferDocumentsTab={editingIsGallery}
          tabListAriaLabel="Repository gallery and documents"
          galleryDescription="Image files — scroll the grid and click a tile for a larger preview."
          documentsDescription="PDFs, spreadsheets, text, video, audio, and other files — same row actions as before."
          galleryPanel={
            galleryItems.length === 0 && !editingIsGallery ? (
              <p className="empty subtle">No image files in this view.</p>
            ) : (
              <FileGalleryGrid
                items={galleryItems}
                renderFooter={(item) => (
                  <>
                    <a href={item.file_url} target="_blank" rel="noreferrer" className="pill">
                      Open
                    </a>
                    <button type="button" className="btn btn-secondary" onClick={() => startEdit(item)}>
                      Edit
                    </button>
                    {isStaff ? (
                      <>
                        <button type="button" className="btn btn-secondary" onClick={() => void setApproval(item, "approved")}>
                          Approve
                        </button>
                        <button type="button" className="btn btn-secondary" onClick={() => void setApproval(item, "rejected")}>
                          Reject
                        </button>
                      </>
                    ) : null}
                    <button type="button" className="btn btn-danger" onClick={() => void remove(item.id)}>
                      Delete
                    </button>
                  </>
                )}
              />
            )
          }
          documentsPanel={
            documentListItems.length === 0 ? (
              <p className="empty subtle">No document-type files in this view.</p>
            ) : (
              <div className="list">
                {documentListItems.map((item, index) => (
                  <MotionListItem key={item.id} index={index} className="list-item file-list-row">
                    <FileRowThumb
                      fileUrl={item.file_url}
                      fileName={item.file_name}
                      mimeType={item.mime_type}
                      editing={editingId === item.id}
                    />
                    <div className="stack workshop-file-body" style={{ gap: 6 }}>
                      {editingId === item.id ? (
                        <>
                          <div className="field">
                            <label>Title</label>
                            <input value={draftTitle} onChange={(e) => setDraftTitle(e.target.value)} />
                          </div>
                        </>
                      ) : (
                        <>
                          <div className="workshop-line-title">{item.title}</div>
                          {isStaff ? (
                            <div className="workshop-line-meta">
                              Owner {uploaderLabels[item.user_id] ?? "…"} ·{" "}
                              {item.approval_status?.trim() ? item.approval_status : "pending"}
                            </div>
                          ) : null}
                          <div className="workshop-line-meta">{item.file_name}</div>
                          <div className="workshop-line-meta">Uploaded {formatDate(item.created_at)}</div>
                          <a href={item.file_url} target="_blank" rel="noreferrer" className="pill">
                            Open file
                          </a>
                        </>
                      )}
                    </div>
                    <div className="actions">
                      {editingId === item.id ? (
                        <>
                          <button type="button" className="btn btn-primary" onClick={() => void saveEdit(item.id)}>
                            Save
                          </button>
                          <button type="button" className="btn btn-secondary" onClick={() => setEditingId(null)}>
                            Cancel
                          </button>
                        </>
                      ) : (
                        <>
                          <button type="button" className="btn btn-secondary" onClick={() => startEdit(item)}>
                            Edit
                          </button>
                          {isStaff ? (
                            <>
                              <button
                                type="button"
                                className="btn btn-secondary"
                                onClick={() => void setApproval(item, "approved")}
                              >
                                Approve
                              </button>
                              <button
                                type="button"
                                className="btn btn-secondary"
                                onClick={() => void setApproval(item, "rejected")}
                              >
                                Reject
                              </button>
                            </>
                          ) : null}
                          <button type="button" className="btn btn-danger" onClick={() => void remove(item.id)}>
                            Delete
                          </button>
                        </>
                      )}
                    </div>
                  </MotionListItem>
                ))}
              </div>
            )
          }
        />
      ) : null}
    </motion.div>
  );
}
