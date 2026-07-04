import 'package:flutter/material.dart';
import 'package:cap/shared/models/marketplace_listing.dart';
import 'package:cap/shared/utils/user_block_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MarketplaceProvider extends ChangeNotifier {
  List<MarketplaceListing> _listings = [];
  bool _isLoading = false;
  Set<String> _favoriteListingIds = {};

  List<MarketplaceListing> get listings => _listings;
  bool get isLoading => _isLoading;
  Set<String> get favoriteListingIds => _favoriteListingIds;

  MarketplaceProvider();

  Future<void> loadListingsFromSupabase() async {
    _isLoading = true;
    notifyListeners();

    try {
      final supabase = Supabase.instance.client;
      final excludedUserIds = await blockedUserIdsForCurrentUser(supabase);
      final List<dynamic> rows = await supabase
          .from('marketplace_listings')
          .select(
              'id, user_id, title, price, description, condition, tags, image_urls, specifications, location, created_at')
          .order('created_at', ascending: false)
          .limit(100);

      final filteredRows = rows.where((raw) {
        final row = raw as Map<String, dynamic>;
        final uid = row['user_id'] as String;
        return !excludedUserIds.contains(uid);
      }).toList();

      final Set<String> userIds = filteredRows
          .map((r) => (r as Map<String, dynamic>)['user_id'] as String)
          .toSet();

      Map<String, Map<String, dynamic>> userIdToProfile = {};
      if (userIds.isNotEmpty) {
        final profileRows = await supabase
            .from('user_profiles')
            .select('id, full_name, username, avatar_url, location')
            .inFilter('id', userIds.toList());
        for (final p in profileRows as List<dynamic>) {
          final row = p as Map<String, dynamic>;
          userIdToProfile[row['id'] as String] = row;
        }
      }

      final fetched = filteredRows.map((raw) {
        final row = raw as Map<String, dynamic>;
        final profile = userIdToProfile[row['user_id'] as String];
        final displayName = profile != null
            ? (profile['full_name'] as String?) ??
                (profile['username'] as String?)
            : null;
        final username = displayName ?? 'User';
        final avatarUrl =
            profile != null ? profile['avatar_url'] as String? : null;
        final userLocation =
            profile != null ? profile['location'] as String? : null;

        return MarketplaceListing.fromSupabaseRow(row,
            userName: username, userAvatar: avatarUrl, location: userLocation);
      }).toList();

      _listings = fetched;

      await _loadUserFavorites();
    } catch (e) {
      _listings = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadUserFavorites() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        _favoriteListingIds = {};
        return;
      }

      final List<dynamic> rows = await supabase
          .from('marketplace_favorites')
          .select('listing_id')
          .eq('user_id', user.id);

      _favoriteListingIds = rows
          .map((r) => (r as Map<String, dynamic>)['listing_id'] as String)
          .toSet();
    } catch (e) {
      _favoriteListingIds = {};
    }
  }

  Future<bool> isFavorite(String listingId) async {
    if (_favoriteListingIds.isEmpty &&
        Supabase.instance.client.auth.currentUser != null) {
      await _loadUserFavorites();
    }
    return _favoriteListingIds.contains(listingId);
  }

  Future<void> toggleFavorite(String listingId) async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final isCurrentlyFavorite = _favoriteListingIds.contains(listingId);

      if (isCurrentlyFavorite) {
        await supabase
            .from('marketplace_favorites')
            .delete()
            .eq('user_id', user.id)
            .eq('listing_id', listingId);
        _favoriteListingIds.remove(listingId);
      } else {
        await supabase.from('marketplace_favorites').insert({
          'user_id': user.id,
          'listing_id': listingId,
        });
        _favoriteListingIds.add(listingId);
      }

      notifyListeners();
    } catch (e) {
      throw Exception('Failed to toggle favorite: ${e.toString()}');
    }
  }

  Future<List<String>> getUserFavoriteListingIds() async {
    if (_favoriteListingIds.isEmpty &&
        Supabase.instance.client.auth.currentUser != null) {
      await _loadUserFavorites();
    }
    return _favoriteListingIds.toList();
  }

  Future<void> createListing({
    required String title,
    required String description,
    String? condition,
    required List<String> tags,
    required List<String> imageUrls,
    required Map<String, String> specifications,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final profile = await supabase
          .from('user_profiles')
          .select('full_name, username, avatar_url, location')
          .eq('id', user.id)
          .maybeSingle();

      final displayName = profile != null
          ? ((profile['full_name'] as String?) ??
              (profile['username'] as String?) ??
              (user.email ?? 'User'))
          : (user.email ?? 'User');
      final avatarUrl =
          profile != null ? profile['avatar_url'] as String? : null;
      final userLocation =
          profile != null ? profile['location'] as String? : null;

      await supabase.from('marketplace_listings').insert({
        'user_id': user.id,
        'title': title,
        'price': '',
        'description': description,
        'condition': condition,
        'tags': tags,
        'image_urls': imageUrls,
        'specifications': specifications,
        'location': userLocation,
      });

      final local = MarketplaceListing(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: user.id,
        userName: displayName,
        userAvatar: avatarUrl,
        title: title,
        price: '',
        description: description,
        condition: condition,
        tags: tags,
        imageUrls: imageUrls,
        specifications: specifications,
        location: userLocation,
        createdAt: DateTime.now(),
      );
      _listings.insert(0, local);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearListings() {
    _listings = [];
    _favoriteListingIds.clear();
    _isLoading = false;
    notifyListeners();
  }
}
