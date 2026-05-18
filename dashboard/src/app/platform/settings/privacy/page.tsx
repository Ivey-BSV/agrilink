import { LegalDocumentView } from "@/components/legal-document-view";
import { PRIVACY_POLICY_SECTIONS } from "@/lib/legal-policy-content";

export default function PrivacyPolicyPage() {
  return <LegalDocumentView docTitle="Privacy Policy" sections={PRIVACY_POLICY_SECTIONS} />;
}
