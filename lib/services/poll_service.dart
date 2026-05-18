import 'package:supabase_flutter/supabase_flutter.dart';

class PollService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String? get _uid => _supabase.auth.currentUser?.id;

  Future<List<Map<String, dynamic>>> listPolls({int limit = 50}) async {
    final res = await _supabase.from('polls').select('''
          id,
          title,
          description,
          allows_multiple,
          status,
          closes_at,
          created_at,
          created_by,
          user_profiles (
            username,
            full_name,
            avatar_url
          )
        ''').order('created_at', ascending: false).limit(limit);
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<Map<String, dynamic>> getPollDetail(String pollId) async {
    final res = await _supabase.from('polls').select('''
          *,
          user_profiles (
            username,
            full_name,
            avatar_url
          ),
          poll_options (
            id,
            label,
            position
          ),
          poll_votes (
            option_id,
            user_id
          )
        ''').eq('id', pollId).single();

    final map = Map<String, dynamic>.from(res as Map);
    final opts = List<Map<String, dynamic>>.from(map['poll_options'] ?? []);
    opts.sort((a, b) {
      final pa = a['position'] as int? ?? 0;
      final pb = b['position'] as int? ?? 0;
      return pa.compareTo(pb);
    });
    map['poll_options'] = opts;
    return map;
  }

  Future<String> createPoll({
    required String title,
    String? description,
    required bool allowsMultiple,
    DateTime? closesAt,
    required List<String> optionLabels,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Sign in to create a poll.');

    final cleaned =
        optionLabels.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (cleaned.length < 2) {
      throw Exception('Add at least two answer choices.');
    }

    final insert = <String, dynamic>{
      'created_by': uid,
      'title': title.trim(),
      'allows_multiple': allowsMultiple,
    };
    final desc = description?.trim();
    if (desc != null && desc.isNotEmpty) {
      insert['description'] = desc;
    }
    if (closesAt != null) {
      insert['closes_at'] = closesAt.toUtc().toIso8601String();
    }

    final pollRow =
        await _supabase.from('polls').insert(insert).select('id').single();

    final pollId = pollRow['id'] as String;
    final rows = <Map<String, dynamic>>[];
    for (var i = 0; i < cleaned.length; i++) {
      rows.add({
        'poll_id': pollId,
        'label': cleaned[i],
        'position': i,
      });
    }
    if (rows.length < 2) {
      await _supabase.from('polls').delete().eq('id', pollId);
      throw Exception('Add at least two non-empty answer choices.');
    }

    await _supabase.from('poll_options').insert(rows);
    return pollId;
  }

  Future<void> submitVote({
    required String pollId,
    required List<String> optionIds,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Sign in to vote.');

    final detail = await getPollDetail(pollId);
    if (detail['status'] != 'active') {
      throw Exception('This poll is closed.');
    }
    final closesAt = detail['closes_at'] as String?;
    if (closesAt != null) {
      final end = DateTime.tryParse(closesAt);
      if (end != null && DateTime.now().toUtc().isAfter(end.toUtc())) {
        throw Exception('This poll has ended.');
      }
    }

    final allows = detail['allows_multiple'] == true;
    if (!allows && optionIds.length > 1) {
      throw Exception('This poll only allows one answer.');
    }
    if (optionIds.isEmpty) {
      await _supabase.from('poll_votes').delete().eq('poll_id', pollId).eq(
            'user_id',
            uid,
          );
      return;
    }

    final validIds = (detail['poll_options'] as List)
        .map((e) => (e as Map)['id'] as String)
        .toSet();
    for (final id in optionIds) {
      if (!validIds.contains(id)) {
        throw Exception('Invalid answer choice.');
      }
    }

    await _supabase.from('poll_votes').delete().eq('poll_id', pollId).eq(
          'user_id',
          uid,
        );

    final inserts = optionIds
        .map(
          (oid) => {
            'poll_id': pollId,
            'user_id': uid,
            'option_id': oid,
          },
        )
        .toList();
    await _supabase.from('poll_votes').insert(inserts);
  }

  Future<void> closePoll(String pollId) async {
    final uid = _uid;
    if (uid == null) throw Exception('Sign in to manage polls.');
    await _supabase
        .from('polls')
        .update({
          'status': 'closed',
        })
        .eq('id', pollId)
        .eq('created_by', uid);
  }

  Future<void> deletePoll(String pollId) async {
    final uid = _uid;
    if (uid == null) throw Exception('Sign in to manage polls.');
    await _supabase
        .from('polls')
        .delete()
        .eq('id', pollId)
        .eq('created_by', uid);
  }

  Set<String> mySelectedOptionIds(
    Map<String, dynamic> detail,
    String userId,
  ) {
    final votes = detail['poll_votes'];
    if (votes is! List) return {};
    final out = <String>{};
    for (final v in votes) {
      final m = v as Map<String, dynamic>;
      if (m['user_id'] == userId) {
        final oid = m['option_id'] as String?;
        if (oid != null) out.add(oid);
      }
    }
    return out;
  }

  Map<String, int> voteCountsByOptionId(Map<String, dynamic> detail) {
    final votes = detail['poll_votes'];
    final counts = <String, int>{};
    if (votes is! List) return counts;
    for (final v in votes) {
      final m = v as Map<String, dynamic>;
      final oid = m['option_id'] as String?;
      if (oid == null) continue;
      counts[oid] = (counts[oid] ?? 0) + 1;
    }
    return counts;
  }

  int totalVotes(Map<String, int> counts) =>
      counts.values.fold(0, (a, b) => a + b);

  String creatorLabel(Map<String, dynamic> detail) {
    final p = detail['user_profiles'];
    if (p is Map) {
      final n = (p['full_name'] as String?)?.trim();
      if (n != null && n.isNotEmpty) return n;
      final u = (p['username'] as String?)?.trim();
      if (u != null && u.isNotEmpty) return u.startsWith('@') ? u : '@$u';
    }
    return 'Member';
  }
}
