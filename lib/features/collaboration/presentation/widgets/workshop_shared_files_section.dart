import 'package:cap/shared/widgets/entity_shared_files_config.dart';
import 'package:cap/shared/widgets/entity_shared_files_section.dart';
import 'package:flutter/material.dart';

class WorkshopSharedFilesSection extends StatelessWidget {
  const WorkshopSharedFilesSection({
    super.key,
    required this.workshopId,
  });

  final String workshopId;

  @override
  Widget build(BuildContext context) {
    return EntitySharedFilesSection(
      config: EntitySharedFilesConfig.workshop(workshopId: workshopId),
    );
  }
}
