import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/shared/widgets/resource_folder_library_page.dart';
import 'package:flutter/material.dart';

class WorkshopFolderFilesLink extends StatefulWidget {
  const WorkshopFolderFilesLink({super.key, required this.workshopId});

  final String workshopId;

  @override
  State<WorkshopFolderFilesLink> createState() =>
      _WorkshopFolderFilesLinkState();
}

class _WorkshopFolderFilesLinkState extends State<WorkshopFolderFilesLink> {
  String? _folderId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _resolveFolder();
  }

  Future<void> _resolveFolder() async {
    final id = await folderIdForLegacyWorkshop(widget.workshopId);
    if (mounted) {
      setState(() {
        _folderId = id;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.folder_shared, size: 20, color: Colors.grey[700]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Shared materials',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Photos and documents are organized in workshop folders — same as the web dashboard.',
          style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.35),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _loading
                ? null
                : () => openWorkshopFolderLibrary(
                      context,
                      initialFolderId: _folderId,
                    ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.folder_open,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _loading
                              ? 'Loading folder…'
                              : _folderId != null
                                  ? 'Open this session’s folder'
                                  : 'Browse workshop folders',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Gallery for photos · Documents for PDFs and files',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey[500]),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
