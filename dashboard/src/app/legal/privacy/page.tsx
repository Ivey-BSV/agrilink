import { LegalDocumentView } from "@/components/legal-document-view";
import { PRIVACY_POLICY_SECTIONS } from "@/lib/legal-policy-content";

export default function PublicPrivacyPage() {
  return (
    <div style={{ maxWidth: 900, margin: "0 auto", padding: "24px 16px" }}>
      <LegalDocumentView
        docTitle="Privacy Policy"
        sections={PRIVACY_POLICY_SECTIONS}
        backHref="/"
        backLabel="← Sign in"
      />
    </div>
  );
}
