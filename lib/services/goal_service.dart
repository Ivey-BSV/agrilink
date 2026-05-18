import 'package:postgrest/postgrest.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cap/shared/constants/circle_roles.dart';

class GoalService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<bool> testConnection() async {
    try {
      await _supabase.from('goals').select('count').limit(1);
      return true;
    } catch (e) {
      return false;
    }
  }

  String get _currentUserId {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    return user.id;
  }

  Future<Map<String, dynamic>> createGoal({
    required String title,
    required String description,
    required String goalType,
    required DateTime deadlineDate,
    required List<Map<String, dynamic>> milestones,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final goalResponse = await _supabase
          .from('goals')
          .insert({
            'user_id': user.id,
            'title': title,
            'description': description,
            'goal_type': goalType.toLowerCase(),
            'deadline_date': deadlineDate.toIso8601String().split('T')[0],
            'status': 'active',
          })
          .select()
          .single();

      final goalId = goalResponse['id'] as String;

      if (milestones.isNotEmpty) {
        final milestoneData = <Map<String, dynamic>>[];
        for (int i = 0; i < milestones.length; i++) {
          final milestone = milestones[i];
          milestoneData.add({
            'goal_id': goalId,
            'title': milestone['title'],
            'description': milestone['description'] ?? '',
            'completed': milestone['completed'] ?? false,
            'position': i,
          });
        }

        await _supabase.from('goal_milestones').insert(milestoneData);
      }

      if (goalType.toLowerCase() == 'community') {
        await _supabase.from('community_goal_participants').insert({
          'goal_id': goalId,
          'user_id': user.id,
        });
        await ensureCommunityCircleRoles(goalId);
      }

      return goalResponse;
    } catch (e) {
      throw Exception('Failed to create project: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAllGoals() async {
    try {
      final response = await _supabase
          .from('goals')
          .select('''
            *,
            user_profiles!goals_user_id_fkey (
              username,
              full_name,
              avatar_url
            ),
            goal_milestones (
              id,
              title,
              description,
              completed,
              completed_at,
              position
            ),
            community_goal_participants (
              user_id,
              user_profiles!community_goal_participants_user_id_fkey (
                username,
                full_name,
                avatar_url
              )
            )
          ''')
          .order('created_at', ascending: false)
          .order('position',
              ascending: true, referencedTable: 'goal_milestones');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch projects: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getCommunityGoals() async {
    try {
      final response = await _supabase
          .from('goals')
          .select('''
            *,
            user_profiles!goals_user_id_fkey (
              username,
              full_name,
              avatar_url
            ),
            goal_milestones (
              id,
              title,
              description,
              completed,
              completed_at,
              position
            ),
            community_goal_participants (
              user_id,
              user_profiles!community_goal_participants_user_id_fkey (
                username,
                full_name,
                avatar_url
              )
            )
          ''')
          .eq('goal_type', 'community')
          .order('created_at', ascending: false)
          .order('position',
              ascending: true, referencedTable: 'goal_milestones');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      try {
        final response = await _supabase
            .from('goals')
            .select('*')
            .eq('goal_type', 'community')
            .order('created_at', ascending: false);

        return List<Map<String, dynamic>>.from(response);
      } catch (e2) {
        throw Exception('Failed to fetch community projects: $e2');
      }
    }
  }

  Future<List<Map<String, dynamic>>> getPersonalGoals() async {
    try {
      final response = await _supabase
          .from('goals')
          .select('''
            *,
            goal_milestones (
              id,
              title,
              description,
              completed,
              completed_at,
              position
            )
          ''')
          .eq('user_id', _currentUserId)
          .eq('goal_type', 'personal')
          .order('created_at', ascending: false)
          .order('position',
              ascending: true, referencedTable: 'goal_milestones');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      try {
        final response = await _supabase
            .from('goals')
            .select('*')
            .eq('user_id', _currentUserId)
            .eq('goal_type', 'personal')
            .order('created_at', ascending: false);

        return List<Map<String, dynamic>>.from(response);
      } catch (e2) {
        throw Exception('Failed to fetch farm projects: $e2');
      }
    }
  }

  Future<List<Map<String, dynamic>>> getUserPersonalGoals() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('goals')
          .select('''
            *,
            user_profiles!goals_user_id_fkey (
              username,
              full_name,
              avatar_url
            ),
            goal_milestones (
              id,
              title,
              description,
              completed,
              completed_at,
              position
            )
          ''')
          .eq('goal_type', 'personal')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .order('position',
              ascending: true, referencedTable: 'goal_milestones');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch user farm projects: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getUserCommunityGoals() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('goals')
          .select('''
            *,
            user_profiles!goals_user_id_fkey (
              username,
              full_name,
              avatar_url
            ),
            goal_milestones (
              id,
              title,
              description,
              completed,
              completed_at,
              position
            ),
            community_goal_participants (
              user_id,
              user_profiles!community_goal_participants_user_id_fkey (
                username,
                full_name,
                avatar_url
              )
            )
          ''')
          .eq('goal_type', 'community')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch user community projects: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getJoinedCommunityGoals() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final response =
          await _supabase.from('community_goal_participants').select('''
            goal_id,
            goals!community_goal_participants_goal_id_fkey (
              *,
              user_profiles!goals_user_id_fkey (
                username,
                full_name,
                avatar_url
              ),
              goal_milestones (
                id,
                title,
                description,
                completed,
                completed_at
              ),
              community_goal_participants (
                user_id,
                user_profiles!community_goal_participants_user_id_fkey (
                  username,
                  full_name,
                  avatar_url
                )
              )
            )
          ''').eq('user_id', user.id);

      return response
          .map((item) => item['goals'] as Map<String, dynamic>)
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch joined community projects: $e');
    }
  }

  Future<void> joinCommunityGoal(String goalId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await _supabase.from('community_goal_participants').insert({
        'goal_id': goalId,
        'user_id': user.id,
      });
    } catch (e) {
      throw Exception('Failed to join community project: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getCommunityGoalCircleRoles(
    String goalId,
  ) async {
    final res = await _supabase.from('community_goal_circle_roles').select('''
          id,
          role,
          user_id,
          updated_at,
          user_profiles!community_goal_circle_roles_user_id_fkey (
            username,
            full_name,
            avatar_url
          )
        ''').eq('goal_id', goalId);
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<void> ensureCommunityCircleRoles(String goalId) async {
    for (final role in kCommunityCircleRoleSlugs) {
      try {
        await _supabase.from('community_goal_circle_roles').insert({
          'goal_id': goalId,
          'role': role,
        });
      } on PostgrestException catch (e) {
        final code = e.code?.toString();
        if (code != '23505') rethrow;
      }
    }
  }

  List<Map<String, dynamic>> parseCircleRolesFromGoal(
    Map<String, dynamic> goalData,
  ) {
    final raw = goalData['community_goal_circle_roles'];
    if (raw is! List) return [];
    final rows = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    rows.sort((a, b) {
      final ra = a['role'] as String? ?? '';
      final rb = b['role'] as String? ?? '';
      final ia = kCommunityCircleRoleSlugs.indexOf(ra);
      final ib = kCommunityCircleRoleSlugs.indexOf(rb);
      return (ia == -1 ? 99 : ia).compareTo(ib == -1 ? 99 : ib);
    });
    return rows;
  }

  Future<void> setCommunityCircleRoleUser({
    required String goalId,
    required String role,
    required String? userId,
  }) async {
    await _supabase
        .from('community_goal_circle_roles')
        .update({
          'user_id': userId,
        })
        .eq('goal_id', goalId)
        .eq('role', role);
  }

  Future<void> claimCommunityCircleRole(String goalId, String role) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    await setCommunityCircleRoleUser(
      goalId: goalId,
      role: role,
      userId: user.id,
    );
  }

  Future<void> releaseCommunityCircleRole(String goalId, String role) async {
    await setCommunityCircleRoleUser(
      goalId: goalId,
      role: role,
      userId: null,
    );
  }

  Future<void> leaveCommunityGoal(String goalId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await _supabase
          .from('community_goal_circle_roles')
          .update({
            'user_id': null,
          })
          .eq('goal_id', goalId)
          .eq('user_id', user.id);

      await _supabase
          .from('community_goal_participants')
          .delete()
          .eq('goal_id', goalId)
          .eq('user_id', user.id);
    } catch (e) {
      throw Exception('Failed to leave community project: $e');
    }
  }

  Future<bool> hasJoinedCommunityGoal(String goalId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final response = await _supabase
          .from('community_goal_participants')
          .select('id')
          .eq('goal_id', goalId)
          .eq('user_id', user.id)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  Future<void> updateMilestoneStatus(String milestoneId, bool completed) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await _supabase.from('goal_milestones').update({
        'completed': completed,
        'completed_at': completed ? DateTime.now().toIso8601String() : null,
      }).eq('id', milestoneId);

      if (completed) {
        await _supabase.from('milestone_completions').upsert({
          'milestone_id': milestoneId,
          'user_id': user.id,
          'completed_at': DateTime.now().toIso8601String(),
        });
      } else {
        await _supabase
            .from('milestone_completions')
            .delete()
            .eq('milestone_id', milestoneId)
            .eq('user_id', user.id);
      }
    } catch (e) {
      throw Exception('Failed to update milestone status: $e');
    }
  }

  Future<void> updateGoalCompletionStatus(String goalId, bool completed) async {
    try {
      await _supabase.from('goals').update({
        'status': completed ? 'completed' : 'active',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', goalId);
    } catch (e) {
      throw Exception('Failed to update project completion status: $e');
    }
  }

  Future<Map<String, dynamic>> getGoalById(String goalId) async {
    try {
      final response = await _supabase
          .from('goals')
          .select('''
            *,
            user_profiles!goals_user_id_fkey (
              username,
              full_name,
              avatar_url
            ),
            goal_milestones (
              id,
              title,
              description,
              completed,
              completed_at
            ),
            community_goal_participants (
              user_id,
              user_profiles!community_goal_participants_user_id_fkey (
                username,
                full_name,
                avatar_url
              )
            )
          ''')
          .eq('id', goalId)
          .order('position',
              ascending: true, referencedTable: 'goal_milestones')
          .single();

      return response;
    } catch (e) {
      throw Exception('Failed to fetch project: $e');
    }
  }

  Future<void> deleteGoal(String goalId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final goal = await _supabase
          .from('goals')
          .select('user_id')
          .eq('id', goalId)
          .single();

      if (goal['user_id'] != user.id) {
        throw Exception('You can only delete your own projects');
      }

      await _supabase.from('goals').delete().eq('id', goalId);
    } catch (e) {
      throw Exception('Failed to delete project: $e');
    }
  }

  Future<Map<String, int>> getParticipantContributions(String goalId) async {
    try {
      final milestones = await _supabase
          .from('goal_milestones')
          .select('id')
          .eq('goal_id', goalId);

      if (milestones.isEmpty) return {};

      final milestoneIds = milestones.map((m) => m['id'] as String).toList();

      final completions = await _supabase
          .from('milestone_completions')
          .select('user_id')
          .inFilter('milestone_id', milestoneIds);

      final Map<String, int> contributions = {};
      for (final completion in completions) {
        final userId = completion['user_id'] as String;
        contributions[userId] = (contributions[userId] ?? 0) + 1;
      }

      return contributions;
    } catch (e) {
      throw Exception('Failed to get participant contributions: $e');
    }
  }

  double calculateProgress(List<Map<String, dynamic>> milestones) {
    if (milestones.isEmpty) return 0.0;

    final completedCount =
        milestones.where((m) => m['completed'] == true).length;
    return completedCount / milestones.length;
  }

  Map<String, dynamic> formatGoalForUI(Map<String, dynamic> goal) {
    final milestones =
        List<Map<String, dynamic>>.from(goal['goal_milestones'] ?? []);

    milestones.sort((a, b) {
      final aPos = a['position'] as int?;
      final bPos = b['position'] as int?;
      if (aPos != null && bPos != null) {
        return aPos.compareTo(bPos);
      }
      final aCreated = a['created_at'] as String?;
      final bCreated = b['created_at'] as String?;
      if (aCreated != null && bCreated != null) {
        return DateTime.parse(aCreated).compareTo(DateTime.parse(bCreated));
      }
      return 0;
    });
    final progress = calculateProgress(milestones);

    final deadlineDate = DateTime.parse(goal['deadline_date']);
    final deadline =
        '${deadlineDate.month}/${deadlineDate.day}/${deadlineDate.year}';

    final userProfile = goal['user_profiles'];
    final author = userProfile != null
        ? userProfile['full_name'] ?? userProfile['username']
        : 'Unknown User';

    final authorAvatarUrl = userProfile?['avatar_url'];
    final authorUserId = goal['user_id'];

    final participants = goal['goal_type'] == 'community'
        ? List<Map<String, dynamic>>.from(
            goal['community_goal_participants'] ?? [])
        : <Map<String, dynamic>>[];

    return {
      'id': goal['id'],
      'title': goal['title'],
      'description': goal['description'],
      'goal_type': goal['goal_type'],
      'deadline': deadline,
      'deadlineDate': deadlineDate,
      'status': goal['status'],
      'progress': progress,
      'author': author,
      'authorAvatarUrl': authorAvatarUrl,
      'authorUserId': authorUserId,
      'participants': participants.length,
      'milestones': milestones,
      'created_at': goal['created_at'],
      'updated_at': goal['updated_at'],
    };
  }
}
