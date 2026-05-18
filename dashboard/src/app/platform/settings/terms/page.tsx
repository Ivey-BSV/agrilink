import { LegalDocumentView } from "@/components/legal-document-view";
import { TERMS_OF_USE_SECTIONS } from "@/lib/legal-policy-content";

export default function TermsOfUsePage() {
  return <LegalDocumentView docTitle="Terms of Use" sections={TERMS_OF_USE_SECTIONS} />;
}
