import 'package:flutter/material.dart';
import 'package:cap/core/animations/app_animations.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/features/edit_profile/presentation/pages/edit_profile_page.dart';
import 'package:cap/features/events/presentation/widgets/event_details_bottom_sheet.dart';
import 'package:cap/features/farm_details/presentation/pages/farm_details_page.dart';
import 'package:cap/providers/auth_provider.dart';
import 'package:cap/providers/event_provider.dart';
import 'package:cap/providers/farm_details_provider.dart';
import 'package:cap/providers/marketplace_provider.dart';
import 'package:cap/providers/post_provider.dart';
import 'package:cap/providers/profile_provider.dart';
import 'package:cap/shared/models/event.dart';
import 'package:cap/shared/models/user_profile.dart';
import 'package:cap/shared/widgets/cached_image_widget.dart';
import 'package:cap/shared/utils/event_date_format.dart';
import 'package:cap/shared/utils/farm_display_formatters.dart';
import 'package:cap/shared/widgets/linkified_text.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class UserProfilePage extends StatefulWidget {
  final String userId;

  const UserProfilePage({super.key, required this.userId});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  UserProfile? _viewedProfile;
  bool _isLoading = true;
  bool _isFollowing = false;
  bool _iBlockedViewedUser = false;
  bool _blockedByViewedUser = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfileData();
      _loadUserEvents();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    final authProvider = context.read<AuthProvider>();
    final profileProvider = context.read<ProfileProvider>();
    final farmDetailsProvider = context.read<FarmDetailsProvider>();

    if (authProvider.userId != null) {
      final profile = await profileProvider.loadUserProfileById(
        widget.userId,
        authProvider.userId!,
      );

      if (profile != null && mounted) {
        setState(() {
          _viewedProfile = profile;
          _isFollowing = profile.isFollowing;
        });
      }

      final blockStatus = await profileProvider.getBlockStatus(widget.userId);
      if (mounted) {
        setState(() {
          _iBlockedViewedUser = blockStatus['iBlocked'] ?? false;
          _blockedByViewedUser = blockStatus['blockedMe'] ?? false;
          _isLoading = false;
        });
      }

      await farmDetailsProvider.loadFarmDetails(widget.userId);
    }
  }

  Future<void> _loadUserEvents() async {
    final eventProvider = context.read<EventProvider>();
    await eventProvider.loadEventsByUser(widget.userId);
  }

  Future<void> _refreshData() async {
    final postProvider = context.read<PostProvider>();
    await Future.wait([
      _loadProfileData(),
      postProvider.loadPostsFromSupabase(),
      _loadUserEvents(),
    ]);
  }

  Future<void> _toggleBlockUser() async {
    final profileProvider = context.read<ProfileProvider>();
    final postProvider = context.read<PostProvider>();
    final marketplaceProvider = context.read<MarketplaceProvider>();
    final wasBlocked = _iBlockedViewedUser;

    final success = wasBlocked
        ? await profileProvider.unblockUser(widget.userId)
        : await profileProvider.blockUser(widget.userId);

    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(profileProvider.error ?? 'Failed to update block status'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await Future.wait([
      postProvider.loadPostsFromSupabase(),
      marketplaceProvider.loadListingsFromSupabase(),
      _loadProfileData(),
    ]);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          wasBlocked ? 'User unblocked' : 'User blocked',
        ),
        backgroundColor: AppTheme.primaryGreen,
      ),
    );
  }

  Future<void> _showBlockConfirmation() async {
    final title = _iBlockedViewedUser ? 'Unblock user?' : 'Block user?';
    final name = _viewedProfile?.fullName ??
        _viewedProfile?.displayUsername ??
        'this user';
    final message = _iBlockedViewedUser
        ? 'You will be able to see each other\'s content again.'
        : 'If you block $name, they won\'t be notified. They will not be able to fully view your profile or your posts, comments, and listings. You also won\'t see their posts, comments, or listings in main pages.';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor:
                  _iBlockedViewedUser ? AppTheme.primaryGreen : Colors.red,
            ),
            child: Text(_iBlockedViewedUser ? 'Unblock' : 'Block'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _toggleBlockUser();
    }
  }

  Future<void> _handleFollowUnfollow() async {
    if (_viewedProfile == null) return;

    final profileProvider = context.read<ProfileProvider>();
    final success = _isFollowing
        ? await profileProvider.unfollowUser(_viewedProfile!.id)
        : await profileProvider.followUser(_viewedProfile!.id);

    if (success && mounted) {
      setState(() {
        _isFollowing = !_isFollowing;
        _viewedProfile = _viewedProfile!.copyWith(isFollowing: _isFollowing);

        if (!_isFollowing) {
          _viewedProfile = _viewedProfile!.copyWith(
            followerCount: (_viewedProfile!.followerCount - 1)
                .clamp(0, double.infinity)
                .toInt(),
          );
        } else {
          _viewedProfile = _viewedProfile!.copyWith(
            followerCount: _viewedProfile!.followerCount + 1,
          );
        }
      });
    }
  }

  void _showUnfollowConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unfollow User'),
        content: Text(
          'Are you sure you want to unfollow ${_viewedProfile?.fullName ?? 'this user'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleFollowUnfollow();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Unfollow'),
          ),
        ],
      ),
    );
  }

  String _getInitialLetter(String name) {
    if (name.isEmpty) return 'U';
    return name[0];
  }

  void _navigateToEditProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EditProfilePage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        appBar: AppBar(
          backgroundColor: AppTheme.backgroundLight,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(
            color: AppTheme.primaryGreen,
          ),
        ),
      );
    }

    if (_viewedProfile == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        appBar: AppBar(
          backgroundColor: AppTheme.backgroundLight,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(
          child: Text('User not found'),
        ),
      );
    }

    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.userId ?? '';

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundLight,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: currentUserId != widget.userId
            ? [
                IconButton(
                  tooltip: _iBlockedViewedUser ? 'Unblock user' : 'Block user',
                  icon: Icon(
                    _iBlockedViewedUser ? Icons.block_flipped : Icons.block,
                    color: _iBlockedViewedUser
                        ? AppTheme.primaryGreen
                        : AppTheme.errorRed,
                  ),
                  onPressed: _showBlockConfirmation,
                ),
              ]
            : null,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: AppTheme.primaryGreen,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _buildProfileHeader(currentUserId == widget.userId),
            ),
            if (_blockedByViewedUser)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_outline,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Profile unavailable',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This user has restricted access to their content.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else ...[
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverAppBarDelegate(
                  TabBar(
                    controller: _tabController,
                    indicatorColor: AppTheme.primaryGreen,
                    labelColor: AppTheme.primaryGreen,
                    unselectedLabelColor: Colors.grey,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    tabs: const [
                      Tab(text: 'Posts'),
                      Tab(text: 'Events'),
                    ],
                  ),
                ),
              ),
              ..._buildTabContentSlivers(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(bool isOwnProfile) {
    final profile = _viewedProfile!;

    return AppAnimations.slideInFromBottom(
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                AppAnimations.scaleIn(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.primaryGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryGreen.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.transparent,
                      backgroundImage: (profile.avatarUrl != null &&
                              profile.avatarUrl!.isNotEmpty)
                          ? CachedNetworkImageProvider(profile.avatarUrl!)
                          : null,
                      child: (profile.avatarUrl == null ||
                              profile.avatarUrl!.isEmpty)
                          ? Text(
                              _getInitialLetter(profile.fullName ??
                                  profile.displayUsername ??
                                  'U'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.fullName ?? 'User',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '@${profile.displayUsername ?? 'username'}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (profile.location != null ||
                profile.farmType != null ||
                profile.experienceLevel != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (profile.location != null &&
                        profile.location!.isNotEmpty)
                      _buildTag(
                        icon: Icons.location_on,
                        text: profile.location!,
                        color: AppTheme.primaryGreen,
                      ),
                    if (profile.farmType != null &&
                        profile.farmType!.isNotEmpty)
                      _buildTag(
                        icon: Icons.agriculture,
                        text: profile.farmType!,
                        color: AppTheme.harvestGold,
                      ),
                    if (profile.experienceLevel != null &&
                        profile.experienceLevel!.isNotEmpty)
                      _buildTag(
                        icon: Icons.star,
                        text: profile.experienceLevel!,
                        color: AppTheme.earthBrown,
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                children: [
                  GestureDetector(
                    onTap: () {
                      context.push(
                        '/followers-following/${widget.userId}/true',
                      );
                    },
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${profile.followerCount}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.harvestGold,
                            ),
                          ),
                          const TextSpan(
                            text: ' followers ',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      context.push(
                        '/followers-following/${widget.userId}/false',
                      );
                    },
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${profile.followingCount}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.harvestGold,
                            ),
                          ),
                          const TextSpan(
                            text: ' following ',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Builder(
                    builder: (context) {
                      final postProvider = context.watch<PostProvider>();
                      final postsCount =
                          postProvider.getPostsByUser(widget.userId).length;
                      return Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '$postsCount',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.harvestGold,
                              ),
                            ),
                            const TextSpan(
                              text: ' posts',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                profile.bio ?? 'No bio available.',
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                  fontStyle:
                      profile.bio == null ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: AppAnimations.scaleIn(
                    child: Container(
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: AppTheme.earthGradient,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextButton.icon(
                        onPressed: _showFarmDetails,
                        icon: const Icon(Icons.agriculture,
                            color: Colors.white, size: 16),
                        label: const Text(
                          'Farm Details',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: isOwnProfile
                      ? AppAnimations.scaleIn(
                          child: Container(
                            height: 32,
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: TextButton.icon(
                              onPressed: _navigateToEditProfile,
                              icon: const Icon(Icons.edit,
                                  color: Colors.white, size: 16),
                              label: const Text(
                                'Edit Profile',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        )
                      : AppAnimations.scaleIn(
                          child: Container(
                            height: 32,
                            decoration: BoxDecoration(
                              gradient: _isFollowing
                                  ? LinearGradient(colors: [
                                      Colors.grey[600]!,
                                      Colors.grey[700]!
                                    ])
                                  : AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: TextButton.icon(
                              onPressed: _isFollowing
                                  ? _showUnfollowConfirmation
                                  : _handleFollowUnfollow,
                              icon: Icon(
                                _isFollowing
                                    ? Icons.person_remove
                                    : Icons.person_add,
                                color: Colors.white,
                                size: 16,
                              ),
                              label: Text(
                                _isFollowing ? 'Following' : 'Follow',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTabContentSlivers() {
    final postsSlivers = _buildPostsTabSlivers();
    final eventsSlivers = _buildEventsTabSlivers();

    return [
      ...postsSlivers.map((sliver) => SliverVisibility(
            visible: _tabController.index == 0,
            maintainState: true,
            maintainAnimation: true,
            sliver: sliver,
          )),
      ...eventsSlivers.map((sliver) => SliverVisibility(
            visible: _tabController.index == 1,
            maintainState: true,
            maintainAnimation: true,
            sliver: sliver,
          )),
    ];
  }

  List<Widget> _buildPostsTabSlivers() {
    final authProvider = context.read<AuthProvider>();
    final isOwnProfile = authProvider.userId == widget.userId;
    final posts = context.watch<PostProvider>().getPostsByUser(widget.userId);

    if (posts.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.grid_view_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No posts yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isOwnProfile
                        ? 'You haven\'t posted anything yet'
                        : 'This user hasn\'t posted anything yet',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.all(2),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final post = posts[index];
              return GestureDetector(
                onTap: () {
                  context.push('/post/${post.id}');
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: post.imageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: post.imageUrl!.startsWith('http')
                              ? CachedImageWidget(
                                  imageUrl: post.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorWidget: Container(
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.image,
                                        color: Colors.grey),
                                  ),
                                )
                              : Image.asset(
                                  post.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.image,
                                          color: Colors.grey),
                                    );
                                  },
                                ),
                        )
                      : Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.image, color: Colors.grey),
                        ),
                ),
              );
            },
            childCount: posts.length,
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildEventsTabSlivers() {
    final authProvider = context.read<AuthProvider>();
    final isOwnProfile = authProvider.userId == widget.userId;
    final eventProvider = context.watch<EventProvider>();

    final userEvents = eventProvider.getEventsByUser(widget.userId);
    final hasLoaded = eventProvider.hasLoadedUserEvents(widget.userId);

    if (eventProvider.isLoading && !hasLoaded) {
      return [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: CircularProgressIndicator(
              color: AppTheme.primaryGreen,
            ),
          ),
        ),
      ];
    }

    if (hasLoaded && userEvents.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_busy,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No events yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isOwnProfile
                        ? 'You haven\'t created any events yet'
                        : 'This user hasn\'t created any events',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverList(
          delegate: SliverChildListDelegate([
            ...userEvents.map((event) => _buildEventCard(event)),
          ]),
        ),
      ),
    ];
  }

  Widget _buildEventCard(Event event) {
    final now = DateTime.now();
    final isUpcoming = event.eventDate.isAfter(now) ||
        (event.eventDate.year == now.year &&
            event.eventDate.month == now.month &&
            event.eventDate.day == now.day);
    final status = isUpcoming ? 'Upcoming' : 'Past';
    final statusColor = isUpcoming ? Colors.orange : Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showEventDetails(event),
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
                      color: AppTheme.primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      event.category,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                event.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (event.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                LinkifiedText(
                  text: event.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    formatEventDateAbbreviated(event.eventDate),
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'at',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      event.time,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      event.location,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.people, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    event.maxAttendees == 0
                        ? '${event.currentAttendees} attendees (Unlimited)'
                        : '${event.currentAttendees}/${event.maxAttendees} attendees',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEventDetails(Event event) {
    final eventProvider = context.read<EventProvider>();
    showEventDetailsFor(
      context,
      event,
      eventProvider: eventProvider,
      onRegisterToggle: (isRegistered) {
        if (isRegistered) {
          _unregisterFromEvent(event, eventProvider);
        } else {
          _registerForEvent(event, eventProvider);
        }
      },
    );
  }

  Future<void> _registerForEvent(Event event, EventProvider provider) async {
    final success = await provider.registerForEvent(event.id);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registered for ${event.title}'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
      await provider.loadEventsByUser(widget.userId);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to register'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _unregisterFromEvent(Event event, EventProvider provider) async {
    final success = await provider.unregisterFromEvent(event.id);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unregistered from ${event.title}'),
          backgroundColor: AppTheme.warningOrange,
        ),
      );
      await provider.loadEventsByUser(widget.userId);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to unregister'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildTag({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showFarmDetails() {
    final authProvider = context.read<AuthProvider>();
    final farmDetailsProvider = context.read<FarmDetailsProvider>();
    final farmDetails = farmDetailsProvider.currentFarmDetails;
    final isOwnProfile = authProvider.userId == widget.userId;

    final bool hasNoFarmData = farmDetails == null ||
        ((farmDetails.farmOverview == null ||
                farmDetails.farmOverview!.trim().isEmpty) &&
            (farmDetails.farmName == null || farmDetails.farmName!.isEmpty) &&
            (farmDetails.farmSize == null ||
                farmDetails.farmSizeUnit == null) &&
            (farmDetails.crops == null || farmDetails.crops!.isEmpty) &&
            (farmDetails.livestock == null || farmDetails.livestock!.isEmpty) &&
            (farmDetails.farmingMethod == null ||
                farmDetails.farmingMethod!.isEmpty) &&
            (farmDetails.soilType == null || farmDetails.soilType!.isEmpty) &&
            (farmDetails.irrigationMethod == null ||
                farmDetails.irrigationMethod!.isEmpty) &&
            (farmDetails.certification == null ||
                farmDetails.certification!.isEmpty) &&
            farmDetails.establishedDate == null);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Farm Details',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (farmDetails == null || hasNoFarmData)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              'No farm details available.',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        )
                      else ...[
                        if (farmDetails.farmScale != null ||
                            farmDetails.certification != null) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (farmDetails.farmScale != null)
                                  _buildBadge(
                                    formatFarmDisplayLabel(
                                        farmDetails.farmScale!),
                                    Colors.blue,
                                  ),
                                if (farmDetails.certification != null &&
                                    farmDetails.certification!.isNotEmpty)
                                  _buildBadge(
                                    formatFarmDisplayLabel(
                                        farmDetails.certification!),
                                    Colors.amber,
                                    icon: Icons.verified,
                                  ),
                              ],
                            ),
                          ),
                        ],
                        if (farmDetails.farmOverview != null &&
                            farmDetails.farmOverview!.trim().isNotEmpty)
                          _buildFarmDetailItem(
                            'Farm overview',
                            farmDetails.farmOverview!.trim(),
                          ),
                        if (farmDetails.farmName != null &&
                            farmDetails.farmName!.isNotEmpty)
                          _buildFarmDetailItem(
                              'Farm Name', farmDetails.farmName!),
                        if (farmDetails.farmSize != null &&
                            farmDetails.farmSizeUnit != null)
                          _buildFarmDetailItem(
                            'Farm Size',
                            '${farmDetails.farmSize} ${farmDetails.farmSizeUnit![0].toUpperCase() + farmDetails.farmSizeUnit!.substring(1)}',
                          ),
                        if (farmDetails.establishedDate != null)
                          _buildFarmDetailItem(
                            'Established Date',
                            formatFarmEstablishedDate(
                                farmDetails.establishedDate!),
                          ),
                        if (farmDetails.farmingMethod != null &&
                            farmDetails.farmingMethod!.isNotEmpty)
                          _buildFarmDetailItem(
                              'Farming Method',
                              formatFarmDisplayLabel(
                                  farmDetails.farmingMethod!)),
                        if (farmDetails.soilType != null &&
                            farmDetails.soilType!.isNotEmpty)
                          _buildFarmDetailItem('Soil Type',
                              formatFarmDisplayLabel(farmDetails.soilType!)),
                        if (farmDetails.irrigationMethod != null &&
                            farmDetails.irrigationMethod!.isNotEmpty)
                          _buildFarmDetailItem(
                              'Irrigation',
                              formatFarmDisplayLabel(
                                  farmDetails.irrigationMethod!)),
                        if (farmDetails.crops != null &&
                            farmDetails.crops!.isNotEmpty)
                          _buildFarmDetailItem(
                            'Primary Crops',
                            farmDetails.crops!
                                .map((c) => c[0].toUpperCase() + c.substring(1))
                                .join(', '),
                          ),
                        if (farmDetails.livestock != null &&
                            farmDetails.livestock!.isNotEmpty)
                          _buildFarmDetailItem(
                            'Livestock',
                            farmDetails.livestock!
                                .map((c) => c[0].toUpperCase() + c.substring(1))
                                .join(', '),
                          ),
                        if (farmDetails.farmType != null &&
                            farmDetails.farmType!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildFarmDetailItem(
                            'Farm Types',
                            farmDetails.farmType!
                                .map((t) => formatFarmTypeLabel(t))
                                .join(', '),
                          ),
                        ],
                        if (farmDetails.activities != null &&
                            farmDetails.activities!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildFarmDetailItem(
                            'Activities',
                            farmDetails.activities!
                                .map((a) => formatFarmDisplayLabel(a))
                                .join(', '),
                          ),
                        ],
                        if (farmDetails.specializations != null &&
                            farmDetails.specializations!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildFarmDetailItem(
                            'Specializations',
                            farmDetails.specializations!
                                .map((s) => formatFarmDisplayLabel(s))
                                .join(', '),
                          ),
                        ],
                        if (farmDetails.farmGoals != null &&
                            farmDetails.farmGoals!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildFarmDetailItem(
                            'Farm Goals',
                            farmDetails.farmGoals!
                                .map((g) => formatFarmDisplayLabel(g))
                                .join(', '),
                          ),
                        ],
                        if (farmDetails.valueAddedProducts != null &&
                            farmDetails.valueAddedProducts!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildFarmDetailItem(
                            'Value-Added Products',
                            farmDetails.valueAddedProducts!
                                .map((v) => formatFarmDisplayLabel(v))
                                .join(', '),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: isOwnProfile
                      ? Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const FarmDetailsPage(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.edit, size: 18),
                                label: const Text('Edit'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey[200],
                                  foregroundColor: Colors.black,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryGreen,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('Close'),
                              ),
                            ),
                          ],
                        )
                      : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Close'),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFarmDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              maxLines: 2,
              softWrap: true,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Text(
              value,
              softWrap: true,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey, width: 0.5),
        ),
      ),
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
