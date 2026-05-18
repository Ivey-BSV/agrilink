import 'package:flutter/material.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/shared/widgets/image_placeholder.dart';
import 'package:cap/shared/widgets/cached_image_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ForumPostCard extends StatefulWidget {
  final String title;
  final String description;
  final String author;
  final String? authorAvatarUrl;
  final String date;
  final int replies;
  final int likes;
  final String? imageUrl;
  final List<String>? tags;
  final String? location;
  final bool isVideo;
  final VoidCallback onTap;

  const ForumPostCard({
    super.key,
    required this.title,
    required this.description,
    required this.author,
    this.authorAvatarUrl,
    required this.date,
    required this.replies,
    required this.likes,
    this.imageUrl,
    this.tags,
    this.location,
    this.isVideo = false,
    required this.onTap,
  });

  @override
  State<ForumPostCard> createState() => _ForumPostCardState();
}

class _ForumPostCardState extends State<ForumPostCard> {
  Widget _buildImage(BoxFit fit) {
    if (widget.imageUrl == null) {
      return const ImagePlaceholder(borderRadius: 8);
    }
    if (widget.imageUrl!.startsWith('http')) {
      return CachedImageWidget(
        imageUrl: widget.imageUrl!,
        fit: fit,
        errorWidget: Container(
          color: AppTheme.primaryGreen.withValues(alpha: 0.1),
          child: const Center(
            child: ImagePlaceholder(borderRadius: 8),
          ),
        ),
      );
    } else {
      return Image.asset(
        widget.imageUrl!,
        fit: fit,
        errorBuilder: (context, error, stack) {
          return Container(
            color: AppTheme.primaryGreen.withValues(alpha: 0.1),
            child: const Center(
              child: ImagePlaceholder(borderRadius: 8),
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.primaryGradient,
                    ),
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.transparent,
                      backgroundImage: widget.authorAvatarUrl != null &&
                              widget.authorAvatarUrl!.isNotEmpty
                          ? CachedNetworkImageProvider(widget.authorAvatarUrl!)
                          : null,
                      child: (widget.authorAvatarUrl == null ||
                              widget.authorAvatarUrl!.isEmpty)
                          ? Text(
                              widget.author.isNotEmpty
                                  ? widget.author[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.author,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.date,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                            if (widget.location != null &&
                                widget.location!.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text('•',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[600])),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  widget.location!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (widget.imageUrl != null) ...[
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: _buildImage(BoxFit.cover),
                      ),
                    ),
                    if (widget.isVideo)
                      Positioned.fill(
                        child: Center(
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (widget.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  widget.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[800],
                    height: 1.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              if (widget.tags != null && widget.tags!.isNotEmpty) ...[
                LayoutBuilder(
                  builder: (context, constraints) {
                    const double hPad = 6;
                    const double vPad = 2;
                    const double spacing = 6;
                    final TextStyle baseStyle = TextStyle(
                      color: AppTheme.primaryGreen,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    );

                    double used = 0;
                    final List<Widget> rowChildren = [];
                    int shown = 0;

                    Size measure(String text) {
                      final tp = TextPainter(
                        text: TextSpan(text: text, style: baseStyle),
                        textDirection: TextDirection.ltr,
                        maxLines: 1,
                      )..layout();

                      return Size(tp.width + (hPad * 2) + 2 + 0.5,
                          tp.height + (vPad * 2) + 2);
                    }

                    Widget chip(String label, {bool subtle = false}) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: hPad, vertical: vPad),
                        decoration: BoxDecoration(
                          color: (subtle
                              ? AppTheme.primaryGreen.withValues(alpha: 0.08)
                              : AppTheme.primaryGreen.withValues(alpha: 0.1)),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppTheme.primaryGreen
                                .withValues(alpha: subtle ? 0.25 : 0.3),
                          ),
                        ),
                        child: Text(
                          label,
                          style: baseStyle.copyWith(
                              fontWeight:
                                  subtle ? FontWeight.w600 : FontWeight.w500),
                        ),
                      );
                    }

                    final double availableWidth = constraints.maxWidth - 10;

                    for (int i = 0; i < widget.tags!.length; i++) {
                      final label = '#${widget.tags![i]}';
                      final sz = measure(label);
                      final double candidate =
                          (rowChildren.isEmpty ? 0 : spacing) + sz.width;

                      if (used + candidate < availableWidth) {
                        if (rowChildren.isNotEmpty) {
                          rowChildren.add(const SizedBox(width: spacing));
                        }
                        rowChildren.add(chip(label));
                        used += candidate;
                        shown++;
                      } else {
                        final remaining = widget.tags!.length - shown;
                        if (remaining > 0) {
                          final overflowLabel = '+$remaining';
                          final overSz = measure(overflowLabel);
                          final double overCand =
                              (rowChildren.isEmpty ? 0 : spacing) +
                                  overSz.width;

                          if (used + overCand < availableWidth) {
                            if (rowChildren.isNotEmpty) {
                              rowChildren.add(const SizedBox(width: spacing));
                            }
                            rowChildren.add(chip(overflowLabel, subtle: true));
                          } else {
                            if (rowChildren.isNotEmpty && shown > 0) {
                              rowChildren.removeLast();
                              if (rowChildren.isNotEmpty &&
                                  rowChildren.last is SizedBox) {
                                rowChildren.removeLast();
                              }

                              used = 0;
                              for (int j = 0; j < rowChildren.length; j++) {
                                if (rowChildren[j] is SizedBox) {
                                  used += spacing;
                                } else if (rowChildren[j] is Container) {
                                  final container = rowChildren[j] as Container;
                                  if (container.child is Text) {
                                    final text = container.child as Text;
                                    if (text.data != null) {
                                      final chipSz = measure(text.data!);
                                      used += chipSz.width;
                                    }
                                  }
                                }
                              }

                              final newRemaining =
                                  widget.tags!.length - (shown - 1);
                              final newOverflowLabel = '+$newRemaining';
                              final newOverSz = measure(newOverflowLabel);
                              final double newOverCand =
                                  (rowChildren.isEmpty ? 0 : spacing) +
                                      newOverSz.width;
                              if (used + newOverCand < availableWidth) {
                                if (rowChildren.isNotEmpty) {
                                  rowChildren
                                      .add(const SizedBox(width: spacing));
                                }
                                rowChildren
                                    .add(chip(newOverflowLabel, subtle: true));
                              }
                            }
                          }
                        }
                        break;
                      }
                    }

                    return ClipRect(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: rowChildren,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 14,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.likes.toString(),
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 14,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${widget.replies}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
