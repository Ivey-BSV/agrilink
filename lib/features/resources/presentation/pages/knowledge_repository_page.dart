import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/shared/models/resource_folder.dart';
import 'package:cap/shared/widgets/resource_folder_library_page.dart';
import 'package:flutter/material.dart';

class KnowledgeRepositoryPage extends StatelessWidget {
  const KnowledgeRepositoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ResourceFolderLibraryPage(
      scope: ResourceScope.repository,
      title: 'Repository',
      description:
          'Browse shared folders. Each folder has a photo gallery and a document list.',
    );
  }
}
