import 'package:cap/shared/widgets/entity_shared_files_config.dart';
import 'package:cap/shared/widgets/entity_shared_files_section.dart';
import 'package:flutter/material.dart';

class GoalSharedFilesSection extends StatelessWidget {
  const GoalSharedFilesSection({
    super.key,
    required this.goalId,
    required this.canUpload,
  });

  final String goalId;
  final bool canUpload;

  @override
  Widget build(BuildContext context) {
    return EntitySharedFilesSection(
      config: EntitySharedFilesConfig.goal(
        goalId: goalId,
        canUpload: canUpload,
      ),
    );
  }
}
