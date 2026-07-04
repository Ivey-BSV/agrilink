"use client";

import { FormEvent, useEffect, useMemo, useState } from "react";
import { ForumTagPicker } from "@/components/forum-tag-picker";
import {
  createExchangeHubListing,
  exchangeHubPrimaryImage,
  rowsToSpecifications,
  specificationsToRows,
  updateExchangeHubListing,
  uploadExchangeHubImage,
  type ExchangeHubListing,
  type ExchangeHubSpecRow,
} from "@/lib/exchange-hub";
import { networkDisplayImageUrl } from "@/lib/image-urls";
import { supabase } from "@/lib/supabase";

const MAX_TAGS = 5;

type ExchangeHubListingModalProps = {
  open: boolean;
  mode: "create" | "edit";
  listing: ExchangeHubListing | null;
  onClose: () => void;
  onSaved: () => void;
};

export function ExchangeHubListingModal({ open, mode, listing, onClose, onSaved }: ExchangeHubListingModalProps) {
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [condition, setCondition] = useState("");
  const [tags, setTags] = useState<string[]>([]);
  const [imageUrl, setImageUrl] = useState<string | null>(null);
  const [specRows, setSpecRows] = useState<ExchangeHubSpecRow[]>([]);
  const [saving, setSaving] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!open) return;
    if (mode === "edit" && listing) {
      setTitle(listing.title);
      setDescription(listing.description ?? "");
      setCondition(listing.condition ?? "");
      setTags(listing.tags);
      setImageUrl(exchangeHubPrimaryImage(listing));
      setSpecRows(specificationsToRows(listing.specifications));
    } else {
      setTitle("");
      setDescription("");
      setCondition("");
      setTags([]);
      setImageUrl(null);
      setSpecRows([]);
    }
    setError(null);
  }, [open, mode, listing]);

  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape" && !saving && !uploading) onClose();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open, saving, uploading, onClose]);

  const previewUrl = useMemo(() => networkDisplayImageUrl(imageUrl, 800), [imageUrl]);

  const onTagsChange = (next: string[]) => {
    if (next.length > MAX_TAGS) {
      setError(`You can select up to ${MAX_TAGS} tags.`);
      setTags(next.slice(0, MAX_TAGS));
      return;
    }
    setError(null);
    setTags(next);
  };

  const addSpecRow = () => {
    setSpecRows((prev) => [...prev, { id: `spec-${Date.now()}`, label: "", value: "" }]);
  };

  const updateSpecRow = (id: string, field: "label" | "value", value: string) => {
    setSpecRows((prev) => prev.map((row) => (row.id === id ? { ...row, [field]: value } : row)));
  };

  const removeSpecRow = (id: string) => {
    setSpecRows((prev) => prev.filter((row) => row.id !== id));
  };

  const onImagePick = async (file: File | null) => {
    if (!file) return;
    setUploading(true);
    setError(null);
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      setError("Sign in required.");
      setUploading(false);
      return;
    }
    const { url, error: uploadError } = await uploadExchangeHubImage(file, user.id);
    setUploading(false);
    if (uploadError || !url) {
      setError(uploadError || "Image upload failed.");
      return;
    }
    setImageUrl(url);
  };

  const onSubmit = async (e: FormEvent) => {
    e.preventDefault();
    if (!title.trim()) {
      setError("Please enter a title.");
      return;
    }
    if (!description.trim()) {
      setError("Please enter a description.");
      return;
    }

    setSaving(true);
    setError(null);

    const payload = {
      title: title.trim(),
      description: description.trim(),
      condition: condition.trim() || null,
      tags,
      imageUrls: imageUrl ? [imageUrl] : [],
      specifications: rowsToSpecifications(specRows),
    };

    const result =
      mode === "edit" && listing
        ? await updateExchangeHubListing(listing.id, payload)
        : await createExchangeHubListing(payload);

    setSaving(false);
    if (result.error) {
      setError(result.error);
      return;
    }
    onSaved();
    onClose();
  };

  if (!open) return null;

  return (
    <div className="backdrop active" role="dialog" aria-modal="true" aria-labelledby="exchange-hub-form-title">
      <div className="absolute inset-0" onClick={() => !saving && !uploading && onClose()} />
      <div
        className="modal-content platform-create-modal exchange-hub-form-modal"
        style={{ opacity: 1, transform: "none", maxWidth: 640, width: "min(96vw, 640px)" }}
      >
        <div className="stack" style={{ gap: 14 }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", gap: 10 }}>
            <h3 id="exchange-hub-form-title" className="section-title" style={{ fontSize: "1.2rem", margin: 0 }}>
              {mode === "edit" ? "Edit shared asset" : "Share asset"}
            </h3>
            <button type="button" className="btn btn-secondary" disabled={saving || uploading} onClick={onClose}>
              Close
            </button>
          </div>

          <form className="stack" style={{ gap: 14 }} onSubmit={(e) => void onSubmit(e)}>
            <div className="field">
              <label>Title</label>
              <input value={title} onChange={(e) => setTitle(e.target.value)} maxLength={80} required disabled={saving} />
            </div>

            <div className="field">
              <label>Condition (optional)</label>
              <input
                value={condition}
                onChange={(e) => setCondition(e.target.value)}
                placeholder="e.g., Excellent, Good condition"
                disabled={saving}
              />
            </div>

            <div className="field">
              <label>Description</label>
              <textarea
                rows={4}
                maxLength={500}
                required
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                placeholder="List the assets which you'd like to share with the community"
                disabled={saving}
              />
            </div>

            <div className="field">
              <label>Photo (optional)</label>
              {previewUrl ? (
                <div className="exchange-hub-form-preview-wrap">
                  <img src={previewUrl} alt="" className="exchange-hub-form-preview" />
                  <button type="button" className="btn btn-secondary" disabled={saving || uploading} onClick={() => setImageUrl(null)}>
                    Remove photo
                  </button>
                </div>
              ) : (
                <input
                  type="file"
                  accept="image/*"
                  disabled={saving || uploading}
                  onChange={(e) => void onImagePick(e.target.files?.[0] ?? null)}
                />
              )}
              {uploading ? <p className="subtle" style={{ margin: "8px 0 0" }}>Uploading photo…</p> : null}
            </div>

            <div className="field">
              <label>Tags (optional, up to {MAX_TAGS})</label>
              <div style={{ maxHeight: 220, overflowY: "auto", paddingRight: 4 }}>
                <ForumTagPicker selected={tags} onChange={onTagsChange} />
              </div>
            </div>

            <div className="field">
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", gap: 10 }}>
                <label style={{ margin: 0 }}>Specifications (optional)</label>
                <button type="button" className="btn btn-secondary btn-primary-compact" disabled={saving} onClick={addSpecRow}>
                  Add row
                </button>
              </div>
              {specRows.length === 0 ? (
                <p className="subtle" style={{ margin: "8px 0 0" }}>
                  No specifications added yet.
                </p>
              ) : (
                <div className="stack" style={{ gap: 8, marginTop: 8 }}>
                  {specRows.map((row) => (
                    <div key={row.id} className="exchange-hub-spec-edit-row">
                      <input
                        value={row.label}
                        onChange={(e) => updateSpecRow(row.id, "label", e.target.value)}
                        placeholder="Label"
                        disabled={saving}
                      />
                      <input
                        value={row.value}
                        onChange={(e) => updateSpecRow(row.id, "value", e.target.value)}
                        placeholder="Value"
                        disabled={saving}
                      />
                      <button type="button" className="btn btn-secondary" disabled={saving} onClick={() => removeSpecRow(row.id)}>
                        Remove
                      </button>
                    </div>
                  ))}
                </div>
              )}
            </div>

            {error ? <p className="error">{error}</p> : null}

            <div style={{ display: "flex", gap: 10, justifyContent: "flex-end", flexWrap: "wrap" }}>
              <button type="button" className="btn btn-secondary" disabled={saving || uploading} onClick={onClose}>
                Cancel
              </button>
              <button type="submit" className="btn btn-primary" disabled={saving || uploading}>
                {saving ? "Saving…" : mode === "edit" ? "Save changes" : "Share asset"}
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  );
}
