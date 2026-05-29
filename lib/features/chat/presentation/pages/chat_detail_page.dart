import 'package:flutter/material.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/features/events/presentation/widgets/event_details_bottom_sheet.dart';
import 'package:cap/shared/utils/event_date_format.dart';
import 'package:cap/providers/auth_provider.dart';
import 'package:cap/providers/chat_provider.dart';
import 'package:cap/providers/event_provider.dart';
import 'package:cap/providers/profile_provider.dart';
import 'package:cap/shared/models/event.dart';
import 'package:cap/shared/models/message.dart';
import 'package:cap/shared/models/post.dart';
import 'package:cap/shared/widgets/linkified_text.dart';
import 'package:cap/shared/widgets/cached_image_widget.dart';
import 'package:cap/shared/widgets/network_circle_avatar.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ChatDetailPage extends StatefulWidget {
  final String chatId;
  final String? participantName;
  final String? participantAvatarUrl;
  final VoidCallback? onAccepted;

  const ChatDetailPage({
    super.key,
    required this.chatId,
    this.participantName,
    this.participantAvatarUrl,
    this.onAccepted,
  });

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _participantName;
  String? _participantAvatarUrl;
  String? _currentUserName;
  String? _currentUserAvatarUrl;
  bool _isMessageRequest = false;
  bool _isFollowingBack = false;
  bool _shouldNavigateToRequests = false;
  bool _isSendingMessage = false;
  final Map<String, Future<Event?>> _eventFuturesCache = {};
  final Map<String, Future<Post?>> _postFuturesCache = {};

  @override
  void initState() {
    super.initState();
    _participantName = widget.participantName;
    _participantAvatarUrl = widget.participantAvatarUrl;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadChat();
      _loadParticipantProfile();
      _loadCurrentUserProfile();
      _checkIfMessageRequestSync();
      _checkIfMessageRequest();
      _markAsRead();
    });
  }

  void _checkIfMessageRequestSync() {
    final chatProvider = context.read<ChatProvider>();
    final messageRequests = chatProvider.messageRequests;
    final chat = chatProvider.getChatById(widget.chatId);

    if (chat != null) {
      final isRequest = messageRequests.any((c) => c.id == chat.id);
      if (mounted) {
        setState(() {
          _isMessageRequest = isRequest;
        });
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadChat() {
    final chatProvider = context.read<ChatProvider>();
    chatProvider.refreshChat(widget.chatId);
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;

    final bottomOffset = _scrollController.position.minScrollExtent;
    if (animated) {
      _scrollController.animateTo(
        bottomOffset,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(bottomOffset);
    }
  }

  Future<void> _loadParticipantProfile() async {
    final chatProvider = context.read<ChatProvider>();
    final authProvider = context.read<AuthProvider>();
    final chat = chatProvider.getChatById(widget.chatId);

    if (chat == null || authProvider.userId == null) return;

    final otherUserId = chat.participants.firstWhere(
      (id) => id != authProvider.userId,
      orElse: () => '',
    );

    if (otherUserId.isEmpty) return;

    try {
      final supabase = Supabase.instance.client;
      final profileResponse = await supabase
          .from('user_profiles')
          .select('full_name, username, avatar_url')
          .eq('id', otherUserId)
          .maybeSingle();

      if (profileResponse != null && mounted) {
        setState(() {
          _participantName = (profileResponse['full_name'] as String?) ??
              (profileResponse['username'] as String?)?.toLowerCase() ??
              'User';
          _participantAvatarUrl = profileResponse['avatar_url'] as String?;
        });
      }
    } catch (e) { /* ignored */ }
  }

  Future<void> _loadCurrentUserProfile() async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.userId == null) return;

    try {
      final supabase = Supabase.instance.client;
      final profileResponse = await supabase
          .from('user_profiles')
          .select('full_name, username, avatar_url')
          .eq('id', authProvider.userId!)
          .maybeSingle();

      if (profileResponse != null && mounted) {
        setState(() {
          _currentUserName = (profileResponse['full_name'] as String?) ??
              (profileResponse['username'] as String?)?.toLowerCase() ??
              'Me';
          _currentUserAvatarUrl = profileResponse['avatar_url'] as String?;
        });
      }
    } catch (e) { /* ignored */ }
  }

  Future<void> _checkIfMessageRequest() async {
    final chatProvider = context.read<ChatProvider>();
    final authProvider = context.read<AuthProvider>();
    final chat = chatProvider.getChatById(widget.chatId);

    if (chat == null || authProvider.userId == null) return;

    final otherUserId = chat.participants.firstWhere(
      (id) => id != authProvider.userId,
      orElse: () => '',
    );

    if (otherUserId.isEmpty) return;

    try {
      final supabase = Supabase.instance.client;

      final otherFollowsCurrent = await supabase
          .from('follows')
          .select('id')
          .eq('follower_id', otherUserId)
          .eq('following_id', authProvider.userId!)
          .maybeSingle();

      final currentFollowsOther = await supabase
          .from('follows')
          .select('id')
          .eq('follower_id', authProvider.userId!)
          .eq('following_id', otherUserId)
          .maybeSingle();

      final hasMessages = chat.lastMessage.isNotEmpty;
      final isRequest = hasMessages &&
          otherFollowsCurrent != null &&
          currentFollowsOther == null;

      if (mounted) {
        setState(() {
          _isMessageRequest = isRequest;
        });
      }
    } catch (e) { /* ignored */ }
  }

  Future<void> _followBack() async {
    final chatProvider = context.read<ChatProvider>();
    final authProvider = context.read<AuthProvider>();
    final profileProvider = context.read<ProfileProvider>();
    final chat = chatProvider.getChatById(widget.chatId);

    if (chat == null || authProvider.userId == null) return;

    final otherUserId = chat.participants.firstWhere(
      (id) => id != authProvider.userId,
      orElse: () => '',
    );

    if (otherUserId.isEmpty) return;

    setState(() {
      _isFollowingBack = true;
    });

    try {
      final success = await profileProvider.followUser(otherUserId);

      if (success && mounted) {
        await chatProvider.loadChats();

        setState(() {
          _isMessageRequest = false;
          _isFollowingBack = false;
        });

        if (mounted) {
          final participantName =
              _participantName ?? widget.participantName ?? 'them';

          widget.onAccepted?.call();
          _showAcceptDialog(participantName);
        }
      } else {
        if (mounted) {
          setState(() {
            _isFollowingBack = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to follow back'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFollowingBack = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAcceptDialog(String participantName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: AppTheme.primaryGreen,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Chat Accepted!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'You are now following $participantName back. You can now chat with them!',
            style: const TextStyle(
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Got it',
                style: TextStyle(
                  color: AppTheme.primaryGreen,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _markAsRead() {
    final chatProvider = context.read<ChatProvider>();
    chatProvider.markChatAsRead(widget.chatId);
  }

  void _sendMessage() async {
    if (_isSendingMessage) return;

    final raw = _messageController.text;
    final content = raw.trim();
    if (content.isEmpty) return;

    setState(() {
      _isSendingMessage = true;
      _messageController.clear();
    });

    final chatProvider = context.read<ChatProvider>();
    try {
      await chatProvider.sendMessage(
        widget.chatId,
        content,
      );

      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollToBottom(animated: true);
        }
      });
    } catch (e) {
      if (_messageController.text.trim().isEmpty) {
        _messageController.text = raw;
        _messageController.selection = TextSelection.fromPosition(
          TextPosition(offset: _messageController.text.length),
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingMessage = false;
        });
      } else {
        _isSendingMessage = false;
      }
    }
  }

  String _getInitialLetter(String name) {
    if (name.isEmpty) return 'U';
    return name[0].toUpperCase();
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

  Future<Post?> _getPostById(String postId) async {
    try {
      final supabase = Supabase.instance.client;

      final row = await supabase
          .from('posts')
          .select(
              'id, user_id, title, content, image_urls, tags, location, created_at')
          .eq('id', postId)
          .maybeSingle();

      if (row == null) {
        return null;
      }

      final rowMap = row;
      final userId = rowMap['user_id'] as String;

      final profileRow = await supabase
          .from('user_profiles')
          .select('id, full_name, username, avatar_url')
          .eq('id', userId)
          .maybeSingle();

      String userName = 'User';
      String? avatarUrl;

      if (profileRow != null) {
        final profile = profileRow;
        userName = (profile['full_name'] as String?) ??
            (profile['username'] as String?) ??
            'User';
        avatarUrl = profile['avatar_url'] as String?;
      }

      return Post.fromSupabaseRow(
        rowMap,
        userName: userName,
        userAvatar: avatarUrl,
      );
    } catch (e) {
      return null;
    }
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
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to unregister'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildEventCard(Event event, bool isMe) {
    return InkWell(
      onTap: () {
        _showEventDetails(event);
      },
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 280,
          minWidth: 200,
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? Colors.white : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMe ? Colors.white.withValues(alpha: 0.5) : Colors.grey[300]!,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    eventCategoryIcon(event.category),
                    color: isMe ? AppTheme.primaryGreen : AppTheme.primaryGreen,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        event.category,
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
            const SizedBox(height: 8),
            LinkifiedText(
              text: event.description,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 12,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  formatEventDateIso(event.eventDate),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.access_time,
                  size: 12,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    event.time,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostCard(Post post, bool isMe) {
    return InkWell(
      onTap: () {
        context.push('/post/${post.id}');
      },
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 280,
          minWidth: 200,
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? Colors.white : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMe ? Colors.white.withValues(alpha: 0.5) : Colors.grey[300]!,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.primaryGradient,
                  ),
                  child: NetworkCircleAvatar(
                    radius: 16,
                    imageUrl: post.userAvatar,
                    fallbackLetter: post.userName.isNotEmpty
                        ? post.userName[0].toUpperCase()
                        : 'U',
                    fallbackTextStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _formatPostTimestamp(post.timestamp),
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
            const SizedBox(height: 8),
            if (post.title.isNotEmpty) ...[
              Text(
                post.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
            ],
            if (post.content.isNotEmpty)
              Text(
                post.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[800],
                ),
              ),
            if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedImageWidget(
                  imageUrl: post.imageUrl!,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatPostTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

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

  bool _shouldShowMessageTimestamp(List<Message> messages, int index) {
    if (index == messages.length - 1) return true;

    final current = messages[index].timestamp.toLocal();
    final nextOlder = messages[index + 1].timestamp.toLocal();

    final sameDay = nextOlder.year == current.year &&
        nextOlder.month == current.month &&
        nextOlder.day == current.day;

    final sameMinute = sameDay &&
        nextOlder.hour == current.hour &&
        nextOlder.minute == current.minute;

    return !sameMinute;
  }

  String _formatChatMessageTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final localTs = timestamp.toLocal();

    final today = DateTime(now.year, now.month, now.day);
    final tsDate = DateTime(localTs.year, localTs.month, localTs.day);

    final time = DateFormat('h:mm a').format(localTs).toUpperCase();

    if (tsDate == today) {
      return time;
    }

    final yesterday = today.subtract(const Duration(days: 1));
    if (tsDate == yesterday) {
      return 'YESTERDAY $time';
    }

    final month = DateFormat('MMM').format(localTs).toUpperCase();
    final day = localTs.day.toString();
    return '$month $day AT $time';
  }

  static const String _postShareTokenPrefix = 'POST_SHARE_ID:';

  String? _extractSharedPostIdFromContent(String content) {
    final idx = content.indexOf(_postShareTokenPrefix);
    if (idx == -1) return null;

    final after = content.substring(idx + _postShareTokenPrefix.length).trim();
    if (after.isEmpty) return null;

    return after.split('\n').first.trim().isEmpty
        ? null
        : after.split('\n').first.trim();
  }

  String _cleanMessageContent(String content) {
    final sharedPostId = _extractSharedPostIdFromContent(content);
    if (sharedPostId != null) return 'Shared a post';
    return content;
  }

  Future<void> _navigateToProfile() async {
    final chatProvider = context.read<ChatProvider>();
    final authProvider = context.read<AuthProvider>();
    final chat = chatProvider.getChatById(widget.chatId);

    if (chat != null && authProvider.userId != null) {
      final otherUserId = chat.participants.firstWhere(
        (id) => id != authProvider.userId,
        orElse: () => '',
      );

      if (otherUserId.isNotEmpty) {
        final wasMessageRequestBefore = _isMessageRequest;

        await context.push('/user-profile/$otherUserId');

        if (mounted) {
          try {
            final supabase = Supabase.instance.client;

            final currentFollowsOther = await supabase
                .from('follows')
                .select('id')
                .eq('follower_id', authProvider.userId!)
                .eq('following_id', otherUserId)
                .maybeSingle();

            final otherFollowsCurrent = await supabase
                .from('follows')
                .select('id')
                .eq('follower_id', otherUserId)
                .eq('following_id', authProvider.userId!)
                .maybeSingle();

            final hasMessages = chat.lastMessage.isNotEmpty;
            final isNowRequest = hasMessages &&
                otherFollowsCurrent != null &&
                currentFollowsOther == null;

            if (mounted) {
              setState(() {
                _isMessageRequest = isNowRequest;

                if (!wasMessageRequestBefore && isNowRequest) {
                  _shouldNavigateToRequests = true;
                }
              });
            }

            chatProvider.refreshFollowStatusForUser(otherUserId);
          } catch (e) {
            chatProvider.refreshFollowStatusForUser(otherUserId).then((_) {
              if (mounted) {
                _checkIfMessageRequest();
              }
            });
          }
        }
      }
    }
  }

  Future<void> _navigateToUserProfile(String userId) async {
    final chatProvider = context.read<ChatProvider>();
    final authProvider = context.read<AuthProvider>();
    final chat = chatProvider.getChatById(widget.chatId);

    if (chat != null && authProvider.userId != null) {
      final otherUserId = chat.participants.firstWhere(
        (id) => id != authProvider.userId,
        orElse: () => '',
      );

      if (userId == otherUserId) {
        final wasMessageRequestBefore = _isMessageRequest;

        await context.push('/user-profile/$userId');

        if (mounted) {
          try {
            final supabase = Supabase.instance.client;

            final currentFollowsOther = await supabase
                .from('follows')
                .select('id')
                .eq('follower_id', authProvider.userId!)
                .eq('following_id', userId)
                .maybeSingle();

            final otherFollowsCurrent = await supabase
                .from('follows')
                .select('id')
                .eq('follower_id', userId)
                .eq('following_id', authProvider.userId!)
                .maybeSingle();

            final hasMessages = chat.lastMessage.isNotEmpty;
            final isNowRequest = hasMessages &&
                otherFollowsCurrent != null &&
                currentFollowsOther == null;

            if (mounted) {
              setState(() {
                _isMessageRequest = isNowRequest;

                if (!wasMessageRequestBefore && isNowRequest) {
                  _shouldNavigateToRequests = true;
                }
              });
            }

            chatProvider.refreshFollowStatusForUser(userId);
          } catch (e) {
            chatProvider.refreshFollowStatusForUser(userId).then((_) {
              if (mounted) {
                _checkIfMessageRequest();
              }
            });
          }
        }
      } else {
        context.push('/user-profile/$userId');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _participantName ?? widget.participantName ?? 'Chat';
    final avatarUrl = _participantAvatarUrl ?? widget.participantAvatarUrl;
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'C';

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundLight,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context, _shouldNavigateToRequests),
        ),
        title: Row(
          children: [
            InkWell(
              onTap: _navigateToProfile,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.primaryGradient,
                ),
                child: NetworkCircleAvatar(
                  radius: 18,
                  imageUrl: avatarUrl,
                  fallbackLetter: initial,
                  fallbackTextStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              fit: FlexFit.loose,
              child: GestureDetector(
                onTap: _navigateToProfile,
                child: Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, chatProvider, child) {
                final chat = chatProvider.getChatById(widget.chatId);
                final authProvider = context.read<AuthProvider>();

                if (chat != null) {
                  if (_participantAvatarUrl == null) {
                    _loadParticipantProfile();
                  }
                  if (_currentUserAvatarUrl == null) {
                    _loadCurrentUserProfile();
                  }
                }

                if (chat == null || chat.messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start the conversation',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final reversedMessages =
                    chat.messages.reversed.toList(growable: false);

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: reversedMessages.length,
                  itemBuilder: (context, index) {
                    final message = reversedMessages[index];
                    final isMe = message.senderId == authProvider.userId;
                    final eventProvider = context.read<EventProvider>();
                    final showTimestamp =
                        _shouldShowMessageTimestamp(reversedMessages, index);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showTimestamp)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Center(
                                child: Text(
                                  _formatChatMessageTimestamp(
                                      message.timestamp),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          Row(
                            mainAxisAlignment: isMe
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.start,
                            children: [
                              if (!isMe) ...[
                                InkWell(
                                  onTap: () {
                                    final chatProvider =
                                        context.read<ChatProvider>();
                                    final authProvider =
                                        context.read<AuthProvider>();
                                    final chat =
                                        chatProvider.getChatById(widget.chatId);
                                    if (chat != null &&
                                        authProvider.userId != null) {
                                      final otherUserId =
                                          chat.participants.firstWhere(
                                        (id) => id != authProvider.userId,
                                        orElse: () => '',
                                      );
                                      if (otherUserId.isNotEmpty) {
                                        _navigateToUserProfile(otherUserId);
                                      }
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: AppTheme.primaryGradient,
                                    ),
                                    child: NetworkCircleAvatar(
                                      radius: 16,
                                      imageUrl: avatarUrl,
                                      fallbackLetter: initial,
                                      fallbackTextStyle: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Flexible(
                                child: message.eventId != null
                                    ? FutureBuilder<Event?>(
                                        key: ValueKey(
                                            'event_${message.eventId}'),
                                        future: _eventFuturesCache.putIfAbsent(
                                          message.eventId!,
                                          () => eventProvider
                                              .getEventById(message.eventId!),
                                        ),
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState ==
                                              ConnectionState.waiting) {
                                            return Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 10),
                                              decoration: BoxDecoration(
                                                color: isMe
                                                    ? AppTheme.primaryGreen
                                                    : Colors.grey[200],
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                              ),
                                              child: const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                          Color>(Colors.white),
                                                ),
                                              ),
                                            );
                                          }

                                          if (snapshot.hasError) {
                                            return Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 10),
                                              decoration: BoxDecoration(
                                                color: isMe
                                                    ? AppTheme.primaryGreen
                                                    : Colors.grey[200],
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                              ),
                                              child: Text(
                                                message.content.isNotEmpty
                                                    ? message.content
                                                    : 'Shared an event',
                                                style: TextStyle(
                                                  color: isMe
                                                      ? Colors.white
                                                      : Colors.black87,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            );
                                          }

                                          final event = snapshot.data;
                                          if (event == null) {
                                            return Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 10),
                                              decoration: BoxDecoration(
                                                color: isMe
                                                    ? AppTheme.primaryGreen
                                                    : Colors.grey[200],
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                              ),
                                              child: Text(
                                                message.content.isNotEmpty
                                                    ? message.content
                                                    : 'Shared an event',
                                                style: TextStyle(
                                                  color: isMe
                                                      ? Colors.white
                                                      : Colors.black87,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            );
                                          }

                                          return _buildEventCard(event, isMe);
                                        },
                                      )
                                    : (message.postId != null ||
                                            _extractSharedPostIdFromContent(
                                                    message.content) !=
                                                null)
                                        ? FutureBuilder<Post?>(
                                            key: ValueKey(
                                              'post_${message.postId ?? _extractSharedPostIdFromContent(message.content)!}',
                                            ),
                                            future:
                                                _postFuturesCache.putIfAbsent(
                                              message.postId ??
                                                  _extractSharedPostIdFromContent(
                                                      message.content)!,
                                              () => _getPostById(
                                                message.postId ??
                                                    _extractSharedPostIdFromContent(
                                                        message.content)!,
                                              ),
                                            ),
                                            builder: (context, snapshot) {
                                              if (snapshot.connectionState ==
                                                  ConnectionState.waiting) {
                                                return Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 16,
                                                      vertical: 10),
                                                  decoration: BoxDecoration(
                                                    color: isMe
                                                        ? AppTheme.primaryGreen
                                                        : Colors.grey[200],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            18),
                                                  ),
                                                  child: const SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                                  Color>(
                                                              Colors.white),
                                                    ),
                                                  ),
                                                );
                                              }

                                              if (snapshot.hasError) {
                                                return Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 16,
                                                      vertical: 10),
                                                  decoration: BoxDecoration(
                                                    color: isMe
                                                        ? AppTheme.primaryGreen
                                                        : Colors.grey[200],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            18),
                                                  ),
                                                  child: Text(
                                                    'Shared a post',
                                                    style: TextStyle(
                                                      color: isMe
                                                          ? Colors.white
                                                          : Colors.black87,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                );
                                              }

                                              final post = snapshot.data;
                                              if (post == null) {
                                                return Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 16,
                                                      vertical: 10),
                                                  decoration: BoxDecoration(
                                                    color: isMe
                                                        ? AppTheme.primaryGreen
                                                        : Colors.grey[200],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            18),
                                                  ),
                                                  child: Text(
                                                    'Shared a post',
                                                    style: TextStyle(
                                                      color: isMe
                                                          ? Colors.white
                                                          : Colors.black87,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                );
                                              }

                                              return _buildPostCard(post, isMe);
                                            },
                                          )
                                        : Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 10,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isMe
                                                  ? AppTheme.primaryGreen
                                                  : Colors.grey[200],
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                            ),
                                            child: Text(
                                              _cleanMessageContent(
                                                  message.content),
                                              style: TextStyle(
                                                color: isMe
                                                    ? Colors.white
                                                    : Colors.black87,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                              ),
                              if (isMe) ...[
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () {
                                    final authProvider =
                                        context.read<AuthProvider>();
                                    if (authProvider.userId != null) {
                                      _navigateToUserProfile(
                                          authProvider.userId!);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: AppTheme.primaryGradient,
                                    ),
                                    child: NetworkCircleAvatar(
                                      radius: 16,
                                      imageUrl: _currentUserAvatarUrl,
                                      fallbackLetter: _getInitialLetter(
                                          _currentUserName ?? 'Me'),
                                      fallbackTextStyle: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          _isMessageRequest
              ? Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Colors.grey[300]!)),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isFollowingBack ? null : _followBack,
                      icon: _isFollowingBack
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.person_add),
                      label: Text(
                        _isFollowingBack
                            ? 'Accepting...'
                            : 'Accept Chat Request',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                )
              : Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Colors.grey[300]!)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: 'Message...',
                            hintStyle: TextStyle(color: Colors.grey[500]),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide:
                                  BorderSide(color: AppTheme.primaryGreen),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                          ),
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _isSendingMessage ? null : _sendMessage,
                        icon: const Icon(Icons.send),
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          disabledBackgroundColor:
                              AppTheme.primaryGreen.withValues(alpha: 0.55),
                          foregroundColor: Colors.white,
                          disabledForegroundColor:
                              Colors.white.withValues(alpha: 0.95),
                          padding: const EdgeInsets.all(12),
                        ),
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }
}
