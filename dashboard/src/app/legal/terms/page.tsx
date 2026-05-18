import { LegalDocumentView } from "@/components/legal-document-view";
import { TERMS_OF_USE_SECTIONS } from "@/lib/legal-policy-content";

export default function PublicTermsPage() {
  return (
    <div style={{ maxWidth: 900, margin: "0 auto", padding: "24px 16px" }}>
      <LegalDocumentView
        docTitle="Terms of Use"
        sections={TERMS_OF_USE_SECTIONS}
        backHref="/"
        backLabel="← Sign in"
      />
    </div>
  );
}
