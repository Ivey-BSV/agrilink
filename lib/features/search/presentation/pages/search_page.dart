import 'package:flutter/material.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/features/community/presentation/pages/marketplace_detail_page.dart';
import 'package:cap/features/post/presentation/pages/post_detail_page.dart';
import 'package:cap/providers/auth_provider.dart';
import 'package:cap/providers/marketplace_provider.dart';
import 'package:cap/providers/post_provider.dart';
import 'package:cap/shared/models/marketplace_listing.dart';
import 'package:cap/shared/models/post.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;

  List<Post> _postResults = [];
  List<MarketplaceListing> _marketplaceResults = [];
  String? _searchError;
  List<String> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadRecentSearches();
  }

  Future<void> _loadRecentSearches() async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.userId == null) return;

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('search_history')
          .select('search_query')
          .eq('user_id', authProvider.userId!)
          .order('created_at', ascending: false);

      final searches =
          (response as List).map((r) => r['search_query'] as String).toList();

      final uniqueSearches = <String>[];
      for (final search in searches) {
        if (!uniqueSearches.contains(search)) {
          uniqueSearches.add(search);
        }
      }

      setState(() {
        _recentSearches = uniqueSearches;
      });
    } catch (e) {}
  }

  Future<void> _saveSearch(String query) async {
    if (query.isEmpty || query.trim().isEmpty) return;

    final authProvider = context.read<AuthProvider>();
    if (authProvider.userId == null) return;

    try {
      final supabase = Supabase.instance.client;
      final trimmedQuery = query.trim();

      await supabase
          .from('search_history')
          .delete()
          .eq('user_id', authProvider.userId!)
          .eq('search_query', trimmedQuery);

      await supabase.from('search_history').insert({
        'user_id': authProvider.userId!,
        'search_query': trimmedQuery,
        'search_category': 'Posts & Marketplace',
      });

      _loadRecentSearches();
    } catch (e) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
    });
    if (value.isNotEmpty) {
      _performSearch();
    } else {
      setState(() {
        _postResults = [];
        _marketplaceResults = [];
      });
    }
  }

  void _clearSearch() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _postResults = [];
      _marketplaceResults = [];
      _searchError = null;
    });
  }

  Future<void> _performSearch() async {
    if (_searchQuery.isEmpty || _searchQuery.isEmpty) {
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    try {
      final postProvider = context.read<PostProvider>();
      final marketplaceProvider = context.read<MarketplaceProvider>();

      await Future.wait([
        postProvider.loadPostsFromSupabase(),
        marketplaceProvider.loadListingsFromSupabase(),
      ]);

      final query = _searchQuery.toLowerCase();

      _postResults = postProvider.posts.where((post) {
        return post.title.toLowerCase().contains(query) ||
            post.content.toLowerCase().contains(query) ||
            (post.tags.any((tag) => tag.toLowerCase().contains(query)));
      }).toList();

      _marketplaceResults = marketplaceProvider.listings.where((listing) {
        return listing.title.toLowerCase().contains(query) ||
            listing.description.toLowerCase().contains(query) ||
            (listing.tags.any((tag) => tag.toLowerCase().contains(query))) ||
            (listing.condition?.toLowerCase().contains(query) ?? false);
      }).toList();
    } catch (e) {
      setState(() {
        _searchError = 'Error searching: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isSearching = false;
      });
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
          'Search',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        actions: const [],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search posts and listings...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearSearch,
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primaryGreen),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              onChanged: _onSearchChanged,
              onSubmitted: (value) => _performSearch(),
            ),
          ),
          if (_searchQuery.isNotEmpty && !_isSearching) ...[
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey, width: 0.5),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppTheme.primaryGreen,
                labelColor: AppTheme.primaryGreen,
                unselectedLabelColor: Colors.grey,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                tabs: const [
                  Tab(text: 'All'),
                  Tab(text: 'Posts'),
                  Tab(text: 'Listings'),
                ],
              ),
            ),
          ],
          Expanded(
            child: _searchQuery.isEmpty
                ? _buildEmptyState()
                : _isSearching
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryGreen,
                        ),
                      )
                    : _searchError != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline,
                                    size: 64, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  _searchError!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    if (_recentSearches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Search for posts and listings',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Start typing to search',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Searches',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              TextButton(
                onPressed: _clearAllRecentSearches,
                child: const Text(
                  'Clear All',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._recentSearches.map((search) => ListTile(
                leading: const Icon(Icons.history, color: Colors.grey),
                title: Text(search),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => _deleteRecentSearch(search),
                ),
                onTap: () {
                  _searchController.text = search;
                  setState(() {
                    _searchQuery = search;
                  });
                  _performSearch();
                },
              )),
        ],
      ),
    );
  }

  Future<void> _clearAllRecentSearches() async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.userId == null) return;

    try {
      final supabase = Supabase.instance.client;
      await supabase
          .from('search_history')
          .delete()
          .eq('user_id', authProvider.userId!);

      setState(() {
        _recentSearches = [];
      });
    } catch (e) {}
  }

  Future<void> _deleteRecentSearch(String query) async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.userId == null) return;

    try {
      final supabase = Supabase.instance.client;
      await supabase
          .from('search_history')
          .delete()
          .eq('user_id', authProvider.userId!)
          .eq('search_query', query);

      _loadRecentSearches();
    } catch (e) {}
  }

  Widget _buildSearchResults() {
    final postResults = _getPostResults();
    final listingResults = _getListingResults();
    final allResults = [...postResults, ...listingResults];

    if (allResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No results found for "$_searchQuery"',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search terms',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildResultsList(allResults),
        _buildResultsList(postResults),
        _buildResultsList(listingResults),
      ],
    );
  }

  List<Map<String, dynamic>> _getPostResults() {
    return _postResults
        .map((post) => {
              'type': 'post',
              'id': post.id,
              'title': post.title,
              'content': post.content,
              'author': post.userId,
              'date': _formatDate(post.timestamp),
              'post': post,
            })
        .toList();
  }

  List<Map<String, dynamic>> _getListingResults() {
    return _marketplaceResults
        .map((listing) => {
              'type': 'marketplace',
              'id': listing.id,
              'title': listing.title,
              'content': listing.description,
              'price': listing.price,
              'condition': listing.condition,
              'location': listing.location,
              'date': _formatDate(listing.createdAt),
              'listing': listing,
            })
        .toList();
  }

  Widget _buildResultsList(List<Map<String, dynamic>> results) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final result = results[index];
        return _buildSearchResultCard(result);
      },
    );
  }

  Widget _buildSearchResultCard(Map<String, dynamic> result) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _handleResultTap(result),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          _getTypeColor(result['type']).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getTypeLabel(result['type']),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _getTypeColor(result['type']),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (result['date'] != null)
                    Text(
                      result['date'] as String,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result['title'] as String,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        if (result['price'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              result['price'] as String,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (result['content'] != null &&
                  (result['content'] as String).isNotEmpty)
                Text(
                  result['content'] as String,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              if (result['location'] != null || result['condition'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      if (result['location'] != null) ...[
                        Icon(Icons.location_on,
                            size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          result['location'] as String,
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                      if (result['location'] != null &&
                          result['condition'] != null)
                        const SizedBox(width: 12),
                      if (result['condition'] != null)
                        Text(
                          result['condition'] as String,
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleResultTap(Map<String, dynamic> result) {
    if (_searchQuery.isNotEmpty && _searchQuery.trim().isNotEmpty) {
      _saveSearch(_searchQuery);
    }

    final type = result['type'] as String;
    switch (type) {
      case 'post':
        final post = result['post'] as Post;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetailPage(postId: post.id),
          ),
        );
        break;
      case 'marketplace':
        final listing = result['listing'] as MarketplaceListing;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MarketplaceDetailPage(
              listingId: listing.id,
              title: listing.title,
              price: listing.price,
              location: listing.location ?? 'Unknown',
              condition: listing.condition ?? 'Unknown',
              imageUrl:
                  listing.imageUrls.isNotEmpty ? listing.imageUrls.first : null,
              authorName: listing.userName,
              authorAvatarUrl: listing.userAvatar,
              authorUserId: listing.userId,
              postedAt: listing.createdAt,
              tags: listing.tags,
              description: listing.description,
              specifications: listing.specifications,
            ),
          ),
        );
        break;
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'post':
        return 'Post';
      case 'marketplace':
        return 'Listing';
      default:
        return 'Other';
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'post':
        return AppTheme.primaryGreen;
      case 'marketplace':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return DateFormat('MMM d, y').format(date);
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }
}
