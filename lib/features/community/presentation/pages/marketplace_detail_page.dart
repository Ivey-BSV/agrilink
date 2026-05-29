import 'package:flutter/material.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/providers/marketplace_provider.dart';
import 'package:cap/shared/widgets/cached_image_widget.dart';
import 'package:cap/shared/widgets/network_circle_avatar.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class MarketplaceDetailPage extends StatefulWidget {
  final String? listingId;
  final String title;
  final String price;
  final String location;
  final String condition;
  final String? imageUrl;
  final String authorName;
  final String? authorAvatarUrl;
  final String? authorUserId;
  final DateTime postedAt;
  final List<String> tags;
  final String? description;
  final Map<String, String>? specifications;

  const MarketplaceDetailPage({
    super.key,
    this.listingId,
    required this.title,
    required this.price,
    required this.location,
    required this.condition,
    this.imageUrl,
    required this.authorName,
    this.authorAvatarUrl,
    this.authorUserId,
    required this.postedAt,
    this.tags = const [],
    this.description,
    this.specifications,
  });

  @override
  State<MarketplaceDetailPage> createState() => _MarketplaceDetailPageState();
}

class _MarketplaceDetailPageState extends State<MarketplaceDetailPage> {
  bool _isFavorite = false;
  bool _isLoadingFavorite = false;
  int _currentIndex = 0;
  late final List<String> _images;

  @override
  void initState() {
    super.initState();
    _images = widget.imageUrl != null ? [widget.imageUrl!] : [];
    _loadFavoriteStatus();
  }

  Future<void> _loadFavoriteStatus() async {
    if (widget.listingId == null) return;

    setState(() {
      _isLoadingFavorite = true;
    });

    try {
      final provider = Provider.of<MarketplaceProvider>(context, listen: false);
      final isFav = await provider.isFavorite(widget.listingId!);
      if (mounted) {
        setState(() {
          _isFavorite = isFav;
          _isLoadingFavorite = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingFavorite = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Exchange Hub Listing',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (widget.listingId != null)
            IconButton(
              icon: _isLoadingFavorite
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: _isFavorite ? Colors.red : Colors.black,
                    ),
              onPressed: widget.listingId != null ? _toggleFavorite : null,
            ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.black),
            onPressed: _shareListing,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: _openImageViewer,
              child: Container(
                height: 200,
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _images.isEmpty
                      ? const Center(
                          child: Icon(
                            Icons.inventory_2,
                            size: 64,
                            color: AppTheme.primaryGreen,
                          ),
                        )
                      : PageView.builder(
                          itemCount: _images.length,
                          onPageChanged: (index) {
                            setState(() {
                              _currentIndex = index;
                            });
                          },
                          itemBuilder: (context, index) {
                            final imageUrl = _images[index];
                            final isNetworkImage = imageUrl.startsWith('http');
                            return isNetworkImage
                                ? CachedImageWidget(
                                    imageUrl: imageUrl,
                                    fit: BoxFit.cover,
                                    errorWidget: Container(
                                      color: AppTheme.primaryGreen
                                          .withValues(alpha: 0.1),
                                      child: const Center(
                                        child: Icon(
                                          Icons.inventory_2,
                                          size: 48,
                                          color: AppTheme.primaryGreen,
                                        ),
                                      ),
                                    ),
                                  )
                                : Image.asset(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: AppTheme.primaryGreen
                                            .withValues(alpha: 0.1),
                                        child: const Center(
                                          child: Icon(
                                            Icons.inventory_2,
                                            size: 48,
                                            color: AppTheme.primaryGreen,
                                          ),
                                        ),
                                      );
                                    },
                                  );
                          },
                        ),
                ),
              ),
            ),
            if (_images.length > 1)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _images.length,
                    (index) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentIndex == index
                            ? AppTheme.primaryGreen
                            : Colors.grey[300],
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: widget.authorUserId != null
                            ? () {
                                context.push(
                                    '/user-profile/${widget.authorUserId}');
                              }
                            : null,
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppTheme.primaryGradient,
                          ),
                          child: widget.authorAvatarUrl != null &&
                                  widget.authorAvatarUrl!.isNotEmpty &&
                                  !widget.authorAvatarUrl!.startsWith('http')
                              ? CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.transparent,
                                  backgroundImage: AssetImage(
                                    widget.authorAvatarUrl!.trim(),
                                  ),
                                  child: null,
                                )
                              : NetworkCircleAvatar(
                                  radius: 16,
                                  imageUrl: widget.authorAvatarUrl,
                                  fallbackLetter: widget.authorName.isNotEmpty
                                      ? widget.authorName[0].toUpperCase()
                                      : 'U',
                                  fallbackTextStyle: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: widget.authorUserId != null
                              ? () {
                                  context.push(
                                      '/user-profile/${widget.authorUserId}');
                                }
                              : null,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.authorName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: widget.authorUserId != null
                                      ? AppTheme.primaryGreen
                                      : Colors.black,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Row(
                                children: [
                                  Icon(Icons.schedule,
                                      size: 12, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatFriendlyDate(widget.postedAt),
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey[600]),
                                  ),
                                  const SizedBox(width: 10),
                                  Icon(Icons.location_on_outlined,
                                      size: 12, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      widget.location,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600]),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildPriceBadge(widget.price),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (widget.tags.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.tags
                          .map((t) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(t,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                              ))
                          .toList(),
                    ),
                  if (widget.tags.isNotEmpty) const SizedBox(height: 8),
                  if (widget.description != null ||
                      _getProductDescription(widget.title).isNotEmpty)
                    _buildDescriptionSection(),
                  if (widget.description != null ||
                      _getProductDescription(widget.title).isNotEmpty)
                    const SizedBox(height: 16),
                  if ((widget.specifications != null &&
                          widget.specifications!.isNotEmpty) ||
                      _getProductSpecifications(widget.title).isNotEmpty)
                    _buildSpecificationsSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Description',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          widget.description ?? _getProductDescription(widget.title),
          style: TextStyle(fontSize: 14, height: 1.5, color: Colors.grey[700]),
        ),
      ],
    );
  }

  Widget _buildSpecificationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Specifications',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 1,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: widget.specifications != null &&
                      widget.specifications!.isNotEmpty
                  ? widget.specifications!.entries.map((entry) {
                      return _buildSpecificationItem(entry.key, entry.value);
                    }).toList()
                  : _getProductSpecifications(widget.title),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpecificationItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleFavorite() async {
    if (widget.listingId == null) return;

    setState(() {
      _isLoadingFavorite = true;
    });

    try {
      final provider = Provider.of<MarketplaceProvider>(context, listen: false);
      await provider.toggleFavorite(widget.listingId!);

      if (mounted) {
        setState(() {
          _isFavorite = !_isFavorite;
          _isLoadingFavorite = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isFavorite ? 'Added to favorites!' : 'Removed from favorites',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingFavorite = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update favorite: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _shareListing() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Sharing listing...')));
  }

  void _openImageViewer() {
    if (_images.isEmpty) return;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      pageBuilder: (context, animation, secondaryAnimation) {
        return SafeArea(
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: InteractiveViewer(
                          minScale: 0.8,
                          maxScale: 4,
                          child: _images[_currentIndex].startsWith('http')
                              ? CachedImageWidget(
                                  imageUrl: _images[_currentIndex],
                                  fit: BoxFit.contain,
                                )
                              : Image.asset(
                                  _images[_currentIndex],
                                  fit: BoxFit.contain,
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Text(
                          'Close',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1.0).animate(animation),
            child: child,
          ),
        );
      },
    );
  }

  String _formatFriendlyDate(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    if (difference.inDays > 0) return '${difference.inDays}d ago';
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    return 'Just now';
  }

  Widget _buildPriceBadge(String price) {
    final isFree = price.trim().toLowerCase() == 'free';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isFree
            ? Colors.green.withValues(alpha: 0.1)
            : AppTheme.primaryGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isFree ? Colors.green : AppTheme.primaryGreen, width: 1),
      ),
      child: Text(
        price,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: isFree ? Colors.green[700] : AppTheme.primaryGreen,
        ),
      ),
    );
  }

  String _getProductDescription(String title) {
    return 'Quality agricultural product available for purchase. Contact seller for more details.';
  }

  List<Widget> _getProductSpecifications(String title) {
    return [
      _buildSpecificationItem('Type', 'Agricultural Product'),
      _buildSpecificationItem('Condition', 'Good'),
      _buildSpecificationItem('Available', 'Yes'),
    ];
  }
}
