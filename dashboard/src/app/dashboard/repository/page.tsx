"use client";

import { ResourceFolderLibrary } from "@/components/resource-folder-library";
import { useSearchParams } from "next/navigation";

const REPOSITORY_DOC_SELECT =
  "id, folder_id, user_id, title, file_name, file_url, mime_type, created_at, approval_status, visibility_rules";

export default function RepositoryFilesPage() {
  const searchParams = useSearchParams();
  const initialFolderId = searchParams.get("folder");

  return (
    <ResourceFolderLibrary
      scope="repository"
      heading="Repository Files"
      memberHeading="My Repository Files"
      description="Browse folders for shared guides, PDFs, photos, and links. Open a folder to upload or add a link. Click Repository in the sidebar anytime to return to all folders."
      memberDescription="Open a folder to upload files or add links (YouTube, articles). Click Repository in the sidebar (or the breadcrumb) to go back to all folders."
      emptyLibraryMessage="No repository folders yet. Create a folder first, then upload files or add links inside it."
      tableName="knowledge_repository_documents"
      storageBucket="knowledge-repository"
      docSelect={REPOSITORY_DOC_SELECT}
      uploadModalTitle="Upload repository file"
      uploadSuccessSingular="Repository file uploaded."
      uploadSuccessPlural="{n} repository files uploaded."
      deleteConfirmMessage="Delete this repository file?"
      initialFolderId={initialFolderId}
    />
  );
}
