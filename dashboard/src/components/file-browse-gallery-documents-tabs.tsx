"use client";

import { useEffect, useState, type ReactNode } from "react";

type BrowseTab = "gallery" | "documents" | "links";

function pickInitialTab(
  galleryCount: number,
  documentCount: number,
  linksCount: number,
  hasLinks: boolean
): BrowseTab {
  if (galleryCount > 0) return "gallery";
  if (documentCount > 0) return "documents";
  if (hasLinks && linksCount > 0) return "links";
  return "gallery";
}

export function FileBrowseGalleryDocumentsTabs({
  galleryCount,
  documentCount,
  linksCount = 0,
  preferDocumentsTab,
  preferLinksTab,
  tabListAriaLabel,
  galleryDescription,
  documentsDescription,
  linksDescription,
  galleryPanel,
  documentsPanel,
  linksPanel,
}: {
  galleryCount: number;
  documentCount: number;
  linksCount?: number;
  preferDocumentsTab?: boolean;
  preferLinksTab?: boolean;
  tabListAriaLabel: string;
  galleryDescription: string;
  documentsDescription: string;
  linksDescription?: string;
  galleryPanel: ReactNode;
  documentsPanel: ReactNode;
  linksPanel?: ReactNode;
}) {
  const hasLinks = linksPanel != null;
  const [tab, setTab] = useState<BrowseTab>(() =>
    pickInitialTab(galleryCount, documentCount, linksCount, hasLinks)
  );

  useEffect(() => {
    setTab(pickInitialTab(galleryCount, documentCount, linksCount, hasLinks));
  }, [galleryCount, documentCount, linksCount, hasLinks]);

  useEffect(() => {
    if (preferDocumentsTab) setTab("documents");
  }, [preferDocumentsTab]);

  useEffect(() => {
    if (preferLinksTab) setTab("links");
  }, [preferLinksTab]);

  const tabsClass = hasLinks
    ? "platform-profile-tabs file-browse-tabs--split file-browse-tabs--triple"
    : "platform-profile-tabs file-browse-tabs--split";

  return (
    <div className="file-browse-tabbed">
      <div className={tabsClass} role="tablist" aria-label={tabListAriaLabel}>
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
        {hasLinks ? (
          <button
            type="button"
            role="tab"
            aria-selected={tab === "links"}
            className={`platform-profile-tab${tab === "links" ? " active" : ""}`}
            onClick={() => setTab("links")}
          >
            Links ({linksCount})
          </button>
        ) : null}
      </div>

      {tab === "gallery" ? (
        <div className="file-browse-tab-panel" role="tabpanel">
          <p className="subtle file-browse-tab-panel-hint">{galleryDescription}</p>
          {galleryPanel}
        </div>
      ) : tab === "documents" ? (
        <div className="file-browse-tab-panel" role="tabpanel">
          <p className="subtle file-browse-tab-panel-hint">{documentsDescription}</p>
          {documentsPanel}
        </div>
      ) : (
        <div className="file-browse-tab-panel" role="tabpanel">
          <p className="subtle file-browse-tab-panel-hint">{linksDescription}</p>
          {linksPanel}
        </div>
      )}
    </div>
  );
}
