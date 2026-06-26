import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/shared/models/resource_folder.dart';
import 'package:cap/shared/utils/file_browse_categories.dart';
import 'package:cap/shared/utils/file_browse_ui_utils.dart';
import 'package:cap/shared/utils/resource_link_utils.dart';
import 'package:cap/shared/utils/shared_document_upload.dart';
import 'package:cap/shared/widgets/file_browse_gallery_grid.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Folder grid + per-folder gallery/documents browse (matches web dashboard).
class ResourceFolderLibraryPage extends StatefulWidget {
  const ResourceFolderLibraryPage({
    super.key,
    required this.scope,
    required this.title,
    required this.description,
    this.initialFolderId,
    this.embedded = false,
  });

  final ResourceScope scope;
  final String title;
  final String description;
  final String? initialFolderId;
  final bool embedded;

  @override
  State<ResourceFolderLibraryPage> createState() =>
      _ResourceFolderLibraryPageState();
}

class _ResourceFolderLibraryPageState extends State<ResourceFolderLibraryPage>
    with SingleTickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<ResourceFolder> _folders = [];
  List<Map<String, dynamic>> _allRows = [];
  String? _selectedFolderId;
  bool _loading = true;
  String? _error;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCount, vsync: this);
    _selectedFolderId = widget.initialFolderId;
    _load();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  String get _documentsTable => widget.scope == ResourceScope.workshop
      ? 'workshop_documents'
      : 'knowledge_repository_documents';

  String get _storageBucket => widget.scope == ResourceScope.workshop
      ? 'workshop-repository'
      : 'knowledge-repository';

  String get _storageUrlMarker => widget.scope == ResourceScope.workshop
      ? '/workshop-repository/'
      : '/knowledge-repository/';

  bool get _supportsLinks => true;

  int get _tabCount => _supportsLinks ? 3 : 2;

  String get _docSelect =>
      'id, folder_id, user_id, title, file_name, file_url, mime_type, created_at, approval_status, consent_agreed_at';

  ResourceFolder? get _selectedFolder {
    if (_selectedFolderId == null) return null;
    for (final f in _folders) {
      if (f.id == _selectedFolderId) return f;
    }
    return null;
  }

  List<Map<String, dynamic>> get _folderRows {
    if (_selectedFolderId == null) return [];
    return _allRows.where((r) => r['folder_id'] == _selectedFolderId).toList();
  }

  FileBrowseSplit _splitRows(List<Map<String, dynamic>> rows) {
    return splitGalleryDocumentsAndLinks(
      rows,
      storageUrlMarker: _storageUrlMarker,
      includeLinks: _supportsLinks,
    );
  }

  Map<String, FolderFileStats> get _folderStats {
    final stats = <String, FolderFileStats>{};
    for (final folder in _folders) {
      stats[folder.id] = const FolderFileStats();
    }
    for (final row in _allRows) {
      final folderId = row['folder_id'] as String?;
      if (folderId == null) continue;
      final current = stats[folderId] ?? const FolderFileStats();
      final isGallery = isGalleryImageFile(
        row['file_name'] as String? ?? '',
        row['mime_type'] as String?,
        row['file_url'] as String?,
        row['title'] as String?,
      );
      final isLink = !isGallery &&
          _supportsLinks &&
          isResourceLinkRow(
            row['file_url'] as String?,
            row['mime_type'] as String?,
            storageUrlMarker: _storageUrlMarker,
          );
      stats[folderId] = FolderFileStats(
        total: current.total + 1,
        gallery: current.gallery + (isGallery ? 1 : 0),
        documents: current.documents + (isGallery || isLink ? 0 : 1),
        links: current.links + (isLink ? 1 : 0),
      );
    }
    return stats;
  }

  void _syncTabToContent(List<Map<String, dynamic>> rows) {
    if (_tabController == null) return;
    if (_supportsLinks) {
      final split = _splitRows(rows);
      if (split.gallery.isNotEmpty) {
        _tabController!.index = 0;
      } else if (split.documents.isNotEmpty) {
        _tabController!.index = 1;
      } else if (split.links.isNotEmpty) {
        _tabController!.index = 2;
      } else {
        _tabController!.index = 0;
      }
      return;
    }
    final split = splitGalleryAndDocuments(rows);
    if (split.gallery.isEmpty && split.documents.isNotEmpty) {
      _tabController!.index = 1;
    } else {
      _tabController!.index = 0;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final folderRes = await _supabase
          .from('resource_folders')
          .select(ResourceFolder.selectColumns)
          .eq('scope', widget.scope.dbValue)
          .order('sort_order', ascending: true)
          .order('name', ascending: true);

      final folders = (folderRes as List)
          .map((e) => ResourceFolder.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();

      final docRes = await _supabase
          .from(_documentsTable)
          .select(_docSelect)
          .order('created_at', ascending: false);

      final raw = List<Map<String, dynamic>>.from(
        (docRes as List).map((e) => Map<String, dynamic>.from(e as Map)),
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

      if (!mounted) return;
      setState(() {
        _folders = folders;
        _allRows = raw;
        _loading = false;
        if (_selectedFolderId != null &&
            !folders.any((f) => f.id == _selectedFolderId)) {
          _selectedFolderId = null;
        }
        if (_selectedFolderId != null) {
          _syncTabToContent(_folderRows);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _openFolder(String folderId) {
    setState(() => _selectedFolderId = folderId);
    _syncTabToContent(_folderRows);
  }

  void _backToFolders() {
    setState(() => _selectedFolderId = null);
  }

  /// True when this screen was pushed already scoped to one folder (e.g. workshop detail).
  bool get _openedDirectlyIntoFolder => widget.initialFolderId != null;

  void _handleBack() {
    if (_selectedFolderId != null) {
      if (_openedDirectlyIntoFolder) {
        Navigator.pop(context);
      } else {
        _backToFolders();
      }
      return;
    }
    Navigator.pop(context);
  }

  bool get _canPopRoute =>
      _selectedFolderId == null || _openedDirectlyIntoFolder;

  Future<void> _showCreateFolderDialog() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New folder'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Folder name',
                  hintText: 'e.g., May 6 Open Lecture',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (created != true || !mounted) return;

    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final name = nameController.text.trim();
    final maxSort = _folders.fold<int>(0, (m, f) => f.sortOrder > m ? f.sortOrder : m);

    try {
      final inserted = await _supabase
          .from('resource_folders')
          .insert({
            'scope': widget.scope.dbValue,
            'name': name,
            'description': descController.text.trim().isEmpty
                ? null
                : descController.text.trim(),
            'sort_order': maxSort + 10,
            'created_by': user.id,
          })
          .select(ResourceFolder.selectColumns)
          .single();

      final folder =
          ResourceFolder.fromMap(Map<String, dynamic>.from(inserted as Map));
      if (!mounted) return;
      setState(() {
        _folders = [..._folders, folder]
          ..sort((a, b) => a.sortOrder != b.sortOrder
              ? a.sortOrder.compareTo(b.sortOrder)
              : a.name.compareTo(b.name));
      });
      _openFolder(folder.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Folder “${folder.name}” created.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create folder: $e')),
      );
    } finally {
      nameController.dispose();
      descController.dispose();
    }
  }

  SharedDocumentUploadTarget get _uploadTarget {
    final folder = _selectedFolder;
    if (folder == null) {
      return SharedDocumentUploadTarget.knowledgeRepository;
    }
    return SharedDocumentUploadTarget.forResourceFolder(
      scope: widget.scope,
      folderId: folder.id,
      legacyWorkshopId: folder.legacyWorkshopId,
    );
  }

  Future<void> _upload() async {
    if (_selectedFolderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Open a folder before uploading.')),
      );
      return;
    }
    await showSharedDocumentUploadSheet(
      context,
      signInRequiredMessage: 'Sign in to upload files.',
      onPickFiles: _pickFromFiles,
      onPickGallery: _pickFromGallery,
      onAddLink: _supportsLinks ? _showAddLinkDialog : null,
    );
  }

  Future<void> _showAddLinkDialog() async {
    if (_selectedFolderId == null) return;

    final user = _supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign in to add links.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final titleController = TextEditingController();
    final urlController = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add link'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title (optional)',
                  hintText: 'e.g., Soil health lecture',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlController,
                autofocus: true,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'URL',
                  hintText: 'https://youtube.com/watch?v=…',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (normalizeResourceLinkUrl(urlController.text) == null) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (saved != true || !mounted) {
      titleController.dispose();
      urlController.dispose();
      return;
    }

    final normalized = normalizeResourceLinkUrl(urlController.text);
    final linkTitle = titleController.text.trim();
    titleController.dispose();
    urlController.dispose();

    if (normalized == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid http or https URL.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final displayTitle =
        linkTitle.isEmpty ? linkDisplayHost(normalized) : linkTitle;

    try {
      await _supabase.from(_documentsTable).insert(
            buildResourceLinkInsertRow(
              folderId: _selectedFolderId!,
              userId: user.id,
              title: displayTitle,
              url: normalized,
            ),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link added.'),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add link: $e')),
      );
    }
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
    if (ok && mounted) await _load();
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
        content: const Text('This removes the file for everyone who can see it.'),
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

    final url = row['file_url'] as String? ?? '';
    final storagePath =
        fileBrowseStoragePathFromPublicUrl(url, _storageUrlMarker);
    final id = row['id'] as String;

    try {
      if (storagePath.isNotEmpty) {
        await _supabase.storage.from(_storageBucket).remove([storagePath]);
      }
      await _supabase.from(_documentsTable).delete().eq('id', id);
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

  Widget _buildFolderGrid() {
    if (_folders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Icon(Icons.create_new_folder_outlined,
              size: 56, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'No folders yet. Tap New folder to organize photos and documents.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey[700], height: 1.5),
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton(
              onPressed: _showCreateFolderDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('Create first folder'),
            ),
          ),
        ],
      );
    }

    final stats = _folderStats;
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.92,
      ),
      itemCount: _folders.length,
      itemBuilder: (context, index) {
        final folder = _folders[index];
        final s = stats[folder.id] ?? const FolderFileStats();
        final meta = s.total == 0
            ? 'Empty'
            : _supportsLinks
                ? '${s.total} item${s.total == 1 ? '' : 's'} · ${s.gallery} photo${s.gallery == 1 ? '' : 's'}${s.links > 0 ? ' · ${s.links} link${s.links == 1 ? '' : 's'}' : ''}'
                : '${s.total} file${s.total == 1 ? '' : 's'} · ${s.gallery} photo${s.gallery == 1 ? '' : 's'}';

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openFolder(folder.id),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📁', style: TextStyle(fontSize: 24, height: 1)),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Text(
                      folder.name,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    meta,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: Colors.grey[600], height: 1.2),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGalleryTab(List<Map<String, dynamic>> gallery) {
    final currentId = _supabase.auth.currentUser?.id;
    if (gallery.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 48, 24, 100),
        children: [
          Icon(Icons.photo_library_outlined, size: 56, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'No photos in this folder yet.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey[700]),
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
    final currentId = _supabase.auth.currentUser?.id;
    if (documents.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 48, 24, 100),
        children: [
          Icon(Icons.description_outlined, size: 56, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'No documents in this folder yet.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey[700]),
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
        if (created != null) dt = DateTime.tryParse(created);
        final dateStr =
            dt != null ? DateFormat.yMMMd().add_jm().format(dt.toLocal()) : '';
        final contributor = fileBrowseContributorLabel(row);
        final isMine = row['user_id'] == currentId;

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  if (isMine)
                    IconButton(
                      icon: Icon(Icons.delete_outline,
                          color: Colors.grey[600], size: 22),
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

  Widget _buildLinksTab(List<Map<String, dynamic>> links) {
    final currentId = _supabase.auth.currentUser?.id;
    if (links.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 48, 24, 100),
        children: [
          Icon(Icons.link, size: 56, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'No links in this folder yet.\nAdd YouTube videos or web pages from Upload → Link.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey[700], height: 1.4),
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: links.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final row = links[index];
        final title = row['title'] as String? ?? 'Untitled';
        final url = row['file_url'] as String? ?? '';
        final created = row['created_at'] as String?;
        DateTime? dt;
        if (created != null) dt = DateTime.tryParse(created);
        final dateStr =
            dt != null ? DateFormat.yMMMd().add_jm().format(dt.toLocal()) : '';
        final contributor = fileBrowseContributorLabel(row);
        final isMine = row['user_id'] == currentId;
        final thumb = youTubeThumbnailUrl(url);
        final host = linkDisplayHost(url);

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: url.isEmpty ? null : () => _openRow(row),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (thumb != null)
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: thumb,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: Colors.grey[200],
                            child: Icon(Icons.play_circle_outline,
                                size: 48, color: Colors.grey[500]),
                          ),
                        ),
                        Center(
                          child: Icon(Icons.play_circle_filled,
                              size: 52, color: Colors.white.withValues(alpha: 0.92)),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    height: 72,
                    color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                    child: Icon(Icons.link, size: 32, color: AppTheme.primaryGreen),
                  ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                              '$host · $contributor · $dateStr',
                              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      if (isMine)
                        IconButton(
                          icon: Icon(Icons.delete_outline,
                              color: Colors.grey[600], size: 22),
                          onPressed: () => _confirmDelete(row),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFolderContents() {
    final folder = _selectedFolder;
    final rows = _folderRows;
    final split = _splitRows(rows);

    if (rows.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Icon(Icons.upload_file, size: 56, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            _supportsLinks
                ? 'This folder is empty. Upload photos or documents, or add links (YouTube, articles).'
                : 'This folder is empty. Upload photos or documents to get started.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey[700], height: 1.5),
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton.icon(
              onPressed: _upload,
              icon: const Icon(Icons.add),
              label: Text(_supportsLinks ? 'Add content' : 'Upload file'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (folder?.description?.trim().isNotEmpty == true)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              folder!.description!.trim(),
              style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.35),
            ),
          ),
        Material(
          color: AppTheme.backgroundLight,
          child: TabBar(
            controller: _tabController,
            labelColor: AppTheme.primaryGreen,
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: AppTheme.primaryGreen,
            tabs: [
              Tab(text: 'Gallery (${split.gallery.length})'),
              Tab(text: 'Documents (${split.documents.length})'),
              if (_supportsLinks) Tab(text: 'Links (${split.links.length})'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildGalleryTab(split.gallery),
              _buildDocumentsTab(split.documents),
              if (_supportsLinks) _buildLinksTab(split.links),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Could not load folders.\n\n'
            'If you just added folders, run the resource_folders migration in Supabase.\n\n$_error',
            style: TextStyle(color: Colors.grey[800], height: 1.4),
          ),
        ],
      );
    }
    if (_selectedFolderId == null) {
      return _buildFolderGrid();
    }
    return _buildFolderContents();
  }

  @override
  Widget build(BuildContext context) {
    final inFolder = _selectedFolderId != null;
    final folderName = _selectedFolder?.name ?? widget.title;

    final body = RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primaryGreen,
      child: _buildBody(),
    );

    if (widget.embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (inFolder)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: _backToFolders,
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('All folders'),
                  ),
                  Expanded(
                    child: Text(
                      folderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    onPressed: inFolder ? _upload : _showCreateFolderDialog,
                    icon: Icon(inFolder ? Icons.upload_file : Icons.create_new_folder_outlined),
                    color: AppTheme.primaryGreen,
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.description,
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _showCreateFolderDialog,
                    icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                    label: const Text('New folder'),
                  ),
                ],
              ),
            ),
          Expanded(child: body),
        ],
      );
    }

    return PopScope(
      canPop: _canPopRoute,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_selectedFolderId != null) _backToFolders();
      },
      child: Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundLight,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: _handleBack,
        ),
        title: Text(
          inFolder ? folderName : widget.title,
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (inFolder)
            IconButton(
              icon: const Icon(Icons.upload_file, color: Colors.black),
              onPressed: _upload,
            )
          else
            IconButton(
              icon: const Icon(Icons.create_new_folder_outlined, color: Colors.black),
              onPressed: _showCreateFolderDialog,
              tooltip: 'New folder',
            ),
        ],
      ),
      floatingActionButton: inFolder
          ? FloatingActionButton.extended(
              onPressed: _upload,
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            )
          : null,
      body: body,
    ),
    );
  }
}

/// Opens the folder library scoped to workshop files, optionally pre-selecting a folder.
Future<void> openWorkshopFolderLibrary(
  BuildContext context, {
  String? initialFolderId,
}) {
  return Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (context) => ResourceFolderLibraryPage(
        scope: ResourceScope.workshop,
        title: 'Workshop Files',
        description:
            'Browse workshop folders. Each folder has a photo gallery, documents, and links.',
        initialFolderId: initialFolderId,
      ),
    ),
  );
}

/// Resolves a folder id from legacy workshop_id (e.g. "3" → folder row).
Future<String?> folderIdForLegacyWorkshop(String workshopId) async {
  try {
    final res = await Supabase.instance.client
        .from('resource_folders')
        .select('id')
        .eq('scope', ResourceScope.workshop.dbValue)
        .eq('legacy_workshop_id', workshopId)
        .maybeSingle();
    if (res == null) return null;
    return res['id'] as String?;
  } catch (_) {
    return null;
  }
}
