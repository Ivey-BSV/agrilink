import 'package:supabase_flutter/supabase_flutter.dart';

Future<Set<String>> blockedUserIdsForCurrentUser(
    SupabaseClient supabase) async {
  final user = supabase.auth.currentUser;
  if (user == null) return <String>{};
  try {
    final rows = await supabase
        .from('user_blocks')
        .select('blocker_id, blocked_id')
        .or('blocker_id.eq.${user.id},blocked_id.eq.${user.id}');
    final Set<String> ids = <String>{};
    for (final raw in rows as List<dynamic>) {
      final row = raw as Map<String, dynamic>;
      final blocker = row['blocker_id'] as String;
      final blocked = row['blocked_id'] as String;
      if (blocker == user.id) {
        ids.add(blocked);
      } else if (blocked == user.id) {
        ids.add(blocker);
      }
    }
    return ids;
  } catch (_) {
    return <String>{};
  }
}
