import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cap/core/theme/app_theme.dart';

class FileBrowseGalleryGrid extends StatelessWidget {
  const FileBrowseGalleryGrid({
    super.key,
    required this.items,
    required this.currentUserId,
    required this.onCellTap,
    required this.onDeleteRequest,
    this.shrinkWrap = false,
    this.physics,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 16),
  });

  final List<Map<String, dynamic>> items;
  final String? currentUserId;
  final void Function(Map<String, dynamic> row) onCellTap;
  final void Function(Map<String, dynamic> row) onDeleteRequest;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: shrinkWrap,
      physics: physics,
      padding: padding,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final row = items[index];
        final url = row['file_url'] as String? ?? '';
        final displayTitle = row['title'] as String? ?? 'Photo';
        final isMine = row['user_id'] == currentUserId;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: url.isEmpty ? null : () => onCellTap(row),
            borderRadius: BorderRadius.circular(10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: Colors.grey.shade200,
                    child: url.isEmpty
                        ? Icon(Icons.broken_image_outlined,
                            color: Colors.grey[500])
                        : CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Center(
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.primaryGreen.withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Icon(
                              Icons.broken_image_outlined,
                              color: Colors.grey[500],
                            ),
                          ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.65),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(6, 16, 6, 4),
                        child: Text(
                          displayTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (isMine)
                    Positioned(
                      top: 2,
                      right: 2,
                      child: Material(
                        color: Colors.black45,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => onDeleteRequest(row),
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(
                              Icons.delete_outline,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
