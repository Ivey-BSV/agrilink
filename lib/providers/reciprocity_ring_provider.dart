import 'package:cap/shared/utils/avatar_utils.dart';
import 'package:cap/shared/utils/relative_time_format.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReciprocityRingProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _asks = [];
  List<Map<String, dynamic>> _offers = [];
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get asks => _asks;
  List<Map<String, dynamic>> get offers => _offers;
  bool get isLoading => _isLoading;
  String? get error => _error;

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> loadAsks() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final List<dynamic> askRows = await _supabase
          .from('reciprocity_ring_asks')
          .select('*')
          .order('created_at', ascending: false);

      final Set<String> userIds = askRows
          .map((r) => (r as Map<String, dynamic>)['user_id'] as String)
          .toSet();
      final Set<String> askIds = askRows
          .map((r) => (r as Map<String, dynamic>)['id'] as String)
          .toSet();

      Map<String, Map<String, dynamic>> userIdToProfile = {};
      if (userIds.isNotEmpty) {
        final profileRows = await _supabase
            .from('user_profiles')
            .select('id, full_name, username, avatar_url, location')
            .inFilter('id', userIds.toList());
        for (final p in profileRows as List<dynamic>) {
          final row = p as Map<String, dynamic>;
          userIdToProfile[row['id'] as String] = row;
        }
      }

      Map<String, List<Map<String, dynamic>>> askResponses = {};
      if (askIds.isNotEmpty) {
        final List<dynamic> responseRows = await _supabase
            .from('reciprocity_ring_responses')
            .select('*')
            .inFilter('ask_id', askIds.toList())
            .order('created_at', ascending: false);

        final Set<String> responseUserIds = responseRows
            .map((r) => (r as Map<String, dynamic>)['user_id'] as String)
            .toSet();

        Map<String, Map<String, dynamic>> responseUserProfiles = {};
        if (responseUserIds.isNotEmpty) {
          final responseProfileRows = await _supabase
              .from('user_profiles')
              .select('id, full_name, username, avatar_url')
              .inFilter('id', responseUserIds.toList());
          for (final p in responseProfileRows as List<dynamic>) {
            final row = p as Map<String, dynamic>;
            responseUserProfiles[row['id'] as String] = row;
          }
        }

        for (final response in responseRows) {
          final row = response as Map<String, dynamic>;
          final askId = row['ask_id'] as String;
          final responseUserId = row['user_id'] as String;
          final profile = responseUserProfiles[responseUserId];

          if (!askResponses.containsKey(askId)) {
            askResponses[askId] = [];
          }

          final responderName = profile != null
              ? (profile['full_name'] as String?) ??
                  (profile['username'] as String?) ??
                  'User'
              : 'User';
          final avatar = avatarInitialLetter(responderName);

          askResponses[askId]!.add({
            'responder': responderName,
            'avatar': avatar,
            'response': row['response'] as String,
            'time':
                formatFriendlyRelativeTimeFromIso(row['created_at'] as String),
            'created_at': row['created_at'] as String,
          });
        }
      }

      _asks = askRows.map((raw) {
        final row = raw as Map<String, dynamic>;
        final userId = row['user_id'] as String;
        final profile = userIdToProfile[userId];
        final askId = row['id'] as String;

        final ownerName = profile != null
            ? (profile['full_name'] as String?) ??
                (profile['username'] as String?) ??
                'User'
            : 'User';
        final avatar = avatarInitialLetter(ownerName);
        final location =
            row['location'] as String? ?? profile?['location'] as String?;

        return {
          'id': askId,
          'user_id': userId,
          'owner': ownerName,
          'avatar': avatar,
          'location': location ?? '',
          'need': row['need'] as String,
          'tags': (row['tags'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [],
          'responses': askResponses[askId] ?? [],
          'time': row['timing'] as String,
          'created_at': row['created_at'] as String,
        };
      }).toList();
    } catch (e) {
      _error = 'Failed to load asks: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadOffers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final List<dynamic> offerRows = await _supabase
          .from('reciprocity_ring_offers')
          .select('*')
          .order('created_at', ascending: false);

      final Set<String> userIds = offerRows
          .map((r) => (r as Map<String, dynamic>)['user_id'] as String)
          .toSet();
      final Set<String> offerIds = offerRows
          .map((r) => (r as Map<String, dynamic>)['id'] as String)
          .toSet();

      Map<String, Map<String, dynamic>> userIdToProfile = {};
      if (userIds.isNotEmpty) {
        final profileRows = await _supabase
            .from('user_profiles')
            .select('id, full_name, username, avatar_url, location')
            .inFilter('id', userIds.toList());
        for (final p in profileRows as List<dynamic>) {
          final row = p as Map<String, dynamic>;
          userIdToProfile[row['id'] as String] = row;
        }
      }

      Map<String, List<Map<String, dynamic>>> offerInterests = {};
      if (offerIds.isNotEmpty) {
        final List<dynamic> interestRows = await _supabase
            .from('reciprocity_ring_interests')
            .select('*')
            .inFilter('offer_id', offerIds.toList())
            .order('created_at', ascending: false);

        final Set<String> interestUserIds = interestRows
            .map((r) => (r as Map<String, dynamic>)['user_id'] as String)
            .toSet();

        Map<String, Map<String, dynamic>> interestUserProfiles = {};
        if (interestUserIds.isNotEmpty) {
          final interestProfileRows = await _supabase
              .from('user_profiles')
              .select('id, full_name, username, avatar_url')
              .inFilter('id', interestUserIds.toList());
          for (final p in interestProfileRows as List<dynamic>) {
            final row = p as Map<String, dynamic>;
            interestUserProfiles[row['id'] as String] = row;
          }
        }

        for (final interest in interestRows) {
          final row = interest as Map<String, dynamic>;
          final offerId = row['offer_id'] as String;
          final interestUserId = row['user_id'] as String;
          final profile = interestUserProfiles[interestUserId];

          if (!offerInterests.containsKey(offerId)) {
            offerInterests[offerId] = [];
          }

          final interestedName = profile != null
              ? (profile['full_name'] as String?) ??
                  (profile['username'] as String?) ??
                  'User'
              : 'User';
          final avatar = avatarInitialLetter(interestedName);

          offerInterests[offerId]!.add({
            'user_id': interestUserId,
            'interested': interestedName,
            'avatar': avatar,
            'message': row['message'] as String,
            'time':
                formatFriendlyRelativeTimeFromIso(row['created_at'] as String),
            'created_at': row['created_at'] as String,
          });
        }
      }

      _offers = offerRows.map((raw) {
        final row = raw as Map<String, dynamic>;
        final userId = row['user_id'] as String;
        final profile = userIdToProfile[userId];
        final offerId = row['id'] as String;

        final ownerName = profile != null
            ? (profile['full_name'] as String?) ??
                (profile['username'] as String?) ??
                'User'
            : 'User';
        final avatar = avatarInitialLetter(ownerName);
        final location =
            row['location'] as String? ?? profile?['location'] as String?;

        return {
          'id': offerId,
          'user_id': userId,
          'owner': ownerName,
          'avatar': avatar,
          'location': location ?? '',
          'offer': row['offer'] as String,
          'description': row['description'] as String?,
          'window': row['window'] as String,
          'tags': (row['tags'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [],
          'interests': offerInterests[offerId] ?? [],
          'created_at': row['created_at'] as String,
        };
      }).toList();
    } catch (e) {
      _error = 'Failed to load offers: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createAsk({
    required String userId,
    required String need,
    required String timing,
    String? location,
    List<String>? tags,
  }) async {
    try {
      await _supabase
          .from('reciprocity_ring_asks')
          .insert({
            'user_id': userId,
            'need': need,
            'timing': timing,
            'location': location,
            'tags': tags ?? [],
          })
          .select()
          .single();

      await loadAsks();
      return true;
    } catch (e) {
      _error = 'Failed to create ask: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteAsk(String askId) async {
    try {
      await _supabase.from('reciprocity_ring_asks').delete().eq('id', askId);
      await loadAsks();
      return true;
    } catch (e) {
      _error = 'Failed to delete ask: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> createOffer({
    required String userId,
    required String offer,
    required String window,
    String? description,
    String? location,
    List<String>? tags,
  }) async {
    try {
      await _supabase
          .from('reciprocity_ring_offers')
          .insert({
            'user_id': userId,
            'offer': offer,
            'window': window,
            'description': description,
            'location': location,
            'tags': tags ?? [],
          })
          .select()
          .single();

      await loadOffers();
      return true;
    } catch (e) {
      _error = 'Failed to create offer: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteOffer(String offerId) async {
    try {
      await _supabase
          .from('reciprocity_ring_offers')
          .delete()
          .eq('id', offerId);
      await loadOffers();
      return true;
    } catch (e) {
      _error = 'Failed to delete offer: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> addResponse({
    required String askId,
    required String userId,
    required String response,
  }) async {
    try {
      await _supabase.from('reciprocity_ring_responses').insert({
        'ask_id': askId,
        'user_id': userId,
        'response': response,
      });

      await loadAsks();
      return true;
    } catch (e) {
      _error = 'Failed to add response: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> addInterest({
    required String offerId,
    required String userId,
    required String message,
  }) async {
    try {
      await _supabase.from('reciprocity_ring_interests').insert({
        'offer_id': offerId,
        'user_id': userId,
        'message': message,
      });

      await loadOffers();
      return true;
    } catch (e) {
      _error = 'Failed to add interest: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  int getInterestCount(Map<String, dynamic> offer) {
    final interests = offer['interests'] as List<dynamic>?;
    if (interests == null || interests.isEmpty) return 0;
    final userIds = <String>{};
    var legacyRows = 0;
    for (final raw in interests) {
      final i = raw as Map<String, dynamic>;
      final uid = i['user_id'] as String?;
      if (uid != null && uid.isNotEmpty) {
        userIds.add(uid);
      } else {
        legacyRows++;
      }
    }
    return userIds.length + legacyRows;
  }

  double getMedianTurnaroundTime() {
    if (_asks.isEmpty) return 0.0;

    final List<double> turnaroundTimes = [];

    for (final ask in _asks) {
      final responses = ask['responses'] as List<dynamic>?;
      if (responses != null && responses.isNotEmpty) {
        try {
          final askCreatedAt = DateTime.parse(ask['created_at'] as String);

          DateTime? earliestResponseTime;
          for (final response in responses) {
            final responseData = response as Map<String, dynamic>;
            final responseCreatedAt =
                DateTime.parse(responseData['created_at'] as String);
            if (earliestResponseTime == null ||
                responseCreatedAt.isBefore(earliestResponseTime)) {
              earliestResponseTime = responseCreatedAt;
            }
          }

          if (earliestResponseTime != null) {
            final difference = earliestResponseTime.difference(askCreatedAt);
            final hours = difference.inHours.toDouble();

            if (hours == 0) {
              turnaroundTimes.add(difference.inMinutes / 60.0);
            } else {
              turnaroundTimes.add(hours);
            }
          }
        } catch (e) {
          continue;
        }
      }
    }

    if (turnaroundTimes.isEmpty) return 0.0;

    turnaroundTimes.sort();
    final middle = turnaroundTimes.length ~/ 2;
    if (turnaroundTimes.length % 2 == 1) {
      return turnaroundTimes[middle];
    } else {
      return (turnaroundTimes[middle - 1] + turnaroundTimes[middle]) / 2.0;
    }
  }

  void clearData() {
    _asks = [];
    _offers = [];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}
