import 'package:flutter/material.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/features/chat/presentation/pages/chat_users_page.dart';
import 'package:cap/features/notifications/presentation/widgets/notification_bell_button.dart';
import 'package:cap/features/community/presentation/data/forum_marketplace_tag_categories.dart';
import 'package:cap/features/events/presentation/pages/events_page.dart';
import 'package:cap/features/community/presentation/widgets/create_post_button.dart';
import 'package:cap/features/community/presentation/widgets/forum_post_card.dart';
import 'package:cap/features/profile/presentation/pages/profile_page.dart';
import 'package:cap/features/search/presentation/pages/search_page.dart';
import 'package:cap/providers/auth_provider.dart';
import 'package:cap/providers/post_provider.dart';
import 'package:cap/providers/profile_provider.dart';
import 'package:cap/shared/models/post.dart';
import 'package:cap/shared/utils/image_url_utils.dart';
import 'package:cap/shared/utils/relative_time_format.dart';
import 'package:cap/shared/widgets/network_circle_avatar.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String _sortBy = 'newest';
  String _contentFilter = 'all';
  final Set<String> _selectedTags = <String>{};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PostProvider>().loadPostsFromSupabase();

      final auth = context.read<AuthProvider>();
      final profileProvider = context.read<ProfileProvider>();
      if (auth.userId != null && profileProvider.currentProfile == null) {
        profileProvider.loadProfile(auth.userId!);
      }
    });
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      _contentFilter == 'all',
                      () => setState(() => _contentFilter = 'all'),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      'Photos',
                      _contentFilter == 'photos',
                      () => setState(() => _contentFilter = 'photos'),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      'Videos',
                      _contentFilter == 'videos',
                      () => setState(() => _contentFilter = 'videos'),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sort, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      _getSortLabel(_sortBy),
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
                onSelected: (value) => setState(() => _sortBy = value),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'newest',
                    child: Row(
                      children: [
                        Text('Newest First'),
                        if (_sortBy == 'newest') ...[
                          const Spacer(),
                          Icon(Icons.check,
                              color: AppTheme.primaryGreen, size: 16),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'oldest',
                    child: Row(
                      children: [
                        Text('Oldest First'),
                        if (_sortBy == 'oldest') ...[
                          const Spacer(),
                          Icon(Icons.check,
                              color: AppTheme.primaryGreen, size: 16),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'most_liked',
                    child: Row(
                      children: [
                        Text('Most Liked'),
                        if (_sortBy == 'most_liked') ...[
                          const Spacer(),
                          Icon(Icons.check,
                              color: AppTheme.primaryGreen, size: 16),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'most_commented',
                    child: Row(
                      children: [
                        Text('Most Comments'),
                        if (_sortBy == 'most_commented') ...[
                          const Spacer(),
                          Icon(Icons.check,
                              color: AppTheme.primaryGreen, size: 16),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
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

  List<Post> _filterAndSortPosts(List<Post> posts) {
    List<Post> filtered = posts.where((post) {
      switch (_contentFilter) {
        case 'photos':
          return post.imageUrl != null && !_isVideoPost(post);
        case 'videos':
          return _isVideoPost(post);
        case 'all':
        default:
          return true;
      }
    }).toList();

    if (_selectedTags.isNotEmpty) {
      filtered = filtered.where((post) {
        if (post.tags.isEmpty) return false;
        for (final String t in post.tags) {
          if (_selectedTags.contains(t)) return true;
        }
        return false;
      }).toList();
    }

    switch (_sortBy) {
      case 'oldest':
        filtered.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        break;
      case 'most_liked':
        filtered.sort((a, b) => b.likes.compareTo(a.likes));
        break;
      case 'most_commented':
        filtered.sort((a, b) => b.comments.compareTo(a.comments));
        break;
      case 'newest':
      default:
        filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        break;
    }

    return filtered;
  }

  bool _isVideoPost(Post post) => isVideoMediaUrl(post.imageUrl);

  String _getSortLabel(String sortBy) {
    switch (sortBy) {
      case 'newest':
        return 'Newest';
      case 'oldest':
        return 'Oldest';
      case 'most_liked':
        return 'Most Liked';
      case 'most_commented':
        return 'Most Comments';
      default:
        return 'Newest';
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
                          setState(() => _selectedTags.clear());
                          setLocalState(() {});
                        },
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${_selectedTags.length} selected',
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
                                  final selected = _selectedTags.contains(tag);
                                  return FilterChip(
                                    label: Text(tag),
                                    selected: selected,
                                    onSelected: (isSelected) {
                                      setState(() {
                                        if (isSelected) {
                                          _selectedTags.add(tag);
                                        } else {
                                          _selectedTags.remove(tag);
                                        }
                                      });
                                      setLocalState(() {});
                                    },
                                    selectedColor: AppTheme.primaryGreen
                                        .withValues(alpha: 0.2),
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
                      onPressed: () {
                        Navigator.pop(context);
                      },
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

  @override
  Widget build(BuildContext context) {
    Widget pageContent = Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundLight,
        elevation: 0,
        leading: _buildUserAvatarLeading(context),
        titleSpacing: 16,
        title: Text(
          'Community',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
        ),
        actions: [
          if (_tabController.index == 0)
            IconButton(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.filter_list, color: Colors.black),
                  if (_selectedTags.isNotEmpty)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen,
                          shape: BoxShape.circle,
                        ),
                        constraints:
                            const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Center(
                          child: Text(
                            _selectedTags.length.toString(),
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
            ),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SearchPage(),
                ),
              );
            },
          ),
          const NotificationBellButton(),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChatUsersPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
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
                Tab(text: 'Forums'),
                Tab(text: 'Events'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildForumsTab(),
                const EventsPage(hideAppBar: true),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton:
          CreatePostButton(currentTabIndex: _tabController.index),
    );

    return pageContent;
  }

  Widget _buildUserAvatarLeading(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profileProvider = context.watch<ProfileProvider>();
    final profile = profileProvider.currentProfile;
    final String? avatarUrl = profile?.avatarUrl;
    final String displayLetter = (profile?.fullName ?? auth.userName ?? 'U')
            .trim()
            .isNotEmpty
        ? (profile?.fullName ?? auth.userName ?? 'U').trim()[0].toUpperCase()
        : 'U';

    if (auth.userId != null &&
        (profile == null || profile.id != auth.userId) &&
        !profileProvider.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        profileProvider.loadProfile(auth.userId!);
      });
    }

    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ProfilePage()),
          );
        },
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppTheme.primaryGradient,
          ),
          child: NetworkCircleAvatar(
            avatarKey: ValueKey('avatar_${auth.userId}_${avatarUrl ?? 'none'}'),
            radius: 18,
            imageUrl: avatarUrl,
            cacheBustKey: auth.userId ?? 'none',
            fallbackLetter: displayLetter,
            fallbackTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForumsTab() {
    return Consumer<PostProvider>(
      builder: (context, postProvider, child) {
        final posts = postProvider.posts;

        if (postProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (posts.isEmpty) {
          return const Center(
            child: Text(
              'No posts yet. Be the first to share!',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        final filteredPosts = _filterAndSortPosts(posts);

        return Column(
          children: [
            _buildFilterBar(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () =>
                    context.read<PostProvider>().loadPostsFromSupabase(),
                child: filteredPosts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.forum_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No posts found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try adjusting your filters',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredPosts.length,
                        itemBuilder: (context, index) {
                          final post = filteredPosts[index];
                          return ForumPostCard(
                            key: ValueKey(post.id),
                            title: post.title,
                            description: post.content,
                            author: post.userName,
                            authorAvatarUrl: post.userAvatar,
                            date: formatFriendlyRelativeTime(post.timestamp),
                            replies: post.comments,
                            likes: post.likes,
                            imageUrl: post.imageUrl,
                            tags: post.tags,
                            location: post.location,
                            isVideo: _isVideoPost(post),
                            onTap: () {
                              context.push('/post/${post.id}');
                            },
                          );
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}
