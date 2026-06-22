"use client";

import { motion } from "framer-motion";
import { useCallback, useEffect, useMemo, useState } from "react";
import { supabase } from "@/lib/supabase";
import { formatDate } from "@/lib/format";
import { extractStoragePathFromPublicUrl } from "@/lib/storage";
import { getEffectiveStaffAccess, isModeratorPlusEffective, type EffectiveStaffAccess } from "@/lib/staff-profile";
import { splitGalleryAndDocuments, isGalleryImageFile } from "@/lib/file-browse-layout";
import {
  buildResourceStoragePath,
  RESOURCE_FOLDER_SELECT,
  type ResourceFolder,
  type ResourceScope,
} from "@/lib/resource-folders";
import { FileUploadModal } from "@/components/file-upload-modal";
import { FileBrowseGalleryDocumentsTabs } from "@/components/file-browse-gallery-documents-tabs";
import { FileGalleryGrid } from "@/components/file-gallery-grid";
import { FileRowThumb } from "@/components/file-row-thumb";
import { MotionListItem } from "@/components/motion-list";
import { PageSectionHeader } from "@/components/page-section-header";
import { fetchUploaderLabelByUserIds } from "@/lib/document-owner-profiles";

type LibraryDocRow = {
  id: string;
  folder_id: string | null;
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

type ResourceFolderLibraryProps = {
  scope: ResourceScope;
  heading: string;
  memberHeading: string;
  description: string;
  memberDescription: string;
  emptyLibraryMessage: string;
  tableName: "workshop_documents" | "knowledge_repository_documents";
  storageBucket: "workshop-repository" | "knowledge-repository";
  docSelect: string;
  uploadModalTitle: string;
  uploadSuccessSingular: string;
  uploadSuccessPlural: string;
  deleteConfirmMessage: string;
};

export function ResourceFolderLibrary({
  scope,
  heading,
  memberHeading,
  description,
  memberDescription,
  emptyLibraryMessage,
  tableName,
  storageBucket,
  docSelect,
  uploadModalTitle,
  uploadSuccessSingular,
  uploadSuccessPlural,
  deleteConfirmMessage,
}: ResourceFolderLibraryProps) {
  const [folders, setFolders] = useState<ResourceFolder[]>([]);
  const [items, setItems] = useState<LibraryDocRow[]>([]);
  const [selectedFolderId, setSelectedFolderId] = useState<string | null>(null);
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
  const [ownerFilter, setOwnerFilter] = useState<"all" | "mine">("all");
  const [search, setSearch] = useState("");
  const [uploadOpen, setUploadOpen] = useState(false);
  const [folderModalOpen, setFolderModalOpen] = useState(false);
  const [newFolderName, setNewFolderName] = useState("");
  const [newFolderDescription, setNewFolderDescription] = useState("");
  const [creatingFolder, setCreatingFolder] = useState(false);

  const isStaff = isModeratorPlusEffective(staffAccess);
  const pageHeading = !accessResolved || isStaff ? heading : memberHeading;
  const pageDescription = !accessResolved || isStaff ? description : memberDescription;
  const selectedFolder = selectedFolderId ? folders.find((f) => f.id === selectedFolderId) ?? null : null;

  const loadData = useCallback(async () => {
    setError(null);
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      setError("Not signed in.");
      setLoading(false);
      return;
    }
    setCurrentUserId(user.id);
    const access = await getEffectiveStaffAccess(user.id, user.email);
    setStaffAccess(access);
    setAccessResolved(true);

    const { data: folderData, error: folderError } = await supabase
      .from("resource_folders")
      .select(RESOURCE_FOLDER_SELECT)
      .eq("scope", scope)
      .order("sort_order", { ascending: true })
      .order("name", { ascending: true });

    if (folderError) {
      setError(folderError.message);
      setLoading(false);
      return;
    }
    setFolders((folderData as ResourceFolder[]) ?? []);

    let q = supabase.from(tableName).select(docSelect).order("created_at", { ascending: false });
    if (!isModeratorPlusEffective(access)) {
      q = q.eq("user_id", user.id);
    } else {
      q = q.limit(800);
    }
    const { data, error: fetchError } = await q;
    if (fetchError) {
      setError(fetchError.message);
      setLoading(false);
      return;
    }
    setItems((data as LibraryDocRow[]) ?? []);
    setLoading(false);
  }, [scope, tableName, docSelect]);

  useEffect(() => {
    void loadData();
  }, [loadData]);

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

  const folderStats = useMemo(() => {
    const stats = new Map<string, { total: number; gallery: number; documents: number }>();
    for (const folder of folders) {
      stats.set(folder.id, { total: 0, gallery: 0, documents: 0 });
    }
    for (const item of items) {
      if (!item.folder_id) continue;
      const entry = stats.get(item.folder_id) ?? { total: 0, gallery: 0, documents: 0 };
      entry.total += 1;
      if (isGalleryImageFile(item.file_name, item.mime_type, item.file_url, item.title)) {
        entry.gallery += 1;
      } else {
        entry.documents += 1;
      }
      stats.set(item.folder_id, entry);
    }
    return stats;
  }, [folders, items]);

  const visibleItems = useMemo(() => {
    if (!selectedFolderId) return [];
    let out = items.filter((r) => r.folder_id === selectedFolderId);

    if (isStaff && ownerFilter === "mine" && currentUserId) {
      out = out.filter((r) => r.user_id === currentUserId);
    }

    const q = search.trim().toLowerCase();
    if (q) {
      out = out.filter(
        (r) => r.title.toLowerCase().includes(q) || r.file_name.toLowerCase().includes(q)
      );
    }

    const byCreated = (a: LibraryDocRow, b: LibraryDocRow) =>
      new Date(a.created_at).getTime() - new Date(b.created_at).getTime();
    const byTitle = (a: LibraryDocRow, b: LibraryDocRow) =>
      a.title.localeCompare(b.title, undefined, { sensitivity: "base" });

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
  }, [items, selectedFolderId, sortKey, search, isStaff, ownerFilter, currentUserId]);

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

  const createFolder = async () => {
    const name = newFolderName.trim();
    if (!name) {
      setError("Folder name is required.");
      return;
    }
    setCreatingFolder(true);
    setError(null);
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      setError("Not signed in.");
      setCreatingFolder(false);
      return;
    }

    const maxSort = folders.reduce((m, f) => Math.max(m, f.sort_order), 0);
    const { data, error: insertError } = await supabase
      .from("resource_folders")
      .insert({
        scope,
        name,
        description: newFolderDescription.trim() || null,
        sort_order: maxSort + 10,
        created_by: user.id,
      })
      .select(RESOURCE_FOLDER_SELECT)
      .single();

    if (insertError) {
      setError(insertError.message);
      setCreatingFolder(false);
      return;
    }

    const row = data as ResourceFolder;
    setFolders((prev) => [...prev, row].sort((a, b) => a.sort_order - b.sort_order || a.name.localeCompare(b.name)));
    setNewFolderName("");
    setNewFolderDescription("");
    setFolderModalOpen(false);
    setSelectedFolderId(row.id);
    setSuccess(`Folder “${row.name}” created.`);
    setCreatingFolder(false);
  };

  const upload = async () => {
    if (!selectedFolderId) {
      setError("Open a folder before uploading.");
      return;
    }
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
    const folder = folders.find((f) => f.id === selectedFolderId);
    const uploadedRows: LibraryDocRow[] = [];

    for (const file of uploadFiles) {
      const filePath = buildResourceStoragePath(selectedFolderId, user.id, file.name);

      const { error: storageError } = await supabase.storage.from(storageBucket).upload(filePath, file, {
        cacheControl: "3600",
        upsert: false,
        contentType: file.type || "application/octet-stream",
      });

      if (storageError) {
        setError(storageError.message);
        setUploading(false);
        return;
      }

      const publicUrl = supabase.storage.from(storageBucket).getPublicUrl(filePath).data.publicUrl;

      const payload: Record<string, unknown> = {
        folder_id: selectedFolderId,
        user_id: user.id,
        title: uploadFiles.length > 1 ? `${uploadTitle.trim()} - ${file.name}` : uploadTitle.trim(),
        file_name: file.name,
        file_url: publicUrl,
        mime_type: file.type || null,
        approval_status: staff ? "approved" : "pending",
        visibility_rules: {},
      };
      if (tableName === "workshop_documents" && folder?.legacy_workshop_id) {
        payload.workshop_id = folder.legacy_workshop_id;
      }

      const { data: inserted, error: insertError } = await supabase
        .from(tableName)
        .insert(payload)
        .select(docSelect)
        .single();

      if (insertError) {
        setError(insertError.message);
        setUploading(false);
        return;
      }
      uploadedRows.push(inserted as LibraryDocRow);
    }

    setItems((prev) => [...uploadedRows, ...prev]);
    setUploadTitle("");
    setUploadFiles([]);
    setUploadOpen(false);
    setSuccess(uploadedRows.length === 1 ? uploadSuccessSingular : uploadSuccessPlural.replace("{n}", String(uploadedRows.length)));
    setUploading(false);
  };

  const remove = async (id: string) => {
    if (!confirm(deleteConfirmMessage)) return;
    const row = items.find((i) => i.id === id);
    if (row) {
      const storagePath = extractStoragePathFromPublicUrl(row.file_url, storageBucket);
      if (storagePath) {
        await supabase.storage.from(storageBucket).remove([storagePath]);
      }
    }
    const { error: deleteError } = await supabase.from(tableName).delete().eq("id", id);
    if (deleteError) {
      setError(deleteError.message);
      return;
    }
    setItems((prev) => prev.filter((p) => p.id !== id));
  };

  const startEdit = (row: LibraryDocRow) => {
    setEditingId(row.id);
    setDraftTitle(row.title);
  };

  const saveEdit = async (id: string) => {
    const { error: updateError } = await supabase.from(tableName).update({ title: draftTitle }).eq("id", id);
    if (updateError) {
      setError(updateError.message);
      return;
    }
    setItems((prev) => prev.map((p) => (p.id === id ? { ...p, title: draftTitle } : p)));
    setEditingId(null);
  };

  const openFolder = (folderId: string) => {
    setSelectedFolderId(folderId);
    setSearch("");
    setEditingId(null);
    setError(null);
    setSuccess(null);
  };

  const backToFolders = () => {
    setSelectedFolderId(null);
    setSearch("");
    setEditingId(null);
  };

  return (
    <motion.div
      className="content-card stack"
      initial={{ opacity: 0, y: 6 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.2 }}
    >
      <PageSectionHeader
        title={selectedFolder ? selectedFolder.name : pageHeading}
        description={selectedFolder?.description?.trim() || pageDescription}
        action={
          selectedFolder ? (
            <div className="resource-folder-header-actions">
              <button type="button" className="btn btn-secondary btn-primary-compact" onClick={backToFolders}>
                All folders
              </button>
              <button type="button" className="btn btn-primary btn-primary-compact" onClick={() => setUploadOpen(true)}>
                Upload file
              </button>
            </div>
          ) : (
            <button type="button" className="btn btn-primary btn-primary-compact" onClick={() => setFolderModalOpen(true)}>
              New folder
            </button>
          )
        }
      />

      {selectedFolder ? (
        <p className="subtle resource-folder-breadcrumb">
          <button type="button" className="resource-folder-breadcrumb-link" onClick={backToFolders}>
            Folders
          </button>
          <span aria-hidden> / </span>
          <span>{selectedFolder.name}</span>
        </p>
      ) : null}

      {error ? <p className="error">{error}</p> : null}
      {success ? <p className="success">{success}</p> : null}
      {loading ? <p className="subtle">Loading…</p> : null}

      {!loading && !selectedFolderId ? (
        folders.length === 0 ? (
          <div className="file-library-empty">
            <p>{emptyLibraryMessage}</p>
            <button type="button" className="btn btn-primary" onClick={() => setFolderModalOpen(true)}>
              Create first folder
            </button>
          </div>
        ) : (
          <div className="resource-folder-grid">
            {folders.map((folder) => {
              const stats = folderStats.get(folder.id) ?? { total: 0, gallery: 0, documents: 0 };
              return (
                <button
                  key={folder.id}
                  type="button"
                  className="resource-folder-card"
                  onClick={() => openFolder(folder.id)}
                >
                  <span className="resource-folder-card-icon" aria-hidden>
                    📁
                  </span>
                  <span className="resource-folder-card-name">{folder.name}</span>
                  <span className="resource-folder-card-meta">
                    {stats.total === 0
                      ? "Empty"
                      : `${stats.total} file${stats.total === 1 ? "" : "s"} · ${stats.gallery} photo${stats.gallery === 1 ? "" : "s"} · ${stats.documents} doc${stats.documents === 1 ? "" : "s"}`}
                  </span>
                </button>
              );
            })}
          </div>
        )
      ) : null}

      {!loading && selectedFolderId ? (
        visibleItems.length === 0 && !search && ownerFilter === "all" ? (
          <div className="file-library-empty">
            <p>This folder is empty. Upload photos or documents to get started.</p>
            <button type="button" className="btn btn-primary" onClick={() => setUploadOpen(true)}>
              Upload file
            </button>
          </div>
        ) : (
          <>
            <div className="file-browse-toolbar workshop-toolbar">
              <div className="field">
                <label htmlFor="folder-sort">Sort</label>
                <select id="folder-sort" value={sortKey} onChange={(e) => setSortKey(e.target.value as SortKey)}>
                  <option value="created_desc">Newest first</option>
                  <option value="created_asc">Oldest first</option>
                  <option value="title_asc">Title A–Z</option>
                  <option value="title_desc">Title Z–A</option>
                </select>
              </div>
              {isStaff ? (
                <div className="field">
                  <label htmlFor="folder-owner">Uploader</label>
                  <select
                    id="folder-owner"
                    value={ownerFilter}
                    onChange={(e) => setOwnerFilter(e.target.value as "all" | "mine")}
                  >
                    <option value="all">Everyone</option>
                    <option value="mine">My uploads only</option>
                  </select>
                </div>
              ) : null}
              <div className="field file-browse-toolbar-search">
                <label htmlFor="folder-search">Search</label>
                <input
                  id="folder-search"
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                  placeholder="Title or file name…"
                  autoComplete="off"
                />
              </div>
              <div className="workshop-toolbar-meta">{visibleItems.length} in folder</div>
            </div>

            {visibleItems.length === 0 ? (
              <p className="empty">No files match your filters.</p>
            ) : (
              <FileBrowseGalleryDocumentsTabs
                galleryCount={galleryFromFilter.length}
                documentCount={documentListItems.length}
                preferDocumentsTab={editingIsGallery}
                tabListAriaLabel="Folder gallery and documents"
                galleryDescription="Photos and images in this folder."
                documentsDescription="PDFs, slides, video, audio, and other files."
                galleryPanel={
                  galleryItems.length === 0 && !editingIsGallery ? (
                    <p className="empty subtle">No images in this folder.</p>
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
                    <p className="empty subtle">No documents in this folder.</p>
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
                              <div className="field">
                                <label>Title</label>
                                <input value={draftTitle} onChange={(e) => setDraftTitle(e.target.value)} />
                              </div>
                            ) : (
                              <>
                                <div className="workshop-line-title">{item.title}</div>
                                {isStaff ? (
                                  <div className="workshop-line-meta">
                                    Owner {uploaderLabels[item.user_id] ?? "…"}
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
            )}
          </>
        )
      ) : null}

      <FileUploadModal
        open={uploadOpen}
        title={uploadModalTitle}
        submitting={uploading}
        onClose={() => {
          if (uploading) return;
          setUploadOpen(false);
        }}
        onSubmit={upload}
      >
        {selectedFolder ? (
          <p className="subtle" style={{ margin: 0 }}>
            Uploading to <strong>{selectedFolder.name}</strong>
          </p>
        ) : null}
        <div className="field">
          <label htmlFor="folder-upload-title">Title</label>
          <input
            id="folder-upload-title"
            value={uploadTitle}
            onChange={(e) => setUploadTitle(e.target.value)}
            placeholder="e.g., Session handout"
          />
        </div>
        <div className="field">
          <label htmlFor="folder-upload-file">File</label>
          <input
            id="folder-upload-file"
            type="file"
            multiple
            onChange={(e) => setUploadFiles(Array.from(e.target.files ?? []))}
          />
        </div>
      </FileUploadModal>

      <FileUploadModal
        open={folderModalOpen}
        title="New folder"
        submitting={creatingFolder}
        submitLabel="Create folder"
        onClose={() => {
          if (creatingFolder) return;
          setFolderModalOpen(false);
        }}
        onSubmit={createFolder}
      >
        <div className="field">
          <label htmlFor="new-folder-name">Folder name</label>
          <input
            id="new-folder-name"
            value={newFolderName}
            onChange={(e) => setNewFolderName(e.target.value)}
            placeholder="e.g., May 6 Open Lecture"
            autoFocus
          />
        </div>
        <div className="field">
          <label htmlFor="new-folder-desc">Description (optional)</label>
          <textarea
            id="new-folder-desc"
            rows={2}
            value={newFolderDescription}
            onChange={(e) => setNewFolderDescription(e.target.value)}
            placeholder="Short note about what belongs here"
          />
        </div>
      </FileUploadModal>
    </motion.div>
  );
}
