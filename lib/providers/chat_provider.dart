import 'package:flutter/material.dart';
import 'package:cap/shared/models/chat.dart';
import 'package:cap/shared/models/message.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatProvider extends ChangeNotifier {
  List<Chat> _chats = [];
  bool _isLoading = false;
  String? _lastLoadError;
  final Map<String, List<Message>> _chatMessages = {};
  final Map<String, bool> _mutualFollowCache = {};

  static const String _postShareTokenPrefix = 'POST_SHARE_ID:';

  List<Chat> get chats => _chats;
  bool get isLoading => _isLoading;
  String? get lastLoadError => _lastLoadError;

  List<Chat> get regularChats {
    return _chats.where((chat) {
      if (chat.participants.length != 2) return false;
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return false;

      final otherUserId =
          chat.participants.firstWhere((id) => id != currentUser.id);

      final currentUserFollowsOther =
          _getCurrentUserFollowsOther(currentUser.id, otherUserId);

      return currentUserFollowsOther;
    }).toList();
  }

  List<Chat> get messageRequests {
    final result = _chats.where((chat) {
      if (chat.participants.length != 2) return false;
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return false;

      final otherUserId =
          chat.participants.firstWhere((id) => id != currentUser.id);

      final otherUserFollowsCurrent =
          _getOtherUserFollowsCurrent(currentUser.id, otherUserId);

      final currentUserFollowsOther =
          _getCurrentUserFollowsOther(currentUser.id, otherUserId);

      final hasMessages = chat.lastMessage.isNotEmpty;

      final isRequest =
          hasMessages && otherUserFollowsCurrent && !currentUserFollowsOther;

      return isRequest;
    }).toList();

    return result;
  }

  bool _getCurrentUserFollowsOther(String currentUserId, String otherUserId) {
    final cacheKey = '${currentUserId}_$otherUserId';

    if (_mutualFollowCache[cacheKey] == true) return true;

    final followKey = 'follows_${currentUserId}_$otherUserId';
    return _mutualFollowCache[followKey] ?? false;
  }

  bool _getOtherUserFollowsCurrent(String currentUserId, String otherUserId) {
    final followKey = 'follows_${otherUserId}_$currentUserId';
    return _mutualFollowCache[followKey] ?? false;
  }

  ChatProvider();

  Future<Set<String>> _getExcludedUserIds(SupabaseClient supabase) async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return <String>{};
    try {
      final rows = await supabase
          .from('user_blocks')
          .select('blocker_id, blocked_id')
          .or('blocker_id.eq.${currentUser.id},blocked_id.eq.${currentUser.id}');
      final Set<String> excluded = <String>{};
      for (final raw in rows as List<dynamic>) {
        final row = raw as Map<String, dynamic>;
        final blocker = row['blocker_id'] as String;
        final blocked = row['blocked_id'] as String;
        if (blocker == currentUser.id) {
          excluded.add(blocked);
        } else if (blocked == currentUser.id) {
          excluded.add(blocker);
        }
      }
      return excluded;
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> loadChats() async {
    _isLoading = true;
    _lastLoadError = null;
    notifyListeners();

    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      final rows1 = await supabase
          .from('chats')
          .select('*')
          .eq('user1_id', currentUser.id)
          .order('updated_at', ascending: false);
      final rows2 = await supabase
          .from('chats')
          .select('*')
          .eq('user2_id', currentUser.id)
          .order('updated_at', ascending: false);
      final byChatId = <String, Map<String, dynamic>>{};
      for (final row in rows1 as List<dynamic>) {
        final m = row as Map<String, dynamic>;
        byChatId[m['id'] as String] = m;
      }
      for (final row in rows2 as List<dynamic>) {
        final m = row as Map<String, dynamic>;
        byChatId[m['id'] as String] = m;
      }
      final chatsResponse = byChatId.values.toList()
        ..sort(
          (a, b) => DateTime.parse(b['updated_at'] as String)
              .compareTo(DateTime.parse(a['updated_at'] as String)),
        );
      final excludedUserIds = await _getExcludedUserIds(supabase);

      final Set<String> userIds = {};
      for (final chatRow in chatsResponse as List<dynamic>) {
        final row = chatRow as Map<String, dynamic>;
        userIds.add(row['user1_id'] as String);
        userIds.add(row['user2_id'] as String);
      }

      Map<String, Map<String, dynamic>> userIdToProfile = {};
      if (userIds.isNotEmpty) {
        final profileRows = await supabase
            .from('user_profiles')
            .select('id, full_name, username, avatar_url')
            .inFilter('id', userIds.toList());
        for (final p in profileRows as List<dynamic>) {
          final row = p as Map<String, dynamic>;
          userIdToProfile[row['id'] as String] = row;
        }
      }

      final otherUserIds = userIds.where((id) => id != currentUser.id).toList();
      await _loadMutualFollowStatus(currentUser.id, otherUserIds);

      final List<Chat> loadedChats = [];
      for (final chatRow in chatsResponse as List<dynamic>) {
        final row = chatRow as Map<String, dynamic>;
        final chatId = row['id'] as String;
        final user1Id = row['user1_id'] as String;
        final user2Id = row['user2_id'] as String;

        final otherUserId = user1Id == currentUser.id ? user2Id : user1Id;
        if (excludedUserIds.contains(otherUserId)) {
          continue;
        }
        final otherUserProfile = userIdToProfile[otherUserId];

        final otherUserName = otherUserProfile != null
            ? (otherUserProfile['full_name'] as String?) ??
                (otherUserProfile['username'] as String?) ??
                'User'
            : 'User';

        final lastMessageData = await supabase
            .from('messages')
            .select('content, created_at, sender_id, read_at, event_id')
            .eq('chat_id', chatId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        String lastMessage = '';
        DateTime lastMessageTime = DateTime.parse(row['updated_at'] as String);
        if (lastMessageData != null) {
          final hasEventId = lastMessageData['event_id'] != null;
          if (hasEventId) {
            lastMessage = 'Shared an event';
          } else {
            final content = lastMessageData['content'] as String? ?? '';
            lastMessage = content.contains(_postShareTokenPrefix)
                ? 'Shared a post'
                : content;
          }
          lastMessageTime =
              DateTime.parse(lastMessageData['created_at'] as String);
        }

        final unreadCountResponse = await supabase
            .from('messages')
            .select('id')
            .eq('chat_id', chatId)
            .eq('sender_id', otherUserId)
            .isFilter('read_at', null);

        final unreadCount = (unreadCountResponse as List).length;

        final messages = await _loadMessagesForChat(chatId);

        loadedChats.add(Chat(
          id: chatId,
          participants: [currentUser.id, otherUserId],
          participantNames: ['You', otherUserName],
          lastMessage: lastMessage,
          lastMessageTime: lastMessageTime,
          unreadCount: unreadCount,
          messages: messages,
        ));
      }

      _chats = loadedChats;
      _lastLoadError = null;
    } catch (e, st) {
      _lastLoadError = e.toString();
      debugPrint('ChatProvider.loadChats failed: $e\n$st');
      _chats = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadMutualFollowStatus(
      String currentUserId, List<String> otherUserIds) async {
    if (otherUserIds.isEmpty) return;

    try {
      final supabase = Supabase.instance.client;

      final currentUserFollowsResponse = await supabase
          .from('follows')
          .select('following_id')
          .eq('follower_id', currentUserId)
          .inFilter('following_id', otherUserIds);

      final currentUserFollowsSet =
          (currentUserFollowsResponse as List<dynamic>)
              .map((row) => row['following_id'] as String)
              .toSet();

      final otherUsersFollowResponse = await supabase
          .from('follows')
          .select('follower_id')
          .eq('following_id', currentUserId)
          .inFilter('follower_id', otherUserIds);

      final otherUsersFollowSet = (otherUsersFollowResponse as List<dynamic>)
          .map((row) => row['follower_id'] as String)
          .toSet();

      for (final otherUserId in otherUserIds) {
        final cacheKey = '${currentUserId}_$otherUserId';
        final isMutualFollow = currentUserFollowsSet.contains(otherUserId) &&
            otherUsersFollowSet.contains(otherUserId);
        _mutualFollowCache[cacheKey] = isMutualFollow;

        _mutualFollowCache['follows_${currentUserId}_$otherUserId'] =
            currentUserFollowsSet.contains(otherUserId);
        _mutualFollowCache['follows_${otherUserId}_$currentUserId'] =
            otherUsersFollowSet.contains(otherUserId);
      }
    } catch (e) {}
  }

  Future<List<Message>> _loadMessagesForChat(String chatId) async {
    if (_chatMessages.containsKey(chatId)) {
      return _chatMessages[chatId]!;
    }

    try {
      final supabase = Supabase.instance.client;
      final messagesResponse = await supabase
          .from('messages')
          .select('*')
          .eq('chat_id', chatId)
          .order('created_at', ascending: true);

      final messages = (messagesResponse as List<dynamic>)
          .map((row) => Message.fromSupabaseRow(row as Map<String, dynamic>))
          .toList();

      _chatMessages[chatId] = messages;
      return messages;
    } catch (e) {
      debugPrint('Failed to load messages for chat $chatId: $e');
      return [];
    }
  }

  Chat? getChatById(String chatId) {
    try {
      return _chats.firstWhere((chat) => chat.id == chatId);
    } catch (e) {
      return null;
    }
  }

  Future<Chat?> getOrCreateChat(String otherUserId) async {
    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) throw Exception('Not authenticated');
      final excludedUserIds = await _getExcludedUserIds(supabase);
      if (excludedUserIds.contains(otherUserId)) {
        throw Exception('Cannot chat with this user');
      }

      Map<String, dynamic>? existingChat = await supabase
          .from('chats')
          .select('*')
          .eq('user1_id', currentUser.id)
          .eq('user2_id', otherUserId)
          .maybeSingle();
      existingChat ??= await supabase
          .from('chats')
          .select('*')
          .eq('user1_id', otherUserId)
          .eq('user2_id', currentUser.id)
          .maybeSingle();

      if (existingChat != null) {
        final chatId = existingChat['id'] as String;
        await loadChats();
        return getChatById(chatId);
      }

      final newChatResponse = await supabase
          .from('chats')
          .insert({
            'user1_id': currentUser.id,
            'user2_id': otherUserId,
          })
          .select()
          .single();

      final chatId = newChatResponse['id'] as String;
      await loadChats();
      return getChatById(chatId);
    } catch (e, st) {
      debugPrint('getOrCreateChat failed: $e\n$st');
      return null;
    }
  }

  Future<void> sendMessage(
    String chatId,
    String content, {
    String? eventId,
    String? postId,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) throw Exception('Not authenticated');
      final chatRow = await supabase
          .from('chats')
          .select('user1_id, user2_id')
          .eq('id', chatId)
          .maybeSingle();
      if (chatRow != null) {
        final user1 = chatRow['user1_id'] as String;
        final user2 = chatRow['user2_id'] as String;
        final otherUserId = user1 == currentUser.id ? user2 : user1;
        final excludedUserIds = await _getExcludedUserIds(supabase);
        if (excludedUserIds.contains(otherUserId)) {
          throw Exception('Cannot send messages to this user');
        }
      }

      await supabase.from('messages').insert({
        'chat_id': chatId,
        'sender_id': currentUser.id,
        'content': content,
        if (eventId != null) 'event_id': eventId,
        if (postId != null) 'post_id': postId,
      });

      _chatMessages.remove(chatId);
      await _loadMessagesForChat(chatId);
      await loadChats();
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> shareEvent({
    required String eventId,
    required String recipientUserId,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) throw Exception('Not authenticated');

      final chat = await getOrCreateChat(recipientUserId);
      if (chat == null) throw Exception('Failed to get or create chat');

      await sendMessage(
        chat.id,
        'Shared an event',
        eventId: eventId,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> sharePost({
    required String postId,
    required String recipientUserId,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) throw Exception('Not authenticated');

      final chat = await getOrCreateChat(recipientUserId);
      if (chat == null) throw Exception('Failed to get or create chat');

      try {
        await sendMessage(
          chat.id,
          'Shared a post',
          postId: postId,
        );
      } catch (e) {
        final token = '$_postShareTokenPrefix$postId';
        await sendMessage(
          chat.id,
          'Shared a post\n$token',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> markChatAsRead(String chatId) async {
    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      final chat = getChatById(chatId);
      if (chat == null) return;

      final otherUserId =
          chat.participants.firstWhere((id) => id != currentUser.id);

      await supabase
          .from('messages')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('chat_id', chatId)
          .eq('sender_id', otherUserId)
          .isFilter('read_at', null);

      _chatMessages.remove(chatId);
      await loadChats();
    } catch (e) {}
  }

  Future<void> refreshChat(String chatId) async {
    _chatMessages.remove(chatId);
    await _loadMessagesForChat(chatId);
    await loadChats();
    notifyListeners();
  }

  Future<void> refreshFollowStatusForUser(String otherUserId) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    try {
      final supabase = Supabase.instance.client;

      final currentUserFollowsResponse = await supabase
          .from('follows')
          .select('id')
          .eq('follower_id', currentUser.id)
          .eq('following_id', otherUserId)
          .maybeSingle();

      final otherUserFollowsResponse = await supabase
          .from('follows')
          .select('id')
          .eq('follower_id', otherUserId)
          .eq('following_id', currentUser.id)
          .maybeSingle();

      final cacheKey = '${currentUser.id}_$otherUserId';
      final isMutualFollow = currentUserFollowsResponse != null &&
          otherUserFollowsResponse != null;
      _mutualFollowCache[cacheKey] = isMutualFollow;

      _mutualFollowCache['follows_${currentUser.id}_$otherUserId'] =
          currentUserFollowsResponse != null;
      _mutualFollowCache['follows_${otherUserId}_${currentUser.id}'] =
          otherUserFollowsResponse != null;

      await loadChats();
    } catch (e) {}
  }

  Future<void> preloadFollowEdgesForUserIds(List<String> otherUserIds) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null || otherUserIds.isEmpty) return;
    final unique = otherUserIds.toSet().toList();
    await _loadMutualFollowStatus(currentUser.id, unique);
    notifyListeners();
  }

  bool isMutualFollowWith(String otherUserId) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return false;
    return _mutualFollowCache['${currentUser.id}_$otherUserId'] == true;
  }

  void clearChats() {
    _chats = [];
    _lastLoadError = null;
    _chatMessages.clear();
    _mutualFollowCache.clear();
    _isLoading = false;
    notifyListeners();
  }
}
