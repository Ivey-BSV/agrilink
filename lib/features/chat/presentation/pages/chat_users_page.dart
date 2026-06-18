import 'package:flutter/material.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/features/chat/presentation/pages/chat_detail_page.dart';
import 'package:cap/providers/auth_provider.dart';
import 'package:cap/providers/chat_provider.dart';
import 'package:cap/providers/profile_provider.dart';
import 'package:cap/shared/models/chat.dart';
import 'package:cap/shared/models/user_profile.dart';
import 'package:cap/shared/widgets/network_circle_avatar.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatUserWithFollowDate {
  final UserProfile user;
  final DateTime? followDate;

  ChatUserWithFollowDate({required this.user, this.followDate});
}

class ChatUsersPage extends StatefulWidget {
  const ChatUsersPage({super.key});

  @override
  State<ChatUsersPage> createState() => _ChatUsersPageState();
}

class _ChatUsersPageState extends State<ChatUsersPage>
    with SingleTickerProviderStateMixin {
  List<ChatUserWithFollowDate> _followingUsers = [];
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    final authProvider = context.read<AuthProvider>();
    final profileProvider = context.read<ProfileProvider>();
    final chatProvider = context.read<ChatProvider>();

    if (authProvider.userId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final users = await profileProvider.getFollowing(authProvider.userId!);

      final supabase = Supabase.instance.client;
      final followDatesResponse = await supabase
          .from('follows')
          .select('following_id, created_at')
          .eq('follower_id', authProvider.userId!)
          .order('created_at', ascending: false);

      final followDatesMap = <String, DateTime>{};
      for (final row in followDatesResponse as List<dynamic>) {
        final userId = row['following_id'] as String;
        final createdAt = DateTime.parse(row['created_at'] as String);
        followDatesMap[userId] = createdAt;
      }

      final usersWithFollowDates = users.map((user) {
        return ChatUserWithFollowDate(
          user: user,
          followDate: followDatesMap[user.id],
        );
      }).toList();

      await chatProvider.loadChats();
      await chatProvider.preloadFollowEdgesForUserIds(
        usersWithFollowDates.map((e) => e.user.id).toList(),
      );

      if (mounted) {
        setState(() {
          _followingUsers = usersWithFollowDates;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getInitialLetter(String name) {
    if (name.isEmpty) return 'U';
    return name[0].toUpperCase();
  }

  String _formatTimeAgo(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _openChat(UserProfile user, {bool isFromRequests = false}) async {
    final chatProvider = context.read<ChatProvider>();
    final authProvider = context.read<AuthProvider>();

    if (authProvider.userId == null) return;

    final chat = await chatProvider.getOrCreateChat(user.id);

    if (chat != null && mounted) {
      void Function()? onAccepted;
      if (isFromRequests) {
        onAccepted = () {
          if (mounted && _tabController.index != 0) {
            _tabController.animateTo(0, duration: Duration.zero);
          }
        };
      }

      final shouldNavigateToRequests = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => ChatDetailPage(
            chatId: chat.id,
            participantName: user.fullName ?? user.displayUsername ?? 'User',
            participantAvatarUrl: user.avatarUrl,
            onAccepted: onAccepted,
          ),
        ),
      );

      if (shouldNavigateToRequests == true && mounted) {
        _tabController.animateTo(1,
            duration: const Duration(milliseconds: 200));
      }

      chatProvider.loadChats();
    }
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
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Messages',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryGreen),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundLight,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Messages',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryGreen,
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: AppTheme.primaryGreen,
          tabs: const [
            Tab(text: 'Messages'),
            Tab(text: 'Requests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMessagesTab(),
          _buildMessageRequestsTab(),
        ],
      ),
    );
  }

  Widget _buildMessagesTab() {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        final authProvider = context.read<AuthProvider>();
        if (authProvider.userId == null) {
          return const Center(child: Text('Not authenticated'));
        }

        if (chatProvider.lastLoadError != null) {
          return RefreshIndicator(
            onRefresh: () async {
              await chatProvider.loadChats();
            },
            color: AppTheme.primaryGreen,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.error_outline,
                        size: 48, color: Colors.grey[600]),
                    const SizedBox(height: 12),
                    Text(
                      "Couldn't load conversations",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      chatProvider.lastLoadError!,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => chatProvider.loadChats(),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final regularChats = chatProvider.regularChats;
        final regularChatUserIds = regularChats
            .map((chat) => chat.participants.firstWhere(
                  (id) => id != authProvider.userId,
                ))
            .toSet();

        final filteredUsers = _followingUsers.where((u) {
          return regularChatUserIds.contains(u.user.id) ||
              chatProvider.isMutualFollowWith(u.user.id);
        }).toList();

        final sortedUsers = List<ChatUserWithFollowDate>.from(filteredUsers);
        sortedUsers.sort((a, b) {
          final chatA = chatProvider.chats.firstWhere(
            (chat) =>
                chat.participants.contains(a.user.id) &&
                chat.participants.length == 2,
            orElse: () => Chat(
              id: '',
              participants: [],
              participantNames: [],
              lastMessage: '',
              lastMessageTime: DateTime(1970),
              unreadCount: 0,
              messages: [],
            ),
          );
          final chatB = chatProvider.chats.firstWhere(
            (chat) =>
                chat.participants.contains(b.user.id) &&
                chat.participants.length == 2,
            orElse: () => Chat(
              id: '',
              participants: [],
              participantNames: [],
              lastMessage: '',
              lastMessageTime: DateTime(1970),
              unreadCount: 0,
              messages: [],
            ),
          );

          final hasMessagesA = chatA.messages.isNotEmpty;
          final hasMessagesB = chatB.messages.isNotEmpty;

          if (hasMessagesA && hasMessagesB) {
            return chatB.lastMessageTime.compareTo(chatA.lastMessageTime);
          } else if (hasMessagesA) {
            return -1;
          } else if (hasMessagesB) {
            return 1;
          } else {
            final followDateA = a.followDate ?? DateTime(1970);
            final followDateB = b.followDate ?? DateTime(1970);
            return followDateB.compareTo(followDateA);
          }
        });

        if (sortedUsers.isEmpty) {
          final hasFollowing = _followingUsers.isNotEmpty;
          return RefreshIndicator(
            onRefresh: _loadData,
            color: AppTheme.primaryGreen,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height - 200,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        hasFollowing
                            ? 'No mutual chats yet'
                            : 'No people to chat with',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          hasFollowing
                              ? 'People appear here when you already have a thread, or when someone you follow follows you back. Pull to refresh after you both follow each other.'
                              : 'Follow people to start chatting',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _loadData,
          color: AppTheme.primaryGreen,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: sortedUsers.length,
            itemBuilder: (context, index) {
              final userWithDate = sortedUsers[index];
              final user = userWithDate.user;
              final chat = chatProvider.chats.firstWhere(
                (c) =>
                    c.participants.contains(user.id) &&
                    c.participants.length == 2,
                orElse: () => Chat(
                  id: '',
                  participants: [],
                  participantNames: [],
                  lastMessage: '',
                  lastMessageTime: DateTime(1970),
                  unreadCount: 0,
                  messages: [],
                ),
              );

              final hasChat = chat.id.isNotEmpty;
              final hasMessages = hasChat && chat.messages.isNotEmpty;
              final lastMessage = chat.lastMessage;
              final lastMessageTime = chat.lastMessageTime;
              final unreadCount = chat.unreadCount;
              final hasUnread = unreadCount > 0;

              final lastMessageFromMe = hasMessages
                  ? chat.messages.last.senderId == authProvider.userId
                  : false;
              final isSeen =
                  hasMessages && lastMessageFromMe && chat.messages.last.isRead;

              final isUnread = hasUnread && !lastMessageFromMe;

              return InkWell(
                onTap: () => _openChat(user),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppTheme.primaryGradient,
                        ),
                        child: NetworkCircleAvatar(
                          radius: 28,
                          imageUrl: user.avatarUrl,
                          fallbackLetter: _getInitialLetter(
                              user.fullName ?? user.displayUsername ?? 'U'),
                          fallbackTextStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.fullName ?? 'Unknown User',
                              style: TextStyle(
                                fontWeight: isUnread
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                fontSize: 16,
                                color: Colors.black,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              !hasMessages
                                  ? 'Start a conversation'
                                  : lastMessageFromMe
                                      ? isSeen
                                          ? 'Seen'
                                          : 'Sent ${_formatTimeAgo(lastMessageTime)}'
                                      : hasUnread
                                          ? '$unreadCount new message${unreadCount > 1 ? 's' : ''}'
                                          : lastMessage,
                              style: TextStyle(
                                fontSize: 14,
                                color: isUnread
                                    ? Colors.black87
                                    : Colors.grey[600],
                                fontWeight: isUnread
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (hasUnread)
                        Container(
                          width: 12,
                          height: 12,
                          margin: const EdgeInsets.only(left: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMessageRequestsTab() {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        final authProvider = context.read<AuthProvider>();
        if (authProvider.userId == null) {
          return const Center(child: Text('Not authenticated'));
        }

        if (chatProvider.lastLoadError != null) {
          return RefreshIndicator(
            onRefresh: () async {
              await chatProvider.loadChats();
            },
            color: AppTheme.primaryGreen,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.error_outline,
                        size: 48, color: Colors.grey[600]),
                    const SizedBox(height: 12),
                    Text(
                      "Couldn't load conversations",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      chatProvider.lastLoadError!,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => chatProvider.loadChats(),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final messageRequests = chatProvider.messageRequests;

        if (messageRequests.isEmpty) {
          return RefreshIndicator(
            onRefresh: _loadData,
            color: AppTheme.primaryGreen,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height - 200,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.mark_email_unread_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No message requests',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Messages from people you haven\'t followed back\nwill appear here',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _loadData,
          color: AppTheme.primaryGreen,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: messageRequests.length,
            itemBuilder: (context, index) {
              final chat = messageRequests[index];
              final otherUserId = chat.participants.firstWhere(
                (id) => id != authProvider.userId,
              );

              final user = _followingUsers.firstWhere(
                (u) => u.user.id == otherUserId,
                orElse: () => ChatUserWithFollowDate(
                  user: UserProfile(
                    id: otherUserId,
                    username: chat.participantNames[1],
                    fullName: chat.participantNames[1],
                  ),
                ),
              );

              final lastMessage = chat.lastMessage;
              final unreadCount = chat.unreadCount;
              final hasUnread = unreadCount > 0;

              return InkWell(
                onTap: () => _openChat(user.user, isFromRequests: true),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppTheme.primaryGradient,
                        ),
                        child: NetworkCircleAvatar(
                          radius: 28,
                          imageUrl: user.user.avatarUrl,
                          fallbackLetter: _getInitialLetter(
                              user.user.fullName ??
                                  user.user.displayUsername ??
                                  'U'),
                          fallbackTextStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.user.fullName ?? 'Unknown User',
                              style: TextStyle(
                                fontWeight: hasUnread
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                fontSize: 16,
                                color: Colors.black,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              hasUnread
                                  ? '$unreadCount new message${unreadCount > 1 ? 's' : ''}'
                                  : lastMessage,
                              style: TextStyle(
                                fontSize: 14,
                                color: hasUnread
                                    ? Colors.black87
                                    : Colors.grey[600],
                                fontWeight: hasUnread
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (hasUnread)
                        Container(
                          width: 12,
                          height: 12,
                          margin: const EdgeInsets.only(left: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
