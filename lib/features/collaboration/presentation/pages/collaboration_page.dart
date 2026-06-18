import 'package:flutter/material.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/features/chat/presentation/pages/chat_users_page.dart';
import 'package:cap/features/notifications/presentation/widgets/notification_bell_button.dart';
import 'package:cap/features/collaboration/presentation/pages/future_visualization_list_page.dart';
import 'package:cap/features/collaboration/presentation/pages/goal_setting_page.dart';
import 'package:cap/features/polls/presentation/pages/polls_list_page.dart';
import 'package:cap/features/collaboration/presentation/pages/reciprocity_ring_page.dart';
import 'package:cap/features/community/presentation/pages/exchange_hub_page.dart';
import 'package:cap/providers/auth_provider.dart';
import 'package:cap/providers/profile_provider.dart';
import 'package:cap/shared/widgets/user_profile_app_bar_avatar.dart';
import 'package:provider/provider.dart';

class CollaborationPage extends StatefulWidget {
  const CollaborationPage({super.key});

  @override
  State<CollaborationPage> createState() => _CollaborationPageState();
}

class _CollaborationPageState extends State<CollaborationPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    Widget pageContent = Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundLight,
        elevation: 0,
        leading: const UserProfileAppBarAvatar(),
        titleSpacing: 16,
        title: Text(
          'Collaboration',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
        ),
        actions: [
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
                Tab(text: 'Tools'),
                Tab(text: 'Exchange Hub'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildToolsTab(),
                const ExchangeHubPage(embeddedInTab: true),
              ],
            ),
          ),
        ],
      ),
    );

    return pageContent;
  }

  Widget _buildToolCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required String description,
    required Color color,
    required bool isAvailable,
    required VoidCallback onTap,
  }) {
    final Color accent = color;
    final Color startColor =
        accent.withValues(alpha: accent == Colors.grey[600] ? 0.14 : 0.22);
    final Color endColor = accent.withValues(alpha: 0.05);
    final bool isMuted = accent == Colors.grey[600];

    final card = Card(
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
                  colors: isMuted
                      ? [Colors.grey[200]!, Colors.grey[100]!]
                      : [startColor, endColor],
                ),
              ),
            ),
            Positioned(
              right: -20,
              top: -30,
              child: Icon(
                icon,
                size: 140,
                color: accent.withValues(alpha: 0.08),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, contentConstraints) {
                  final bool hasBoundedHeight =
                      contentConstraints.hasBoundedHeight &&
                          contentConstraints.maxHeight.isFinite &&
                          contentConstraints.maxHeight > 0;

                  Widget buildDescription() {
                    final descriptionText = Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[800],
                        height: 1.4,
                      ),
                    );

                    if (!hasBoundedHeight) {
                      return descriptionText;
                    }

                    return Expanded(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: descriptionText,
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize:
                        hasBoundedHeight ? MainAxisSize.max : MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.1),
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
                                  label,
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
                                    color: isAvailable
                                        ? AppTheme.primaryGreen
                                        : Colors.grey[600],
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
                                color: Colors.black.withValues(alpha: 0.1),
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
                      buildDescription(),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    return card;
  }

  Widget _buildToolsTab() {
    final tools = [
      {
        'icon': Icons.flag,
        'label': 'Projects',
        'subtitle': 'Set shared objectives',
        'description':
            'Create shared roadmaps, assign owners, and keep the cohort aligned.',
        'color': AppTheme.primaryGreen,
        'available': true,
        'action': () => _navigateToTool('Projects'),
      },
      {
        'icon': Icons.how_to_vote_outlined,
        'label': 'Polls',
        'subtitle': 'Ask the group',
        'description':
            'Run quick questions with one or many answers—good for decisions and pulse checks.',
        'color': AppTheme.primaryGreen,
        'available': true,
        'action': () => _navigateToTool('Polls'),
      },
      {
        'icon': Icons.handshake,
        'label': 'Reciprocity Ring',
        'subtitle': 'Trade asks and offers',
        'description':
            'Trade support, equipment, and time through structured asks and offers.',
        'color': AppTheme.primaryGreen,
        'available': true,
        'action': () => _navigateToTool('Reciprocity Ring'),
      },
      {
        'icon': Icons.visibility,
        'label': 'Future Visualization',
        'subtitle': 'Plan ahead together',
        'description':
            'Prototype the next season together and surface future opportunities.',
        'color': AppTheme.primaryGreen,
        'available': true,
        'action': () => _navigateToTool('Future Visualization'),
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tools.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 8),
            child: Text(
              'Programs & group tools',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
            ),
          );
        }

        final tool = tools[index - 1];
        return _buildToolCard(
          icon: tool['icon'] as IconData,
          label: tool['label'] as String,
          subtitle: tool['subtitle'] as String,
          description: tool['description'] as String,
          color: tool['color'] as Color,
          isAvailable: tool['available'] as bool,
          onTap: tool['action'] as VoidCallback,
        );
      },
    );
  }

  void _navigateToTool(String toolName) {
    if (toolName == 'Projects') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const GoalSettingPage(),
        ),
      );
      return;
    }

    if (toolName == 'Polls') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const PollsListPage(),
        ),
      );
      return;
    }

    if (toolName == 'Future Visualization') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const FutureVisualizationListPage(),
        ),
      );
      return;
    }

    if (toolName == 'Reciprocity Ring') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ReciprocityRingPage(),
        ),
      );
      return;
    }

    Color accent = _getToolColor(toolName);
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.construction,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Coming Soon',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$toolName is in progress. We\'re polishing it for a smooth collaboration experience.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black,
                          side: BorderSide(
                              color: Colors.black.withValues(alpha: 0.12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Close'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Got it'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getToolColor(String toolName) {
    switch (toolName) {
      case 'Projects':
        return AppTheme.primaryGreen;
      case 'Future Visualization':
        return AppTheme.primaryGreen;
      case 'Reciprocity Ring':
        return AppTheme.primaryGreen;
      case 'Polls':
        return AppTheme.primaryGreen;
      case 'Mutual Aid Board':
        return Colors.grey[600]!;
      default:
        return AppTheme.primaryGreen;
    }
  }
}
