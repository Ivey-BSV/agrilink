import 'package:cap/shared/models/resource_folder.dart';
import 'package:cap/shared/widgets/resource_folder_library_page.dart';
import 'package:flutter/material.dart';

class KnowledgeRepositoryPage extends StatelessWidget {
  const KnowledgeRepositoryPage({super.key, this.initialFolderId});

  final String? initialFolderId;

  @override
  Widget build(BuildContext context) {
    return ResourceFolderLibraryPage(
      scope: ResourceScope.repository,
      title: 'Repository',
      description:
          'Browse shared folders. Each folder has a photo gallery, documents, and links.',
      initialFolderId: initialFolderId,
    );
  }
}
