import 'package:flutter/material.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/shared/utils/relative_time_format.dart';
import 'package:cap/shared/widgets/image_placeholder.dart';
import 'package:cap/shared/widgets/listing_media_tile.dart';

class MarketplaceCard extends StatelessWidget {
  final String title;
  final String price;
  final String location;
  final String? imageUrl;
  final VoidCallback onTap;
  final DateTime postedAt;
  final String authorName;
  final String? authorAvatarUrl;
  final List<String> tags;

  const MarketplaceCard({
    super.key,
    required this.title,
    required this.price,
    required this.location,
    this.imageUrl,
    required this.onTap,
    required this.postedAt,
    required this.authorName,
    this.authorAvatarUrl,
    this.tags = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 4 / 3,
                      child: Container(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                        child: ListingMediaTile(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: const ImagePlaceholder(
                            borderRadius: 12,
                            icon: Icons.inventory_2,
                          ),
                          errorWidget: const ImagePlaceholder(
                            borderRadius: 12,
                            icon: Icons.inventory_2,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.schedule,
                                size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              formatFriendlyRelativeTime(postedAt),
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              const SizedBox(height: 4),
              _buildPriceBadge(price),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      location,
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceBadge(String price) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryGreen, width: 1),
      ),
      child: Text(
        price,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.primaryGreen,
        ),
      ),
    );
  }
}
