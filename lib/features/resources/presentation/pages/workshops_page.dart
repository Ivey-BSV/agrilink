import 'package:cap/shared/models/resource_folder.dart';
import 'package:cap/shared/widgets/resource_folder_library_page.dart';
import 'package:flutter/material.dart';

class WorkshopsPage extends StatelessWidget {
  const WorkshopsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ResourceFolderLibraryPage(
      scope: ResourceScope.workshop,
      title: 'Workshops',
      description:
          'Browse workshop folders. Each folder has a photo gallery, documents, and links.',
    );
  }
}
