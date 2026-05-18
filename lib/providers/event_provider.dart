import 'package:flutter/material.dart';
import 'package:cap/shared/models/event.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EventProvider extends ChangeNotifier {
  List<Event> _events = [];
  final Map<String, List<Event>> _userEventsCache = {};
  final Set<String> _loadedUsers = {};
  final Set<String> _registeredEventIds = {};
  bool _isLoading = false;
  String? _error;

  List<Event> get events => _events;
  bool get isLoading => _isLoading;
  String? get error => _error;

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> loadEvents() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = _supabase.auth.currentUser;
      final List<dynamic> rows = await _supabase
          .from('events')
          .select('*')
          .order('event_date', ascending: true);

      if (user != null) {
        final registeredRows = await _supabase
            .from('event_registrations')
            .select('event_id')
            .eq('user_id', user.id);
        _registeredEventIds.clear();
        for (final row in registeredRows as List<dynamic>) {
          _registeredEventIds.add(row['event_id'] as String);
        }
      }

      final Set<String> userIds = rows
          .map((r) => (r as Map<String, dynamic>)['user_id'] as String)
          .toSet();

      Map<String, Map<String, dynamic>> userIdToProfile = {};
      if (userIds.isNotEmpty) {
        final profileRows = await _supabase
            .from('user_profiles')
            .select('id, full_name, username, avatar_url')
            .inFilter('id', userIds.toList());
        for (final p in profileRows as List<dynamic>) {
          final row = p as Map<String, dynamic>;
          userIdToProfile[row['id'] as String] = row;
        }
      }

      _events = rows.map((raw) {
        final row = raw as Map<String, dynamic>;
        final profile = userIdToProfile[row['user_id'] as String];
        final userName = profile != null
            ? (profile['full_name'] as String?) ??
                (profile['username'] as String?) ??
                'User'
            : 'User';
        final userAvatar =
            profile != null ? profile['avatar_url'] as String? : null;

        final coHostIds = (row['co_host_ids'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        final coHostNames = <String>[];
        for (final hostId in coHostIds) {
          final hostProfile = userIdToProfile[hostId];
          if (hostProfile != null) {
            coHostNames.add((hostProfile['full_name'] as String?) ??
                (hostProfile['username'] as String?) ??
                'User');
          }
        }

        return Event.fromSupabaseRow(row,
            userName: userName,
            userAvatar: userAvatar,
            coHostNames: coHostNames);
      }).toList();
    } catch (e) {
      _error = 'Failed to load events: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createEvent({
    required String title,
    required String category,
    required String description,
    required DateTime eventDate,
    required String time,
    required String location,
    String? farmId,
    int maxAttendees = 50,
    bool isCoHosted = false,
    List<String> coHostIds = const [],
    List<String> tags = const [],
    String? imageUrl,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final response = await _supabase
          .from('events')
          .insert({
            'user_id': user.id,
            'title': title,
            'category': category,
            'description': description,
            'event_date': eventDate.toIso8601String().split('T')[0],
            'time': time,
            'location': location,
            'farm_id': farmId,
            'max_attendees': maxAttendees,
            'is_co_hosted': isCoHosted,
            'co_host_ids': coHostIds,
            'tags': tags,
            'image_url': imageUrl,
          })
          .select()
          .single();

      final eventId = response['id'] as String;

      await _supabase.from('event_registrations').insert({
        'event_id': eventId,
        'user_id': user.id,
      });

      await _supabase
          .rpc('increment_event_attendees', params: {'event_id': eventId});

      _registeredEventIds.add(eventId);

      await loadEvents();
      return true;
    } catch (e) {
      _error = 'Failed to create event: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> registerForEvent(String eventId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      await _supabase.from('event_registrations').insert({
        'event_id': eventId,
        'user_id': user.id,
      });

      await _supabase
          .rpc('increment_event_attendees', params: {'event_id': eventId});
      _registeredEventIds.add(eventId);
      await loadEvents();
      return true;
    } catch (e) {
      _error = 'Failed to register: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> unregisterFromEvent(String eventId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      await _supabase
          .from('event_registrations')
          .delete()
          .eq('event_id', eventId)
          .eq('user_id', user.id);

      await _supabase
          .rpc('decrement_event_attendees', params: {'event_id': eventId});
      _registeredEventIds.remove(eventId);
      await loadEvents();
      return true;
    } catch (e) {
      _error = 'Failed to unregister: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> isUserRegistered(String eventId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;
    try {
      final result = await _supabase
          .from('event_registrations')
          .select('id')
          .eq('event_id', eventId)
          .eq('user_id', user.id)
          .maybeSingle();
      final isRegistered = result != null;
      if (isRegistered) {
        _registeredEventIds.add(eventId);
      } else {
        _registeredEventIds.remove(eventId);
      }
      return isRegistered;
    } catch (e) {
      return false;
    }
  }

  bool isUserRegisteredSync(String eventId) {
    return _registeredEventIds.contains(eventId);
  }

  List<Event> getEventsByUser(String userId) {
    if (_userEventsCache.containsKey(userId)) {
      return _userEventsCache[userId]!;
    }

    return [];
  }

  bool hasLoadedUserEvents(String userId) {
    return _loadedUsers.contains(userId);
  }

  Future<Event?> getEventById(String eventId) async {
    try {
      final row = await _supabase
          .from('events')
          .select('*')
          .eq('id', eventId)
          .maybeSingle();

      if (row == null) {
        return null;
      }

      final rowMap = row;
      final userId = rowMap['user_id'] as String;
      final profileRow = await _supabase
          .from('user_profiles')
          .select('id, full_name, username, avatar_url')
          .eq('id', userId)
          .maybeSingle();

      Map<String, dynamic>? profile;
      if (profileRow != null) {
        profile = profileRow;
      }
      final userName = profile != null
          ? (profile['full_name'] as String?) ??
              (profile['username'] as String?) ??
              'User'
          : 'User';
      final userAvatar =
          profile != null ? profile['avatar_url'] as String? : null;

      final coHostIds = (rowMap['co_host_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      final coHostNames = <String>[];
      if (coHostIds.isNotEmpty) {
        final coHostProfiles = await _supabase
            .from('user_profiles')
            .select('id, full_name, username')
            .inFilter('id', coHostIds);
        for (final hostProfile in coHostProfiles as List<dynamic>) {
          final hostRow = hostProfile as Map<String, dynamic>;
          coHostNames.add((hostRow['full_name'] as String?) ??
              (hostRow['username'] as String?) ??
              'User');
        }
      }

      return Event.fromSupabaseRow(rowMap,
          userName: userName, userAvatar: userAvatar, coHostNames: coHostNames);
    } catch (e) {
      return null;
    }
  }

  Future<void> loadEventsByUser(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final registrations = await _supabase
          .from('event_registrations')
          .select('event_id')
          .eq('user_id', userId);

      if (registrations.isEmpty) {
        _userEventsCache[userId] = [];
        _loadedUsers.add(userId);
        _isLoading = false;
        notifyListeners();
        return;
      }

      final eventIds = (registrations as List<dynamic>)
          .map((r) => (r as Map<String, dynamic>)['event_id'] as String)
          .toList();

      final List<dynamic> rows = await _supabase
          .from('events')
          .select('*')
          .inFilter('id', eventIds)
          .order('event_date', ascending: true);

      final Set<String> userIds = rows
          .map((r) => (r as Map<String, dynamic>)['user_id'] as String)
          .toSet();

      Map<String, Map<String, dynamic>> userIdToProfile = {};
      if (userIds.isNotEmpty) {
        final profileRows = await _supabase
            .from('user_profiles')
            .select('id, full_name, username, avatar_url')
            .inFilter('id', userIds.toList());
        for (final p in profileRows as List<dynamic>) {
          final row = p as Map<String, dynamic>;
          userIdToProfile[row['id'] as String] = row;
        }
      }

      final userEvents = rows.map((raw) {
        final row = raw as Map<String, dynamic>;
        final profile = userIdToProfile[row['user_id'] as String];
        final userName = profile != null
            ? (profile['full_name'] as String?) ??
                (profile['username'] as String?) ??
                'User'
            : 'User';
        final userAvatar =
            profile != null ? profile['avatar_url'] as String? : null;

        final coHostIds = (row['co_host_ids'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        final coHostNames = <String>[];
        for (final hostId in coHostIds) {
          final hostProfile = userIdToProfile[hostId];
          if (hostProfile != null) {
            coHostNames.add((hostProfile['full_name'] as String?) ??
                (hostProfile['username'] as String?) ??
                'User');
          }
        }

        return Event.fromSupabaseRow(row,
            userName: userName,
            userAvatar: userAvatar,
            coHostNames: coHostNames);
      }).toList();

      _userEventsCache[userId] = userEvents;
      _loadedUsers.add(userId);

      _events.removeWhere((e) => e.userId == userId);
      _events.addAll(userEvents);
      _events.sort((a, b) => a.eventDate.compareTo(b.eventDate));
    } catch (e) {
      _error = 'Failed to load events: ${e.toString()}';

      _loadedUsers.add(userId);
      _userEventsCache[userId] = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
