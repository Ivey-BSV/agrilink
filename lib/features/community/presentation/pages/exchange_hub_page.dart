import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/features/community/presentation/data/forum_marketplace_tag_categories.dart';
import 'package:cap/features/community/presentation/pages/marketplace_detail_page.dart';
import 'package:cap/features/community/presentation/widgets/marketplace_card.dart';
import 'package:cap/features/marketplace/presentation/pages/create_listing_page.dart';
import 'package:cap/providers/marketplace_provider.dart';
import 'package:cap/shared/models/marketplace_listing.dart';
import 'package:provider/provider.dart';

class ExchangeHubPage extends StatefulWidget {
  const ExchangeHubPage({super.key, this.embeddedInTab = false});

  final bool embeddedInTab;

  @override
  State<ExchangeHubPage> createState() => _ExchangeHubPageState();
}

class _ExchangeHubPageState extends State<ExchangeHubPage> {
  String _marketSortBy = 'newest';
  String _marketFilter = 'all';
  final Set<String> _selectedMarketplaceTags = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MarketplaceProvider>().loadListingsFromSupabase();
    });
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryGreen : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[600],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  double _extractPriceValue(String priceText) {
    if (priceText.trim().toLowerCase() == 'free') return 0.0;
    final regex = RegExp(r'([0-9]+(?:\.[0-9]+)?)');
    final match = regex.firstMatch(priceText.replaceAll(',', ''));
    if (match != null) {
      return double.tryParse(match.group(1)!) ?? double.infinity;
    }
    return double.infinity;
  }

  void _openTagsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.9,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Tags',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() => _selectedMarketplaceTags.clear());
                          setLocalState(() {});
                        },
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${_selectedMarketplaceTags.length} selected',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: kForumAndMarketplaceTagCategories.entries
                            .map((entry) {
                          final categoryName = entry.key;
                          final tags = entry.value;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                categoryName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: tags.map((tag) {
                                  final selected =
                                      _selectedMarketplaceTags.contains(tag);
                                  return FilterChip(
                                    label: Text(tag),
                                    selected: selected,
                                    onSelected: (isSelected) {
                                      setState(() {
                                        if (isSelected) {
                                          _selectedMarketplaceTags.add(tag);
                                        } else {
                                          _selectedMarketplaceTags.remove(tag);
                                        }
                                      });
                                      setLocalState(() {});
                                    },
                                    selectedColor:
                                        AppTheme.primaryGreen.withValues(alpha: 0.2),
                                    checkmarkColor: AppTheme.primaryGreen,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: const VisualDensity(
                                      horizontal: -2,
                                      vertical: -2,
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 24),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final tagButton = IconButton(
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.filter_list, color: Colors.black),
          if (_selectedMarketplaceTags.isNotEmpty)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: AppTheme.primaryGreen,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Center(
                  child: Text(
                    _selectedMarketplaceTags.length.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      onPressed: _openTagsBottomSheet,
    );

    if (widget.embeddedInTab) {
      return AppBar(
        backgroundColor: AppTheme.backgroundLight,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Exchange Hub',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
        ),
        actions: [tagButton],
      );
    }

    return AppBar(
      backgroundColor: AppTheme.backgroundLight,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Exchange Hub',
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),
      ),
      actions: [tagButton],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: _buildAppBar(context),
      body: Consumer<MarketplaceProvider>(
        builder: (context, marketplaceProvider, _) {
          final supabaseItems = marketplaceProvider.listings.map((listing) {
            return {
              'title': listing.title,
              'price': listing.price,
              'location': listing.location ?? 'Unknown',
              'condition': listing.condition ?? '',
              'image':
                  listing.imageUrls.isNotEmpty ? listing.imageUrls.first : null,
              'postedAt': listing.createdAt,
              'authorName': listing.userName,
              'authorAvatarUrl': listing.userAvatar ?? '',
              'tags': listing.tags,
              'listing': listing,
            };
          }).toList();

          List<Map<String, Object?>> filteredItems =
              List<Map<String, Object?>>.from(supabaseItems);

          if (_selectedMarketplaceTags.isNotEmpty) {
            filteredItems = filteredItems.where((m) {
              final tags = m['tags'] as List<String>?;
              if (tags == null || tags.isEmpty) return false;
              for (final String t in tags) {
                if (_selectedMarketplaceTags.contains(t)) return true;
              }
              return false;
            }).toList();
          }

          if (_marketFilter == 'free') {
            filteredItems = filteredItems
                .where((m) =>
                    (m['price'] as String).trim().toLowerCase() == 'free')
                .toList();
          } else if (_marketFilter == 'favourites') {
            final favoriteIds = marketplaceProvider.favoriteListingIds;
            filteredItems = filteredItems.where((m) {
              final listing = m['listing'] as MarketplaceListing?;
              return listing != null && favoriteIds.contains(listing.id);
            }).toList();
          }

          final sortedItems = List<Map<String, Object?>>.from(filteredItems);
          switch (_marketSortBy) {
            case 'oldest':
              sortedItems.sort((a, b) => (a['postedAt'] as DateTime)
                  .compareTo(b['postedAt'] as DateTime));
              break;
            case 'price_low':
              sortedItems.sort((a, b) =>
                  _extractPriceValue(a['price'] as String)
                      .compareTo(_extractPriceValue(b['price'] as String)));
              break;
            case 'price_high':
              sortedItems.sort((a, b) =>
                  _extractPriceValue(b['price'] as String)
                      .compareTo(_extractPriceValue(a['price'] as String)));
              break;
            case 'newest':
            default:
              sortedItems.sort((a, b) => (b['postedAt'] as DateTime)
                  .compareTo(a['postedAt'] as DateTime));
              break;
          }

          return Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[200]!, width: 1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              _buildFilterChip(
                                'All',
                                _marketFilter == 'all',
                                () => setState(() => _marketFilter = 'all'),
                              ),
                              const SizedBox(width: 8),
                              _buildFilterChip(
                                'Free',
                                _marketFilter == 'free',
                                () => setState(() => _marketFilter = 'free'),
                              ),
                              const SizedBox(width: 8),
                              _buildFilterChip(
                                'Favourites',
                                _marketFilter == 'favourites',
                                () => setState(
                                    () => _marketFilter = 'favourites'),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) =>
                              setState(() => _marketSortBy = value),
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'newest',
                              child: Row(children: [
                                const Text('Newest First'),
                                if (_marketSortBy == 'newest') ...[
                                  const Spacer(),
                                  Icon(Icons.check,
                                      color: AppTheme.primaryGreen, size: 16),
                                ]
                              ]),
                            ),
                            PopupMenuItem(
                              value: 'oldest',
                              child: Row(children: [
                                const Text('Oldest First'),
                                if (_marketSortBy == 'oldest') ...[
                                  const Spacer(),
                                  Icon(Icons.check,
                                      color: AppTheme.primaryGreen, size: 16),
                                ]
                              ]),
                            ),
                            const PopupMenuDivider(),
                            PopupMenuItem(
                              value: 'price_low',
                              child: Row(children: [
                                const Text('Price: Low to High'),
                                if (_marketSortBy == 'price_low') ...[
                                  const Spacer(),
                                  Icon(Icons.check,
                                      color: AppTheme.primaryGreen, size: 16),
                                ]
                              ]),
                            ),
                            PopupMenuItem(
                              value: 'price_high',
                              child: Row(children: [
                                const Text('Price: High to Low'),
                                if (_marketSortBy == 'price_high') ...[
                                  const Spacer(),
                                  Icon(Icons.check,
                                      color: AppTheme.primaryGreen, size: 16),
                                ]
                              ]),
                            ),
                          ],
                          icon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.sort, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                _marketSortBy == 'newest'
                                    ? 'Newest'
                                    : _marketSortBy == 'oldest'
                                        ? 'Oldest'
                                        : _marketSortBy == 'price_low'
                                            ? 'Price ↑'
                                            : 'Price ↓',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.keyboard_arrow_down,
                                  color: Colors.grey[600], size: 16),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    await marketplaceProvider.loadListingsFromSupabase();
                  },
                  child: sortedItems.isEmpty
                      ? SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Container(
                            height: MediaQuery.of(context).size.height * 0.5,
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No listings found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : MasonryGridView.count(
                          padding: const EdgeInsets.all(16),
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          itemCount: sortedItems.length,
                          itemBuilder: (context, index) {
                            final m = sortedItems[index];
                            final imageUrl = m['image'] as String?;
                            return MarketplaceCard(
                              title: m['title'] as String,
                              price: m['price'] as String,
                              location: m['location'] as String,
                              condition: m['condition'] as String,
                              imageUrl: imageUrl ?? '',
                              postedAt: m['postedAt'] as DateTime,
                              authorName: m['authorName'] as String,
                              authorAvatarUrl: m['authorAvatarUrl'] as String,
                              tags: (m['tags'] as List<String>),
                              onTap: () {
                                final listing =
                                    m['listing'] as MarketplaceListing?;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MarketplaceDetailPage(
                                      listingId: listing?.id,
                                      title: m['title'] as String,
                                      price: m['price'] as String,
                                      location: m['location'] as String,
                                      condition: m['condition'] as String,
                                      imageUrl: imageUrl,
                                      authorName: m['authorName'] as String,
                                      authorAvatarUrl:
                                          m['authorAvatarUrl'] as String,
                                      authorUserId: listing?.userId,
                                      postedAt: m['postedAt'] as DateTime,
                                      tags: (m['tags'] as List<String>),
                                      description: listing?.description,
                                      specifications: listing?.specifications,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_exchange_hub_create_listing',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateListingPage()),
          ).then((_) {
            if (!context.mounted) return;
            context.read<MarketplaceProvider>().loadListingsFromSupabase();
          });
        },
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}
