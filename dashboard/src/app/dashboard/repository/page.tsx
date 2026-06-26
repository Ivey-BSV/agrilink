"use client";

import { ResourceFolderLibrary } from "@/components/resource-folder-library";

const REPOSITORY_DOC_SELECT =
  "id, folder_id, user_id, title, file_name, file_url, mime_type, created_at, approval_status, visibility_rules";

export default function RepositoryFilesPage() {
  return (
    <ResourceFolderLibrary
      scope="repository"
      heading="Repository Files"
      memberHeading="My Repository Files"
      description="Browse repository folders — each folder has a photo gallery, documents, and links for shared reference materials."
      memberDescription="Open a folder to store guides, PDFs, images, and links. The gallery highlights pictures; documents and links have their own tabs."
      emptyLibraryMessage="No repository folders yet. Create a folder to organize shared files."
      tableName="knowledge_repository_documents"
      storageBucket="knowledge-repository"
      docSelect={REPOSITORY_DOC_SELECT}
      uploadModalTitle="Upload repository file"
      uploadSuccessSingular="Repository file uploaded."
      uploadSuccessPlural="{n} repository files uploaded."
      deleteConfirmMessage="Delete this repository file?"
    />
  );
}
