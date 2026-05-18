import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/shared/utils/file_browse_categories.dart';
import 'package:cap/shared/utils/file_browse_ui_utils.dart';
import 'package:cap/shared/utils/shared_document_upload.dart';
import 'package:cap/shared/widgets/entity_shared_files_config.dart';
import 'package:cap/shared/widgets/file_browse_gallery_grid.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EntitySharedFilesSection extends StatefulWidget {
  const EntitySharedFilesSection({
    super.key,
    required this.config,
  });

  final EntitySharedFilesConfig config;

  @override
  State<EntitySharedFilesSection> createState() =>
      _EntitySharedFilesSectionState();
}

class _EntitySharedFilesSectionState extends State<EntitySharedFilesSection> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;
  int _browseSegment = 0;

  EntitySharedFilesConfig get _config => widget.config;

  void _applyBrowseSegmentForRows(List<Map<String, dynamic>> rows) {
    final split = splitGalleryAndDocuments(rows);
    if (split.gallery.isEmpty && split.documents.isNotEmpty) {
      _browseSegment = 1;
    } else {
      _browseSegment = 0;
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _supabase
          .from(_config.documentsTable)
          .select(
            'id, user_id, title, file_name, file_url, mime_type, created_at, approval_status, consent_agreed_at',
          )
          .eq(_config.entityIdColumn, _config.entityId)
          .order('created_at', ascending: false);

      final raw = List<Map<String, dynamic>>.from(
        (res as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );

      final ids = raw.map((e) => e['user_id'] as String).toSet().toList();
      final profileById = <String, Map<String, dynamic>>{};
      if (ids.isNotEmpty) {
        final profs = await _supabase
            .from('user_profiles')
            .select('id, full_name, username')
            .inFilter('id', ids);
        for (final p in profs as List) {
          final m = Map<String, dynamic>.from(p as Map);
          profileById[m['id'] as String] = m;
        }
      }
      for (final r in raw) {
        final uid = r['user_id'] as String?;
        if (uid != null) r['_profile'] = profileById[uid];
      }

      if (mounted) {
        setState(() {
          _rows = raw;
          _loading = false;
          _applyBrowseSegmentForRows(raw);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _showUploadSheet() async {
    if (!_config.canUpload) {
      final denied = _config.uploadDeniedMessage;
      if (denied != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(denied),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    await showSharedDocumentUploadSheet(
      context,
      onPickFiles: _pickFromFiles,
      onPickGallery: _pickFromGallery,
    );
  }

  Future<void> _pickFromFiles(String userId) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not read file. Try a smaller file.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    await _uploadBytes(userId: userId, bytes: bytes, rawName: file.name);
  }

  SharedDocumentUploadTarget get _uploadTarget =>
      SharedDocumentUploadTarget.fromEntityConfig(_config);

  Future<void> _pickFromGallery(String userId) async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (x == null) return;
    final bytes = await x.readAsBytes();
    var rawName = x.name;
    if (rawName.isEmpty) {
      final path = x.path;
      if (path.isNotEmpty) {
        final parts = path.replaceAll('\\', '/').split('/');
        rawName = parts.isNotEmpty ? parts.last : 'photo.jpg';
      } else {
        rawName = 'photo.jpg';
      }
    }
    await _uploadBytes(userId: userId, bytes: bytes, rawName: rawName);
  }

  Future<void> _uploadBytes({
    required String userId,
    required List<int> bytes,
    required String rawName,
  }) async {
    if (!mounted) return;
    final ok = await uploadSharedDocumentBytes(
      context: context,
      target: _uploadTarget,
      userId: userId,
      bytes: bytes,
      rawName: rawName,
    );
    if (ok && mounted) {
      await _load();
    }
  }

  void _openRow(Map<String, dynamic> row) {
    openFileBrowseRow(
      context,
      row,
      onOpenExternalUrl: (url) => launchFileBrowseUrl(context, url),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove file?'),
        content: Text(_config.deleteDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final url = row['file_url'] as String? ?? '';
    final storagePath =
        fileBrowseStoragePathFromPublicUrl(url, _config.storageUrlMarker);
    final id = row['id'] as String;

    try {
      if (storagePath.isNotEmpty) {
        await _supabase.storage
            .from(_config.storageBucket)
            .remove([storagePath]);
      }
      await _supabase.from(_config.documentsTable).delete().eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removed')),
        );
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not remove: $e')),
        );
      }
    }
  }

  Widget _documentCard(Map<String, dynamic> row, String? currentId) {
    final title = row['title'] as String? ?? 'Untitled';
    final fileName = row['file_name'] as String? ?? 'file';
    final url = row['file_url'] as String? ?? '';
    final created = row['created_at'] as String?;
    DateTime? dt;
    if (created != null) dt = DateTime.tryParse(created);
    final dateStr =
        dt != null ? DateFormat.yMMMd().add_jm().format(dt.toLocal()) : '';
    final contributor = fileBrowseContributorLabel(row);
    final isMine = row['user_id'] == currentId;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: url.isEmpty ? null : () => _openRow(row),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  fileBrowseIconForName(fileName),
                  color: AppTheme.primaryGreen,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$contributor · $dateStr',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (isMine)
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: Colors.grey[600],
                    size: 22,
                  ),
                  onPressed: () => _confirmDelete(row),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentId = _supabase.auth.currentUser?.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.folder_shared, size: 20, color: Colors.grey[700]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _config.sectionTitle,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
              ),
            ),
            if (_config.canUpload)
              TextButton.icon(
                onPressed: _loading ? null : _showUploadSheet,
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Add'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryGreen,
                ),
              )
            else if (_config.showViewOnlyWhenCannotUpload)
              Text(
                'View only',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _config.descriptionText,
          style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.35),
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${_config.loadErrorHint}\n$_error',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          )
        else if (_rows.isEmpty)
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.upload_file, color: Colors.grey[500]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _config.emptyStateMessage,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...[
          Builder(
            builder: (context) {
              final split = splitGalleryAndDocuments(_rows);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<int>(
                    segments: [
                      ButtonSegment(
                        value: 0,
                        label: Text('Gallery (${split.gallery.length})'),
                      ),
                      ButtonSegment(
                        value: 1,
                        label: Text('Documents (${split.documents.length})'),
                      ),
                    ],
                    selected: {_browseSegment},
                    onSelectionChanged: (Set<int> selection) {
                      setState(() => _browseSegment = selection.first);
                    },
                  ),
                  const SizedBox(height: 12),
                  if (_browseSegment == 0)
                    split.gallery.isEmpty
                        ? Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Icon(Icons.photo_library_outlined,
                                      color: Colors.grey[500]),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'No photos in Gallery yet. Use Documents '
                                      'for PDFs and files, or tap Add to upload.',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : FileBrowseGalleryGrid(
                            items: split.gallery,
                            currentUserId: currentId,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.zero,
                            onCellTap: _openRow,
                            onDeleteRequest: _confirmDelete,
                          )
                  else if (split.documents.isEmpty)
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.description_outlined,
                                color: Colors.grey[500]),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'No documents yet. PDFs, slides, and other '
                                'non-image files appear here.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final row in split.documents)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _documentCard(row, currentId),
                          ),
                      ],
                    ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}
