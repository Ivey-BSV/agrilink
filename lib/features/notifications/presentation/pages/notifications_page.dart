import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/features/collaboration/presentation/pages/goal_detail_page.dart';
import 'package:cap/features/polls/presentation/pages/poll_detail_page.dart';
import 'package:cap/features/resources/presentation/pages/knowledge_repository_page.dart';
import 'package:cap/features/resources/presentation/pages/workshops_page.dart';
import 'package:cap/features/settings/presentation/pages/notification_settings_page.dart';
import 'package:cap/providers/notification_provider.dart';
import 'package:cap/services/goal_service.dart';
import 'package:cap/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationService _service = NotificationService();
  final GoalService _goals = GoalService();
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;
  bool _unreadOnly = false;
  String _filter = 'all';

  static const _filters = <String, List<String>>{
    'all': [],
    'feed': ['post_new'],
    'polls': ['poll_new', 'poll_closed'],
    'my_posts': ['post_like', 'post_comment'],
    'social': ['follow_new'],
    'chat': ['chat_message'],
    'projects': ['project_join'],
    'resources': [
      'repository_item_new',
      'repository_folder_new',
      'workshop_item_new',
      'workshop_folder_new',
    ],
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _service.listNotifications();
      if (!mounted) return;
      setState(() {
        _rows = list;
        _loading = false;
      });
      await context.read<NotificationProvider>().refreshUnreadCount();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final types = _filters[_filter] ?? [];
    var list = List<Map<String, dynamic>>.from(_rows);
    if (types.isNotEmpty) {
      list = list
          .where((r) => types.contains(r['type'] as String? ?? ''))
          .toList();
    }
    if (_unreadOnly) {
      list = list.where((r) => r['read_at'] == null).toList();
    }
    return list;
  }

  Future<void> _markRead(Map<String, dynamic> row) async {
    final id = row['id'] as String?;
    if (id == null || row['read_at'] != null) return;
    await _service.markRead(id);
    if (!mounted) return;
    setState(() {
      final i = _rows.indexWhere((e) => e['id'] == id);
      if (i >= 0) {
        _rows[i] = {
          ..._rows[i],
          'read_at': DateTime.now().toUtc().toIso8601String(),
        };
      }
    });
    await context.read<NotificationProvider>().refreshUnreadCount();
  }

  Future<void> _markAllRead() async {
    await _service.markAllRead();
    if (!mounted) return;
    await _load();
  }

  Future<void> _openRow(Map<String, dynamic> row) async {
    await _markRead(row);
    if (!mounted) return;
    final data = Map<String, dynamic>.from(
      row['data'] is Map ? row['data'] as Map : {},
    );
    final type = row['type'] as String? ?? '';

    switch (type) {
      case 'post_new':
      case 'post_like':
      case 'post_comment':
        final postId = data['post_id'] as String?;
        if (postId != null) context.push('/post/$postId');
        break;
      case 'poll_new':
      case 'poll_closed':
        final pollId = data['poll_id'] as String?;
        if (pollId != null) {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PollDetailPage(pollId: pollId),
            ),
          );
        }
        break;
      case 'follow_new':
        final followerId = data['follower_id'] as String?;
        if (followerId != null) context.push('/user-profile/$followerId');
        break;
      case 'chat_message':
        final chatId = data['chat_id'] as String?;
        if (chatId != null) context.push('/chat/$chatId');
        break;
      case 'project_join':
        final goalId = data['goal_id'] as String?;
        if (goalId != null) await _openGoal(goalId);
        break;
      case 'repository_item_new':
      case 'repository_folder_new':
        await _openResourceLibrary(
          isRepository: true,
          folderId: data['folder_id'] as String?,
        );
        break;
      case 'workshop_item_new':
      case 'workshop_folder_new':
        await _openResourceLibrary(
          isRepository: false,
          folderId: data['folder_id'] as String?,
        );
        break;
      default:
        break;
    }
  }

  Future<void> _openResourceLibrary({
    required bool isRepository,
    String? folderId,
  }) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => isRepository
            ? KnowledgeRepositoryPage(initialFolderId: folderId)
            : WorkshopsPage(initialFolderId: folderId),
      ),
    );
  }

  Future<void> _openGoal(String goalId) async {
    try {
      final raw = await _goals.getGoalById(goalId);
      final ui = _goals.formatGoalForUI(raw);
      final uid = Supabase.instance.client.auth.currentUser?.id;
      final participants = List<Map<String, dynamic>>.from(
        raw['community_goal_participants'] ?? [],
      );
      final isJoined = uid != null &&
          participants.any((p) => p['user_id']?.toString() == uid);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => GoalDetailPage(
            goalId: ui['id'] as String,
            title: ui['title'] as String,
            type: 'Community',
            author: ui['author'] as String?,
            deadline: ui['deadline'] as String?,
            progress: ui['progress'] as double?,
            milestones: List<Map<String, dynamic>>.from(
                ui['milestones'] as List? ?? []),
            isJoined: isJoined,
            participants: ui['participants'] as int? ?? 0,
            description: ui['description'] as String?,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open project: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined, color: Colors.black),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const NotificationSettingsPage(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Mark all read',
            icon: const Icon(Icons.done_all, color: Colors.black),
            onPressed:
                _rows.any((r) => r['read_at'] == null) ? _markAllRead : null,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_error!,
                        style: const TextStyle(color: AppTheme.errorRed)),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _filters.keys.map((k) {
                      final selected = _filter == k;
                      return FilterChip(
                        label: Text(_filterLabel(k)),
                        selected: selected,
                        onSelected: (_) => setState(() => _filter = k),
                        selectedColor:
                            AppTheme.primaryGreen.withValues(alpha: 0.2),
                        checkmarkColor: AppTheme.primaryGreen,
                      );
                    }).toList(),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Switch(
                        value: _unreadOnly,
                        onChanged: (v) => setState(() => _unreadOnly = v),
                      ),
                      Text(
                        'Unread only',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: filtered.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 120),
                              Center(
                                child: Text(
                                  'No notifications yet',
                                  style: TextStyle(
                                      fontSize: 16,
                                      color: AppTheme.textSecondary),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final row = filtered[index];
                              final read = row['read_at'] != null;
                              final created = DateTime.tryParse(
                                    row['created_at'] as String? ?? '',
                                  ) ??
                                  DateTime.now();
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => _openRow(row),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: read
                                          ? Colors.white
                                          : AppTheme.primaryGreen
                                              .withValues(alpha: 0.06),
                                    ),
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          _iconFor(
                                              row['type'] as String? ?? ''),
                                          color: AppTheme.primaryGreen,
                                          size: 28,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      row['title'] as String? ??
                                                          '',
                                                      style: TextStyle(
                                                        fontWeight: read
                                                            ? FontWeight.w500
                                                            : FontWeight.w700,
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                  ),
                                                  if (!read)
                                                    Container(
                                                      width: 8,
                                                      height: 8,
                                                      margin:
                                                          const EdgeInsets.only(
                                                              left: 6),
                                                      decoration:
                                                          const BoxDecoration(
                                                        color: AppTheme
                                                            .primaryGreen,
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              if ((row['body'] as String?)
                                                      ?.isNotEmpty ==
                                                  true)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 4),
                                                  child: Text(
                                                    row['body'] as String,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.grey[800],
                                                      height: 1.25,
                                                    ),
                                                    maxLines: 3,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              const SizedBox(height: 6),
                                              Text(
                                                _rel(created),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  String _filterLabel(String key) {
    switch (key) {
      case 'all':
        return 'All';
      case 'feed':
        return 'Feed';
      case 'polls':
        return 'Polls';
      case 'my_posts':
        return 'My posts';
      case 'social':
        return 'Social';
      case 'chat':
        return 'Chat';
      case 'projects':
        return 'Projects';
      case 'resources':
        return 'Resources';
      default:
        return key;
    }
  }

  String _rel(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${t.month}/${t.day}/${t.year}';
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'post_new':
        return Icons.article_outlined;
      case 'poll_new':
      case 'poll_closed':
        return Icons.poll_outlined;
      case 'post_like':
        return Icons.favorite_border;
      case 'post_comment':
        return Icons.mode_comment_outlined;
      case 'follow_new':
        return Icons.person_add_alt_1_outlined;
      case 'chat_message':
        return Icons.chat_bubble_outline;
      case 'project_join':
        return Icons.groups_2_outlined;
      case 'repository_item_new':
      case 'repository_folder_new':
        return Icons.folder_shared_outlined;
      case 'workshop_item_new':
      case 'workshop_folder_new':
        return Icons.groups_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }
}
