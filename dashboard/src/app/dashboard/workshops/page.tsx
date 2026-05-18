"use client";

import { motion } from "framer-motion";
import { useEffect, useMemo, useState } from "react";
import { supabase } from "@/lib/supabase";
import { formatDate } from "@/lib/format";
import { extractStoragePathFromPublicUrl } from "@/lib/storage";
import { getEffectiveStaffAccess, isModeratorPlusEffective, type EffectiveStaffAccess } from "@/lib/staff-profile";
import { WORKSHOP_OPTIONS, workshopShortLabel } from "@/lib/workshops";
import { splitGalleryAndDocuments, isGalleryImageFile } from "@/lib/file-browse-layout";
import { FileBrowseGalleryDocumentsTabs } from "@/components/file-browse-gallery-documents-tabs";
import { FileGalleryGrid } from "@/components/file-gallery-grid";
import { FileRowThumb } from "@/components/file-row-thumb";
import { MotionListItem } from "@/components/motion-list";
import { fetchUploaderLabelByUserIds } from "@/lib/document-owner-profiles";

type WorkshopDocRow = {
  id: string;
  workshop_id: string;
  user_id: string;
  title: string;
  file_name: string;
  file_url: string;
  mime_type?: string | null;
  created_at: string;
  approval_status?: string | null;
  visibility_rules?: Record<string, unknown> | null;
};

type SortKey = "created_desc" | "created_asc" | "title_asc" | "title_desc" | "workshop_then_date";

function compareWorkshopId(a: string, b: string): number {
  const na = Number.parseInt(a, 10);
  const nb = Number.parseInt(b, 10);
  if (!Number.isNaN(na) && !Number.isNaN(nb)) return na - nb;
  return a.localeCompare(b);
}

export default function WorkshopsFilesPage() {
  const [items, setItems] = useState<WorkshopDocRow[]>([]);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [draftTitle, setDraftTitle] = useState("");
  const [uploadTitle, setUploadTitle] = useState("");
  const [uploadWorkshopId, setUploadWorkshopId] = useState("1");
  const [uploadFiles, setUploadFiles] = useState<File[]>([]);
  const [uploading, setUploading] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [staffAccess, setStaffAccess] = useState<EffectiveStaffAccess | null>(null);
  const [accessResolved, setAccessResolved] = useState(false);
  const [uploaderLabels, setUploaderLabels] = useState<Record<string, string>>({});

  const [filterWorkshop, setFilterWorkshop] = useState<string>("all");
  const [sortKey, setSortKey] = useState<SortKey>("created_desc");
  const [approvalFilter, setApprovalFilter] = useState<string>("all");
  const [search, setSearch] = useState("");

  const isStaff = isModeratorPlusEffective(staffAccess);
  const heading = !accessResolved || isStaff ? "Workshop Files" : "My Workshop Files";
  const introCopy = !accessResolved
    ? "Loading workshop materials…"
    : isStaff
      ? "Workshop materials are split into a photo gallery for visuals and a document list for PDFs, slides, and other files. Use filters, approvals, and search to review what members have uploaded."
      : "Upload handouts and photos from your workshops. Images appear in the gallery; PDFs and other files stay in the document list. Click a row or thumbnail to preview when your browser supports it.";

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
      const access = await getEffectiveStaffAccess(user.id, user.email);
      if (cancelled) return;
      setStaffAccess(access);
      setAccessResolved(true);

      let q = supabase
        .from("workshop_documents")
        .select(
          "id, workshop_id, user_id, title, file_name, file_url, mime_type, created_at, approval_status, visibility_rules"
        )
        .order("created_at", { ascending: false });
      if (!isModeratorPlusEffective(access)) {
        q = q.eq("user_id", user.id);
      } else {
        q = q.limit(500);
      }
      const { data, error: fetchError } = await q;
      if (cancelled) return;
      if (fetchError) setError(fetchError.message);
      setItems((data as WorkshopDocRow[]) || []);
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

    if (filterWorkshop !== "all") {
      out = out.filter((r) => r.workshop_id === filterWorkshop);
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

    const byCreated = (a: WorkshopDocRow, b: WorkshopDocRow) =>
      new Date(a.created_at).getTime() - new Date(b.created_at).getTime();
    const byTitle = (a: WorkshopDocRow, b: WorkshopDocRow) => a.title.localeCompare(b.title, undefined, { sensitivity: "base" });

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
        case "workshop_then_date": {
          const w = compareWorkshopId(a.workshop_id, b.workshop_id);
          if (w !== 0) return w;
          return byCreated(b, a);
        }
        default:
          return 0;
      }
    });

    return out;
  }, [items, filterWorkshop, sortKey, approvalFilter, search, isStaff]);

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

    const uploadedRows: WorkshopDocRow[] = [];
    for (const file of uploadFiles) {
      const safeName = file.name.replaceAll("/", "_");
      const filePath = `${uploadWorkshopId}/${user.id}/${Date.now()}_${safeName}`;

      const { error: storageError } = await supabase.storage
        .from("workshop-repository")
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

      const publicUrl = supabase.storage.from("workshop-repository").getPublicUrl(filePath).data.publicUrl;

      const { data: inserted, error: insertError } = await supabase
        .from("workshop_documents")
        .insert({
          workshop_id: uploadWorkshopId,
          user_id: user.id,
          title: uploadFiles.length > 1 ? `${uploadTitle.trim()} - ${file.name}` : uploadTitle.trim(),
          file_name: file.name,
          file_url: publicUrl,
          mime_type: file.type || null,
          approval_status: staff ? "approved" : "pending",
          visibility_rules: {},
        })
        .select(
          "id, workshop_id, user_id, title, file_name, file_url, mime_type, created_at, approval_status, visibility_rules"
        )
        .single();

      if (insertError) {
        setError(insertError.message);
        setUploading(false);
        return;
      }
      uploadedRows.push(inserted as WorkshopDocRow);
    }

    setItems((prev) => [...uploadedRows, ...prev]);
    setUploadTitle("");
    setUploadFiles([]);
    setSuccess(
      uploadedRows.length === 1
        ? staff
          ? "Workshop file uploaded (approved)."
          : "Upload queued for admin review."
        : `${uploadedRows.length} workshop files uploaded.`
    );
    setUploading(false);
  };

  const remove = async (id: string) => {
    if (!confirm("Delete this workshop file?")) return;
    const row = items.find((i) => i.id === id);
    if (row) {
      const storagePath = extractStoragePathFromPublicUrl(row.file_url, "workshop-repository");
      if (storagePath) {
        await supabase.storage.from("workshop-repository").remove([storagePath]);
      }
    }
    const { error: deleteError } = await supabase.from("workshop_documents").delete().eq("id", id);
    if (deleteError) {
      setError(deleteError.message);
      return;
    }
    setItems((prev) => prev.filter((p) => p.id !== id));
  };

  const startEdit = (row: WorkshopDocRow) => {
    setEditingId(row.id);
    setDraftTitle(row.title);
  };

  const saveEdit = async (id: string) => {
    const { error: updateError } = await supabase
      .from("workshop_documents")
      .update({ title: draftTitle })
      .eq("id", id);
    if (updateError) {
      setError(updateError.message);
      return;
    }
    setItems((prev) => prev.map((p) => (p.id === id ? { ...p, title: draftTitle } : p)));
    setEditingId(null);
  };

  const setApproval = async (row: WorkshopDocRow, approval_status: string) => {
    setError(null);
    const {
      data: { user },
    } = await supabase.auth.getUser();
    const { error: uErr } = await supabase
      .from("workshop_documents")
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
      <div
        style={{
          display: "flex",
          flexWrap: "wrap",
          gap: 12,
          alignItems: "flex-start",
          justifyContent: "space-between",
        }}
      >
        <div className="stack" style={{ flex: "1 1 12rem", minWidth: 0, gap: 8 }}>
          <h2 className="section-title" style={{ margin: 0 }}>
            {heading}
          </h2>
          <p className="subtle" style={{ margin: 0 }}>
            {introCopy}
          </p>
        </div>
        <button
          type="submit"
          form="workshop-upload-form"
          className="btn btn-primary btn-primary-compact"
          style={{ flexShrink: 0 }}
          disabled={uploading}
        >
          {uploading ? "Uploading…" : "Upload file"}
        </button>
      </div>
      {error ? <p className="error">{error}</p> : null}
      {success ? <p className="success">{success}</p> : null}

      <div className="list-item">
        <form
          id="workshop-upload-form"
          className="stack"
          style={{ width: "100%" }}
          onSubmit={(e) => {
            e.preventDefault();
            void upload();
          }}
        >
          <div style={{ fontWeight: 600 }}>Upload workshop file</div>
          <div className="field">
            <label>Workshop</label>
            <select value={uploadWorkshopId} onChange={(e) => setUploadWorkshopId(e.target.value)}>
              {WORKSHOP_OPTIONS.map((w) => (
                <option key={w.id} value={w.id}>
                  {w.id} — {w.label}
                </option>
              ))}
            </select>
          </div>
          <div className="field">
            <label>Title</label>
            <input
              value={uploadTitle}
              onChange={(e) => setUploadTitle(e.target.value)}
              placeholder="e.g., Soil notes and resources"
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
              <label htmlFor="ws-filter">Workshop</label>
              <select
                id="ws-filter"
                value={filterWorkshop}
                onChange={(e) => setFilterWorkshop(e.target.value)}
              >
                <option value="all">All workshops</option>
                {WORKSHOP_OPTIONS.map((w) => (
                  <option key={w.id} value={w.id}>
                    {w.id} — {w.label}
                  </option>
                ))}
              </select>
            </div>
            <div className="field">
              <label htmlFor="ws-sort">Sort</label>
              <select id="ws-sort" value={sortKey} onChange={(e) => setSortKey(e.target.value as SortKey)}>
                <option value="created_desc">Newest first</option>
                <option value="created_asc">Oldest first</option>
                <option value="title_asc">Title A–Z</option>
                <option value="title_desc">Title Z–A</option>
                <option value="workshop_then_date">Workshop order, then newest</option>
              </select>
            </div>
            {isStaff ? (
              <div className="field">
                <label htmlFor="ws-approval">Approval</label>
                <select id="ws-approval" value={approvalFilter} onChange={(e) => setApprovalFilter(e.target.value)}>
                  <option value="all">All statuses</option>
                  <option value="pending">Pending</option>
                  <option value="approved">Approved</option>
                  <option value="rejected">Rejected</option>
                </select>
              </div>
            ) : null}
            <div className="field" style={{ flex: "2 1 220px", minWidth: "200px" }}>
              <label htmlFor="ws-search">Search</label>
              <input
                id="ws-search"
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

      {loading ? <p className="subtle">Loading workshop files…</p> : null}
      {!loading && items.length === 0 ? <p className="empty">No workshop files uploaded yet.</p> : null}
      {!loading && items.length > 0 && visibleItems.length === 0 ? (
        <p className="empty">No files match your filters. Try clearing search or choosing “All workshops”.</p>
      ) : null}

      {!loading && visibleItems.length > 0 ? (
        <FileBrowseGalleryDocumentsTabs
          galleryCount={galleryFromFilter.length}
          documentCount={documentListItems.length}
          preferDocumentsTab={editingIsGallery}
          tabListAriaLabel="Workshop gallery and documents"
          galleryDescription="Workshop image uploads — click a tile for a larger preview."
          documentsDescription="PDFs, documents, video, audio, and other files — same row actions as before."
          galleryPanel={
            galleryItems.length === 0 && !editingIsGallery ? (
              <p className="empty subtle">No image files in this view.</p>
            ) : (
              <FileGalleryGrid
                items={galleryItems}
                subtitle={(item) => workshopShortLabel(item.workshop_id)}
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
                          <div className="workshop-line-meta">{workshopShortLabel(item.workshop_id)}</div>
                          {isStaff ? (
                            <div className="workshop-line-meta">
                              Owner {uploaderLabels[item.user_id] ?? "…"} · {item.approval_status ?? "pending"}
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
