"use client";

import { ResourceFolderLibrary } from "@/components/resource-folder-library";
import { useSearchParams } from "next/navigation";

const WORKSHOP_DOC_SELECT =
  "id, folder_id, user_id, title, file_name, file_url, mime_type, created_at, approval_status, visibility_rules";

export default function WorkshopsFilesPage() {
  const searchParams = useSearchParams();
  const initialFolderId = searchParams.get("folder");

  return (
    <ResourceFolderLibrary
      scope="workshop"
      heading="Workshop Files"
      memberHeading="My Workshop Files"
      description="Browse workshop folders — each folder has a photo gallery, documents, and links. Open a folder to view uploads or add new content."
      memberDescription="Open a workshop folder to upload handouts, photos, and links. Images appear in the gallery; PDFs and URLs have their own tabs."
      emptyLibraryMessage="No workshop folders yet. Create a folder for each session or event."
      tableName="workshop_documents"
      storageBucket="workshop-repository"
      docSelect={WORKSHOP_DOC_SELECT}
      uploadModalTitle="Upload workshop file"
      uploadSuccessSingular="Workshop file uploaded."
      uploadSuccessPlural="{n} workshop files uploaded."
      deleteConfirmMessage="Delete this workshop file?"
      initialFolderId={initialFolderId}
    />
  );
}
