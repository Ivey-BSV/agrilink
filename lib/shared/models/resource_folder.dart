enum ResourceScope { workshop, repository }

extension ResourceScopeValue on ResourceScope {
  String get dbValue => name;
}

class ResourceFolder {
  const ResourceFolder({
    required this.id,
    required this.scope,
    required this.name,
    this.description,
    required this.sortOrder,
    this.legacyWorkshopId,
    this.createdBy,
    required this.createdAt,
  });

  final String id;
  final ResourceScope scope;
  final String name;
  final String? description;
  final int sortOrder;
  final String? legacyWorkshopId;
  final String? createdBy;
  final String createdAt;

  static const selectColumns =
      'id, scope, name, description, sort_order, legacy_workshop_id, created_by, created_at';

  factory ResourceFolder.fromMap(Map<String, dynamic> map) {
    return ResourceFolder(
      id: map['id'] as String,
      scope: map['scope'] == 'workshop'
          ? ResourceScope.workshop
          : ResourceScope.repository,
      name: map['name'] as String? ?? 'Folder',
      description: map['description'] as String?,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      legacyWorkshopId: map['legacy_workshop_id'] as String?,
      createdBy: map['created_by'] as String?,
      createdAt: map['created_at'] as String? ?? '',
    );
  }

  static String buildStoragePath(
    String folderId,
    String userId,
    String fileName,
  ) {
    final safeName = fileName.replaceAll('/', '_');
    return '$folderId/$userId/${DateTime.now().millisecondsSinceEpoch}_$safeName';
  }
}

class FolderFileStats {
  const FolderFileStats({
    this.total = 0,
    this.gallery = 0,
    this.documents = 0,
    this.links = 0,
  });

  final int total;
  final int gallery;
  final int documents;
  final int links;
}
