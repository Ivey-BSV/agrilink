class EntitySharedFilesConfig {
  const EntitySharedFilesConfig({
    required this.entityId,
    required this.documentsTable,
    required this.entityIdColumn,
    required this.storageBucket,
    required this.storageUrlMarker,
    required this.canUpload,
    required this.sectionTitle,
    required this.descriptionText,
    required this.consentDialogTitle,
    required this.consentDialogBody,
    required this.uploadSuccessMessage,
    required this.deleteDialogBody,
    required this.loadErrorHint,
    required this.emptyStateMessage,
    this.uploadDeniedMessage,
    this.showViewOnlyWhenCannotUpload = false,
  });

  final String entityId;
  final String documentsTable;
  final String entityIdColumn;
  final String storageBucket;
  final String storageUrlMarker;
  final bool canUpload;
  final String sectionTitle;
  final String descriptionText;
  final String consentDialogTitle;
  final String consentDialogBody;
  final String uploadSuccessMessage;
  final String deleteDialogBody;
  final String loadErrorHint;
  final String emptyStateMessage;
  final String? uploadDeniedMessage;
  final bool showViewOnlyWhenCannotUpload;

  factory EntitySharedFilesConfig.goal({
    required String goalId,
    required bool canUpload,
  }) {
    return EntitySharedFilesConfig(
      entityId: goalId,
      documentsTable: 'goal_documents',
      entityIdColumn: 'goal_id',
      storageBucket: 'goal-repository',
      storageUrlMarker: '/goal-repository/',
      canUpload: canUpload,
      showViewOnlyWhenCannotUpload: !canUpload,
      sectionTitle: 'Project files',
      descriptionText: canUpload
          ? 'PDFs, slides, photos, and other files shared with everyone who can open this project.'
          : 'Files shared by the owner and joined members.',
      consentDialogTitle: 'Project file review',
      consentDialogBody:
          'Staff may review this file before it is treated as fully published for the project.',
      uploadSuccessMessage: 'File shared with this project.',
      deleteDialogBody: 'This removes it for everyone in this project.',
      loadErrorHint:
          'Could not load files. Apply the goal_documents Supabase migration if needed.',
      emptyStateMessage: canUpload
          ? 'No files yet. Tap Add to share from Files or Photos.'
          : 'No files have been shared yet.',
      uploadDeniedMessage:
          'Only the project owner or joined members can upload files.',
    );
  }

  factory EntitySharedFilesConfig.workshop({required String workshopId}) {
    return EntitySharedFilesConfig(
      entityId: workshopId,
      documentsTable: 'workshop_documents',
      entityIdColumn: 'workshop_id',
      storageBucket: 'workshop-repository',
      storageUrlMarker: '/workshop-repository/',
      canUpload: true,
      sectionTitle: 'Shared materials',
      descriptionText:
          'PDFs, slides, photos, and other files visible to everyone in this workshop.',
      consentDialogTitle: 'Workshop file review',
      consentDialogBody:
          'Staff may review this file before it is treated as fully published for the workshop.',
      uploadSuccessMessage: 'File shared with this workshop.',
      deleteDialogBody: 'This removes it for everyone in this workshop.',
      loadErrorHint:
          'Could not load files. Run create_workshop_documents.sql in Supabase if needed.',
      emptyStateMessage: 'No files yet. Tap Add to share from Files or Photos.',
    );
  }
}
