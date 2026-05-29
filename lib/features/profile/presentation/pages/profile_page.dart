import 'package:flutter/material.dart';
import 'package:cap/core/animations/app_animations.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/features/edit_profile/presentation/pages/edit_profile_page.dart';
import 'package:cap/features/events/presentation/widgets/event_details_bottom_sheet.dart';
import 'package:cap/features/farm_details/presentation/pages/farm_details_page.dart';
import 'package:cap/features/settings/presentation/pages/settings_page.dart';
import 'package:cap/providers/auth_provider.dart';
import 'package:cap/providers/event_provider.dart';
import 'package:cap/providers/farm_details_provider.dart';
import 'package:cap/providers/post_provider.dart';
import 'package:cap/providers/profile_provider.dart';
import 'package:cap/shared/models/event.dart';
import 'package:cap/shared/widgets/cached_image_widget.dart';
import 'package:cap/shared/utils/event_date_format.dart';
import 'package:cap/shared/utils/farm_display_formatters.dart';
import 'package:cap/shared/widgets/network_circle_avatar.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  Map<String, int> _userStats = {'posts': 0, 'followers': 0, 'following': 0};
  bool _isLoadingStats = true;

  static const List<String> _canonicalCropsOrder = [
    'corn',
    'soybeans',
    'wheat',
    'barley',
    'oats',
    'rice',
    'cotton',
    'potatoes',
    'tomatoes',
    'lettuce',
    'carrots',
    'onions',
    'apples',
    'oranges',
    'grapes',
    'strawberries',
    'blueberries',
    'other',
  ];

  static const List<String> _canonicalLivestockOrder = [
    'cattle',
    'pigs',
    'sheep',
    'goats',
    'chickens',
    'ducks',
    'turkeys',
    'horses',
    'donkeys',
    'rabbits',
    'fish',
    'bees',
    'other',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    _loadUserStats();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfileData();
      _loadUserEvents();
    });
  }

  Future<void> _loadProfileData() async {
    final authProvider = context.read<AuthProvider>();
    final profileProvider = context.read<ProfileProvider>();
    final farmDetailsProvider = context.read<FarmDetailsProvider>();

    if (authProvider.userId != null) {
      await profileProvider.loadProfile(authProvider.userId!);
      await farmDetailsProvider.loadFarmDetails(authProvider.userId!);
    }
  }

  Future<void> _loadUserEvents() async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.userId != null) {
      final eventProvider = context.read<EventProvider>();
      await eventProvider.loadEventsByUser(authProvider.userId!);
    }
  }

  Future<void> _loadUserStats() async {
    final auth = context.read<AuthProvider>();
    final postProvider = context.read<PostProvider>();

    if (auth.userId != null) {
      try {
        final stats = await postProvider.getUserStats(auth.userId!);
        if (!mounted) return;
        setState(() {
          _userStats = stats;
          _isLoadingStats = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoadingStats = false;
        });
      }
    } else {
      if (!mounted) return;
      setState(() {
        _isLoadingStats = false;
      });
    }
  }

  Future<void> _refreshData() async {
    final postProvider = context.read<PostProvider>();
    await Future.wait([
      _loadProfileData(),
      _loadUserStats(),
      postProvider.loadPostsFromSupabase(),
      _loadUserEvents(),
    ]);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserStats();
    });
  }

  String _getInitialLetter(String name) {
    if (name.isEmpty) return 'U';
    return name[0];
  }

  bool _hasNoFarmData(farmDetails) {
    return (farmDetails.farmOverview == null ||
            farmDetails.farmOverview!.trim().isEmpty) &&
        (farmDetails.farmName == null || farmDetails.farmName!.isEmpty) &&
        (farmDetails.farmSize == null || farmDetails.farmSizeUnit == null) &&
        (farmDetails.crops == null || farmDetails.crops!.isEmpty) &&
        (farmDetails.livestock == null || farmDetails.livestock!.isEmpty) &&
        (farmDetails.farmingMethod == null ||
            farmDetails.farmingMethod!.isEmpty) &&
        (farmDetails.soilType == null || farmDetails.soilType!.isEmpty) &&
        (farmDetails.irrigationMethod == null ||
            farmDetails.irrigationMethod!.isEmpty) &&
        (farmDetails.certification == null ||
            farmDetails.certification!.isEmpty) &&
        farmDetails.establishedDate == null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundLight,
        elevation: 0,
        title: AppAnimations.fadeIn(
          child: Text(
            'Profile',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        actions: [
          AppAnimations.scaleIn(
            child: IconButton(
              icon: Icon(Icons.settings, color: AppTheme.textPrimary),
              onPressed: _navigateToSettings,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: AppTheme.primaryGreen,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _buildProfileHeader(),
            ),
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
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final authProvider = context.watch<AuthProvider>();
    final profileProvider = context.watch<ProfileProvider>();
    final user = authProvider;
    final profile = profileProvider.currentProfile;

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
                        color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: NetworkCircleAvatar(
                    radius: 40,
                    imageUrl: profile?.avatarUrl,
                    fallbackLetter: _getInitialLetter(
                        profile?.fullName ?? user.userName ?? 'U'),
                    fallbackTextStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile?.fullName ?? user.userName ?? 'User',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${profile?.displayUsername ?? user.userName?.toLowerCase() ?? 'username'}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (profile?.location != null ||
              profile?.farmType != null ||
              profile?.experienceLevel != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (profile?.location != null &&
                      profile!.location!.isNotEmpty)
                    _buildTag(
                      icon: Icons.location_on,
                      text: profile.location!,
                      color: AppTheme.primaryGreen,
                    ),
                  if (profile?.farmType != null &&
                      profile!.farmType!.isNotEmpty)
                    _buildTag(
                      icon: Icons.agriculture,
                      text: profile.farmType!,
                      color: AppTheme.harvestGold,
                    ),
                  if (profile?.experienceLevel != null &&
                      profile!.experienceLevel!.isNotEmpty)
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
                _buildClickableStat(
                  count: _isLoadingStats
                      ? '...'
                      : _userStats['followers'].toString(),
                  label: 'followers',
                  onTap: () {
                    final authProvider = context.read<AuthProvider>();
                    if (authProvider.userId != null) {
                      context.push(
                        '/followers-following/${authProvider.userId}/true',
                      );
                    }
                  },
                ),
                _buildClickableStat(
                  count: _isLoadingStats
                      ? '...'
                      : _userStats['following'].toString(),
                  label: 'following',
                  onTap: () {
                    final authProvider = context.read<AuthProvider>();
                    if (authProvider.userId != null) {
                      context.push(
                        '/followers-following/${authProvider.userId}/false',
                      );
                    }
                  },
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: _isLoadingStats
                            ? '...'
                            : _userStats['posts'].toString(),
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
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              profile?.bio ??
                  'No bio available. Add one in your profile settings!',
              textAlign: TextAlign.left,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.5,
                fontStyle:
                    profile?.bio == null ? FontStyle.italic : FontStyle.normal,
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
                      onPressed: _showFarmDetailsModal,
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
                child: AppAnimations.scaleIn(
                  child: Container(
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextButton.icon(
                      onPressed: _navigateToEditProfile,
                      icon:
                          const Icon(Icons.edit, color: Colors.white, size: 16),
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
                ),
              ),
            ],
          ),
        ],
      ),
    ));
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
    final auth = context.watch<AuthProvider>();
    final postProvider = context.watch<PostProvider>();
    final posts = postProvider.getPostsByUser(auth.userId ?? '');

    if (postProvider.isLoading) {
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
                    'You haven\'t posted anything yet',
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
    final eventProvider = context.watch<EventProvider>();

    if (authProvider.userId == null) {
      return [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Text('Please log in to view events'),
          ),
        ),
      ];
    }

    final userEvents = eventProvider.getEventsByUser(authProvider.userId!);

    if (eventProvider.isLoading) {
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

    if (userEvents.isEmpty) {
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
                    'You haven\'t created any events',
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
                      color: AppTheme.primaryGreen.withValues(alpha: 0.1),
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
                      color: statusColor.withValues(alpha: 0.1),
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
              const SizedBox(height: 8),
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
                const SizedBox(height: 4),
                Text(
                  event.description,
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
              const SizedBox(height: 4),
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
      await provider.loadEventsByUser(context.read<AuthProvider>().userId!);
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
      await provider.loadEventsByUser(context.read<AuthProvider>().userId!);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to unregister'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsPage(),
      ),
    );
  }

  void _navigateToEditProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EditProfilePage(),
      ),
    );
  }

  void _showFarmDetailsModal() {
    final farmDetailsProvider = context.read<FarmDetailsProvider>();
    final farmDetails = farmDetailsProvider.currentFarmDetails;

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
                      if (farmDetails == null || _hasNoFarmData(farmDetails))
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              'No farm details available. Add them in your profile settings!',
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
                              _capitalizeList(_sortByCanonical(
                                  farmDetails.crops!, _canonicalCropsOrder))),
                        if (farmDetails.livestock != null &&
                            farmDetails.livestock!.isNotEmpty)
                          _buildFarmDetailItem(
                              'Livestock',
                              _capitalizeList(_sortByCanonical(
                                  farmDetails.livestock!,
                                  _canonicalLivestockOrder))),
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
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const FarmDetailsPage(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text('Edit'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[200],
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12),
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
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Close'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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

  String _capitalizeList(List<String> items) {
    final capitalized = items.map((e) {
      if (e.isEmpty) return e;
      return e[0].toUpperCase() + e.substring(1);
    }).join(', ');
    return capitalized;
  }

  Widget _buildBadge(String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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

  List<String> _sortByCanonical(List<String> input, List<String> canonical) {
    final lowerToOriginal = <String, String>{
      for (final i in input) i.toLowerCase(): i,
    };
    final setLower = lowerToOriginal.keys.toSet();
    final sorted = <String>[];
    for (final c in canonical) {
      final lc = c.toLowerCase();
      if (setLower.contains(lc)) {
        sorted.add(lowerToOriginal[lc]!);
      }
    }

    for (final i in input) {
      if (!canonical.map((e) => e.toLowerCase()).contains(i.toLowerCase())) {
        sorted.add(i);
      }
    }
    return sorted;
  }

  Widget _buildTag({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: color,
          ),
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

  Widget _buildClickableStat({
    required String count,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: count,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.harvestGold,
              ),
            ),
            TextSpan(
              text: ' $label ',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
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
