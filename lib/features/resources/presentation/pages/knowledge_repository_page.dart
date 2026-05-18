import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/shared/utils/file_browse_categories.dart';
import 'package:cap/shared/utils/file_browse_ui_utils.dart';
import 'package:cap/shared/utils/shared_document_upload.dart';
import 'package:cap/shared/widgets/file_browse_gallery_grid.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class KnowledgeRepositoryPage extends StatefulWidget {
  const KnowledgeRepositoryPage({super.key});

  @override
  State<KnowledgeRepositoryPage> createState() =>
      _KnowledgeRepositoryPageState();
}

class _KnowledgeRepositoryPageState extends State<KnowledgeRepositoryPage>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _syncTabToContent() {
    final split = splitGalleryAndDocuments(_rows);
    if (split.gallery.isEmpty && split.documents.isNotEmpty) {
      _tabController.index = 1;
    } else {
      _tabController.index = 0;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final supabase = Supabase.instance.client;
      final res = await supabase
          .from('knowledge_repository_documents')
          .select(
            'id, user_id, title, file_name, file_url, mime_type, created_at, approval_status, consent_agreed_at',
          )
          .order('created_at', ascending: false);

      final raw = List<Map<String, dynamic>>.from(
        (res as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );

      final ids = raw.map((e) => e['user_id'] as String).toSet().toList();
      Map<String, Map<String, dynamic>> profileById = {};
      if (ids.isNotEmpty) {
        final profs = await supabase
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
        if (uid != null) {
          r['_profile'] = profileById[uid];
        }
      }

      if (!mounted) return;
      setState(() {
        _rows = raw;
        _loading = false;
        _syncTabToContent();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  static const _uploadTarget = SharedDocumentUploadTarget.knowledgeRepository;

  Future<void> _upload() async {
    await showSharedDocumentUploadSheet(
      context,
      signInRequiredMessage: 'Sign in to upload documents.',
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
        title: const Text('Remove document?'),
        content: const Text(
          'This removes it from the shared repository for everyone.',
        ),
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

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final url = row['file_url'] as String? ?? '';
    final storagePath = fileBrowseStoragePathFromPublicUrl(
      url,
      '/knowledge-repository/',
    );
    final id = row['id'] as String;

    try {
      final supabase = Supabase.instance.client;
      if (storagePath.isNotEmpty) {
        await supabase.storage
            .from('knowledge-repository')
            .remove([storagePath]);
      }
      await supabase
          .from('knowledge_repository_documents')
          .delete()
          .eq('id', id);
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

  Widget _buildGalleryTab(List<Map<String, dynamic>> gallery) {
    final currentId = Supabase.instance.client.auth.currentUser?.id;
    if (gallery.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 48, 24, 100),
        children: [
          Icon(Icons.photo_library_outlined, size: 56, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'No photos in the gallery yet. Images you upload appear here; '
            'PDFs and other files stay under Documents.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
        ],
      );
    }
    return FileBrowseGalleryGrid(
      items: gallery,
      currentUserId: currentId,
      onCellTap: _openRow,
      onDeleteRequest: _confirmDelete,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
    );
  }

  Widget _buildDocumentsTab(List<Map<String, dynamic>> documents) {
    final currentId = Supabase.instance.client.auth.currentUser?.id;
    if (documents.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 48, 24, 100),
        children: [
          Icon(Icons.description_outlined, size: 56, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'No documents in this tab. PDFs, slides, spreadsheets, and other '
            'non-image files show up here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: documents.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final row = documents[index];
        final title = row['title'] as String? ?? 'Untitled';
        final fileName = row['file_name'] as String? ?? 'file';
        final url = row['file_url'] as String? ?? '';
        final created = row['created_at'] as String?;
        DateTime? dt;
        if (created != null) {
          dt = DateTime.tryParse(created);
        }
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
                      color: AppTheme.primaryGreen.withOpacity(0.12),
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final split = splitGalleryAndDocuments(_rows);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundLight,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Repository',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _upload,
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.upload_file),
        label: const Text('Upload'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppTheme.primaryGreen,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(
                        'Could not load repository.\n\n'
                        'If you just added this feature, run the SQL migration '
                        'create_knowledge_repository.sql in Supabase and create the '
                        'storage bucket if needed.\n\n$_error',
                        style: TextStyle(color: Colors.grey[800], height: 1.4),
                      ),
                    ],
                  )
                : _rows.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(24),
                        children: [
                          Icon(Icons.folder_shared,
                              size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'Nothing shared yet.\n'
                            'Upload photos, PDFs, slides, or other files. '
                            'Images appear in Gallery; documents in Documents.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey[700],
                              height: 1.5,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          Material(
                            color: AppTheme.backgroundLight,
                            child: TabBar(
                              controller: _tabController,
                              labelColor: AppTheme.primaryGreen,
                              unselectedLabelColor: Colors.grey[600],
                              indicatorColor: AppTheme.primaryGreen,
                              tabs: [
                                Tab(text: 'Gallery (${split.gallery.length})'),
                                Tab(
                                  text: 'Documents (${split.documents.length})',
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                _buildGalleryTab(split.gallery),
                                _buildDocumentsTab(split.documents),
                              ],
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }
}
