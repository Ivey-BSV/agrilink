import Link from "next/link";
import type { LegalSection } from "@/lib/legal-policy-content";

export function LegalDocumentView({
  docTitle,
  sections,
  backHref = "/platform/settings",
  backLabel = "← Settings",
}: {
  docTitle: string;
  sections: LegalSection[];
  backHref?: string;
  backLabel?: string;
}) {
  const year = new Date().getFullYear();
  return (
    <div className="content-card stack legal-doc-page" style={{ gap: 20 }}>
      <div>
        <Link href={backHref} className="btn btn-secondary" style={{ display: "inline-block" }}>
          {backLabel}
        </Link>
        <h2 className="section-title" style={{ marginTop: 12 }}>
          {docTitle}
        </h2>
        <p className="subtle" style={{ marginTop: 8 }}>
          Last updated: {year}
        </p>
      </div>
      <div className="stack legal-doc-sections" style={{ gap: 20 }}>
        {sections.map((s) => (
          <section key={s.title}>
            <h3 className="legal-doc-section-title">{s.title}</h3>
            <div className="legal-doc-body">{s.body.trim()}</div>
          </section>
        ))}
      </div>
    </div>
  );
}
