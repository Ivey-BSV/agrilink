import 'dart:typed_data';

import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/shared/models/resource_folder.dart';
import 'package:cap/shared/utils/document_upload_utils.dart';
import 'package:cap/shared/widgets/entity_shared_files_config.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SharedDocumentUploadTarget {
  const SharedDocumentUploadTarget({
    required this.storageBucket,
    required this.documentsTable,
    required this.consentDialogTitle,
    required this.consentDialogBody,
    required this.uploadSuccessMessage,
    this.entityIdColumn,
    this.entityId,
    this.folderId,
    this.legacyWorkshopId,
    this.uploadSuccessMessageWhenStaff,
    this.publishImmediately = false,
  });

  final String storageBucket;
  final String documentsTable;
  final String consentDialogTitle;
  final String consentDialogBody;
  final String uploadSuccessMessage;
  final String? uploadSuccessMessageWhenStaff;
  final String? entityIdColumn;
  final String? entityId;
  final String? folderId;
  final String? legacyWorkshopId;
  /// When true, uploads are immediately visible to everyone (no admin review).
  final bool publishImmediately;

  factory SharedDocumentUploadTarget.fromEntityConfig(
    EntitySharedFilesConfig config,
  ) {
    return SharedDocumentUploadTarget(
      storageBucket: config.storageBucket,
      documentsTable: config.documentsTable,
      entityIdColumn: config.entityIdColumn,
      entityId: config.entityId,
      consentDialogTitle: config.consentDialogTitle,
      consentDialogBody: config.consentDialogBody,
      uploadSuccessMessage: config.uploadSuccessMessage,
    );
  }

  static SharedDocumentUploadTarget forResourceFolder({
    required ResourceScope scope,
    required String folderId,
    String? legacyWorkshopId,
  }) {
    if (scope == ResourceScope.repository) {
      return SharedDocumentUploadTarget(
        storageBucket: 'knowledge-repository',
        documentsTable: 'knowledge_repository_documents',
        folderId: folderId,
        publishImmediately: true,
        consentDialogTitle: 'Share file',
        consentDialogBody:
            'This file will be visible to all members in this folder.',
        uploadSuccessMessage: 'File uploaded.',
      );
    }
    return SharedDocumentUploadTarget(
      storageBucket: 'workshop-repository',
      documentsTable: 'workshop_documents',
      folderId: folderId,
      legacyWorkshopId: legacyWorkshopId,
      entityIdColumn: legacyWorkshopId != null ? 'workshop_id' : null,
      entityId: legacyWorkshopId,
      publishImmediately: true,
      consentDialogTitle: 'Share file',
      consentDialogBody:
          'This file will be visible to all members in this folder.',
      uploadSuccessMessage: 'File uploaded.',
    );
  }

  static const knowledgeRepository = SharedDocumentUploadTarget(
    storageBucket: 'knowledge-repository',
    documentsTable: 'knowledge_repository_documents',
    consentDialogTitle: 'Share with admins for review',
    consentDialogBody:
        'Uploads are reviewed by program staff before they appear in the shared library for other members.',
    uploadSuccessMessage: 'Upload submitted for admin review.',
    uploadSuccessMessageWhenStaff: 'Document published.',
  );

  String buildStoragePath(String userId, String safeName) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    if (folderId != null && folderId!.isNotEmpty) {
      return '$folderId/$userId/${timestamp}_$safeName';
    }
    if (entityId != null && entityId!.isNotEmpty) {
      return '$entityId/$userId/${timestamp}_$safeName';
    }
    return '$userId/${timestamp}_$safeName';
  }

  String successMessageFor(bool isStaff) {
    if (isStaff && uploadSuccessMessageWhenStaff != null) {
      return uploadSuccessMessageWhenStaff!;
    }
    return uploadSuccessMessage;
  }

  Map<String, dynamic> buildInsertRow({
    required String userId,
    required String title,
    required String rawName,
    required String publicUrl,
    required String mime,
    required bool isStaff,
  }) {
    final row = <String, dynamic>{
      'user_id': userId,
      'title': title,
      'file_name': rawName,
      'file_url': publicUrl,
      'mime_type': mime,
      'approval_status':
          (publishImmediately || isStaff) ? 'approved' : 'pending',
      'consent_agreed_at': (publishImmediately || isStaff)
          ? null
          : DateTime.now().toUtc().toIso8601String(),
      'visibility_rules': <String, dynamic>{},
    };
    if (entityIdColumn != null &&
        entityId != null &&
        entityIdColumn!.isNotEmpty) {
      row[entityIdColumn!] = entityId;
    }
    if (folderId != null && folderId!.isNotEmpty) {
      row['folder_id'] = folderId;
    }
    return row;
  }
}

Future<void> showSharedDocumentUploadSheet(
  BuildContext context, {
  required void Function(String userId) onPickFiles,
  required void Function(String userId) onPickGallery,
  String signInRequiredMessage = 'Sign in to upload files.',
}) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(signInRequiredMessage),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.folder_open, color: AppTheme.primaryGreen),
              title: const Text('Files'),
              subtitle: const Text('PDFs, documents, and other files'),
              onTap: () {
                Navigator.pop(ctx);
                onPickFiles(user.id);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: AppTheme.primaryGreen),
              title: const Text('Photos'),
              subtitle: const Text('Pictures from your gallery'),
              onTap: () {
                Navigator.pop(ctx);
                onPickGallery(user.id);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

Future<bool> uploadSharedDocumentBytes({
  required BuildContext context,
  required SharedDocumentUploadTarget target,
  required String userId,
  required List<int> bytes,
  required String rawName,
}) async {
  if (bytes.length > DocumentUploadUtils.maxBytes) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('File must be 50 MB or smaller.'),
        backgroundColor: Colors.red,
      ),
    );
    return false;
  }

  final supabase = Supabase.instance.client;
  final title = DocumentUploadUtils.titleFromFileName(rawName);
  final safeName = rawName.replaceAll(RegExp(r'[^\w.\-]'), '_');
  final path = target.buildStoragePath(userId, safeName);

  try {
    final prof = await supabase
        .from('user_profiles')
        .select('account_kind')
        .eq('id', userId)
        .maybeSingle();
    final isStaff =
        prof != null && (prof['account_kind'] as String?) == 'staff';

    if (!isStaff && !target.publishImmediately) {
      if (!context.mounted) return false;
      var consentChecked = false;
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setSt) {
            return AlertDialog(
              title: Text(target.consentDialogTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(target.consentDialogBody),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: consentChecked,
                    onChanged: (v) => setSt(() => consentChecked = v ?? false),
                    title: const Text(
                      'I agree that admins may review this document',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed:
                      consentChecked ? () => Navigator.pop(ctx, true) : null,
                  child: const Text('Upload'),
                ),
              ],
            );
          },
        ),
      );
      if (confirmed != true) {
        return false;
      }
    }

    if (!context.mounted) return false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final ext =
        safeName.contains('.') ? safeName.split('.').last.toLowerCase() : '';
    final mime = DocumentUploadUtils.mimeForExt(ext);
    final data = Uint8List.fromList(bytes);

    await supabase.storage.from(target.storageBucket).uploadBinary(
          path,
          data,
          fileOptions: FileOptions(
            upsert: false,
            contentType: mime,
          ),
        );

    final publicUrl =
        supabase.storage.from(target.storageBucket).getPublicUrl(path);

    await supabase.from(target.documentsTable).insert(
          target.buildInsertRow(
            userId: userId,
            title: title,
            rawName: rawName,
            publicUrl: publicUrl,
            mime: mime,
            isStaff: isStaff,
          ),
        );

    if (context.mounted) Navigator.of(context).pop();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(target.successMessageFor(isStaff)),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
    }
    return true;
  } catch (e) {
    if (context.mounted) Navigator.of(context).pop();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
    return false;
  }
}
