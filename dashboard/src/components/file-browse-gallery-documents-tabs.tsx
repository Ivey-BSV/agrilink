"use client";

import { useEffect, useState, type ReactNode } from "react";

type BrowseTab = "gallery" | "documents";

export function FileBrowseGalleryDocumentsTabs({
  galleryCount,
  documentCount,
  preferDocumentsTab,
  tabListAriaLabel,
  galleryDescription,
  documentsDescription,
  galleryPanel,
  documentsPanel,
}: {
  galleryCount: number;
  documentCount: number;
  preferDocumentsTab?: boolean;
  tabListAriaLabel: string;
  galleryDescription: string;
  documentsDescription: string;
  galleryPanel: ReactNode;
  documentsPanel: ReactNode;
}) {
  const [tab, setTab] = useState<BrowseTab>(() =>
    galleryCount === 0 && documentCount > 0 ? "documents" : "gallery"
  );

  useEffect(() => {
    if (galleryCount === 0 && documentCount > 0) setTab("documents");
  }, [galleryCount, documentCount]);

  useEffect(() => {
    if (preferDocumentsTab) setTab("documents");
  }, [preferDocumentsTab]);

  return (
    <div className="file-browse-tabbed">
      <div
        className="platform-profile-tabs file-browse-tabs--split"
        role="tablist"
        aria-label={tabListAriaLabel}
      >
        <button
          type="button"
          role="tab"
          aria-selected={tab === "gallery"}
          className={`platform-profile-tab${tab === "gallery" ? " active" : ""}`}
          onClick={() => setTab("gallery")}
        >
          Gallery ({galleryCount})
        </button>
        <button
          type="button"
          role="tab"
          aria-selected={tab === "documents"}
          className={`platform-profile-tab${tab === "documents" ? " active" : ""}`}
          onClick={() => setTab("documents")}
        >
          Documents ({documentCount})
        </button>
      </div>

      {tab === "gallery" ? (
        <div className="file-browse-tab-panel" role="tabpanel">
          <p className="subtle file-browse-tab-panel-hint">{galleryDescription}</p>
          {galleryPanel}
        </div>
      ) : (
        <div className="file-browse-tab-panel" role="tabpanel">
          <p className="subtle file-browse-tab-panel-hint">{documentsDescription}</p>
          {documentsPanel}
        </div>
      )}
    </div>
  );
}
