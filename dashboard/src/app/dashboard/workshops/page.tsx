"use client";

import { ResourceFolderLibrary } from "@/components/resource-folder-library";

const WORKSHOP_DOC_SELECT =
  "id, folder_id, user_id, title, file_name, file_url, mime_type, created_at, approval_status, visibility_rules";

export default function WorkshopsFilesPage() {
  return (
    <ResourceFolderLibrary
      scope="workshop"
      heading="Workshop Files"
      memberHeading="My Workshop Files"
      description="Browse workshop folders — each folder has a photo gallery and a document list. Open a folder to view uploads or add new files."
      memberDescription="Open a workshop folder to upload handouts and photos. Images appear in the gallery; PDFs and other files stay in the document list."
      emptyLibraryMessage="No workshop folders yet. Create a folder for each session or event."
      tableName="workshop_documents"
      storageBucket="workshop-repository"
      docSelect={WORKSHOP_DOC_SELECT}
      uploadModalTitle="Upload workshop file"
      uploadSuccessSingular="Workshop file uploaded."
      uploadSuccessPlural="{n} workshop files uploaded."
      deleteConfirmMessage="Delete this workshop file?"
    />
  );
}
