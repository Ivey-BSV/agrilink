import 'package:flutter/material.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/features/chat/presentation/pages/chat_users_page.dart';
import 'package:cap/features/notifications/presentation/widgets/notification_bell_button.dart';
import 'package:cap/providers/auth_provider.dart';
import 'package:cap/providers/profile_provider.dart';
import 'package:cap/features/profile/presentation/pages/profile_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cap/features/farm_network/presentation/pages/farm_directory_page.dart';
import 'package:cap/features/resources/presentation/pages/knowledge_repository_page.dart';
import 'package:cap/features/resources/presentation/pages/workshops_page.dart';
import 'package:provider/provider.dart';

class ResourcesPage extends StatefulWidget {
  const ResourcesPage({super.key});

  @override
  State<ResourcesPage> createState() => _ResourcesPageState();
}

class _ResourcesPageState extends State<ResourcesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  VoidCallback? _farmDirectoryFilterCallback;
  int _farmDirectoryFilterCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final profileProvider = context.read<ProfileProvider>();
      if (auth.userId != null && profileProvider.currentProfile == null) {
        profileProvider.loadProfile(auth.userId!);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pageContent = Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundLight,
        elevation: 0,
        leading: _buildUserAvatarLeading(context),
        titleSpacing: 16,
        title: Text(
          'Resources',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
        ),
        actions: [
          if (_tabController.index == 1)
            IconButton(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.filter_list, color: Colors.black),
                  if (_farmDirectoryFilterCount > 0)
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
                            _farmDirectoryFilterCount.toString(),
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
              onPressed: () {
                _farmDirectoryFilterCallback?.call();
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
                Tab(text: 'Knowledge'),
                Tab(text: 'Farm Directory'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildKnowledgeResourcesTab(),
                _buildFarmDirectoryTab(),
              ],
            ),
          ),
        ],
      ),
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

    final String imageUrl = avatarUrl != null && avatarUrl.isNotEmpty
        ? (avatarUrl.contains('?')
            ? '$avatarUrl&_u=${auth.userId ?? 'none'}'
            : '$avatarUrl?_u=${auth.userId ?? 'none'}')
        : '';

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
          child: CircleAvatar(
            key: ValueKey('avatar_${auth.userId}_${avatarUrl ?? 'none'}'),
            radius: 18,
            backgroundColor: Colors.transparent,
            backgroundImage: imageUrl.isNotEmpty
                ? CachedNetworkImageProvider(imageUrl)
                : null,
            child: imageUrl.isEmpty
                ? Text(
                    displayLetter,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildFarmDirectoryTab() {
    return FarmDirectoryPage(
      hideAppBar: true,
      onFilterCallbackReady: (callback) {
        setState(() {
          _farmDirectoryFilterCallback = callback;
        });
      },
      onFilterCountChanged: (count) {
        setState(() {
          _farmDirectoryFilterCount = count;
        });
      },
    );
  }

  Widget _buildKnowledgeResourcesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 8),
            child: Text(
              'Knowledge Resources',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
            ),
          ),
          _buildResourceCard(
            icon: Icons.folder_shared,
            title: 'Repository',
            subtitle: 'Knowledge sharing',
            description:
                'Upload and browse shared documents — PDFs, slides, spreadsheets, and more',
            color: AppTheme.primaryGreen,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const KnowledgeRepositoryPage(),
                ),
              );
            },
          ),
          _buildResourceCard(
            icon: Icons.groups,
            title: 'Workshops',
            subtitle: 'Collaborate in sessions',
            description:
                'View upcoming and past sessions, then open each one for details and shared files.',
            color: AppTheme.primaryGreen,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const WorkshopsPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildResourceCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String description,
    required Color color,
    bool isAvailable = true,
    required VoidCallback onTap,
  }) {
    final Color accent = color;
    final bool isMuted = accent == Colors.grey[600];
    final Color startColor =
        isMuted ? Colors.grey[200]! : accent.withOpacity(0.22);
    final Color endColor =
        isMuted ? Colors.grey[100]! : accent.withOpacity(0.05);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [startColor, endColor],
                ),
              ),
            ),
            Positioned(
              right: -20,
              top: -30,
              child: Icon(
                icon,
                size: 140,
                color: accent.withOpacity(0.08),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          icon,
                          color: accent,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isAvailable ? accent : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isAvailable)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Soon',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[800],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
