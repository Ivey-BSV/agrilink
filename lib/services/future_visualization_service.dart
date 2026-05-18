import 'package:supabase_flutter/supabase_flutter.dart';

class FutureVisualizationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String get _currentUserId {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    return user.id;
  }

  Future<Map<String, dynamic>> createFutureVisualization({
    required String title,
    required String intent,
    required String visionDescription,
    required int months,
    required List<String> focusAreas,
    required List<Map<String, dynamic>> milestones,
    String? ask,
    String? offer,
    required bool isPublic,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final visualizationResponse = await _supabase
          .from('future_visualizations')
          .insert({
            'user_id': user.id,
            'title': title,
            'intent': intent,
            'vision_description': visionDescription,
            'months': months,
            'focus_areas': focusAreas,
            'ask': ask,
            'offer': offer,
            'public': isPublic,
          })
          .select()
          .single();

      final visualizationId = visualizationResponse['id'] as String;

      if (milestones.isNotEmpty) {
        final milestoneData = <Map<String, dynamic>>[];
        for (final milestone in milestones) {
          milestoneData.add({
            'future_visualization_id': visualizationId,
            'title': milestone['title'] as String,
            'month_offset': milestone['monthOffset'] as int,
          });
        }

        await _supabase
            .from('future_visualization_milestones')
            .insert(milestoneData);
      }

      return await getFutureVisualizationById(visualizationId);
    } catch (e) {
      throw Exception('Failed to create future visualization: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAllFutureVisualizations() async {
    try {
      final user = _supabase.auth.currentUser;

      final response = await _supabase
          .from('future_visualizations')
          .select('''
            *,
            user_profiles!future_visualizations_user_id_fkey (
              username,
              full_name,
              avatar_url
            ),
            future_visualization_milestones (
              id,
              title,
              month_offset,
              created_at
            )
          ''')
          .or(user != null
              ? 'public.eq.true,user_id.eq.${user.id}'
              : 'public.eq.true')
          .order('created_at', ascending: false)
          .order('month_offset',
              ascending: true,
              referencedTable: 'future_visualization_milestones');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch future visualizations: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getCommunityPlans() async {
    try {
      final response = await _supabase
          .from('future_visualizations')
          .select('''
            *,
            user_profiles!future_visualizations_user_id_fkey (
              username,
              full_name,
              avatar_url
            ),
            future_visualization_milestones (
              id,
              title,
              month_offset,
              created_at
            )
          ''')
          .eq('public', true)
          .order('created_at', ascending: false)
          .order('month_offset',
              ascending: true,
              referencedTable: 'future_visualization_milestones');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch community plans: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getMyPrivatePlans() async {
    try {
      final response = await _supabase
          .from('future_visualizations')
          .select('''
            *,
            user_profiles!future_visualizations_user_id_fkey (
              username,
              full_name,
              avatar_url
            ),
            future_visualization_milestones (
              id,
              title,
              month_offset,
              created_at
            )
          ''')
          .eq('user_id', _currentUserId)
          .eq('public', false)
          .order('created_at', ascending: false)
          .order('month_offset',
              ascending: true,
              referencedTable: 'future_visualization_milestones');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch personal plans: $e');
    }
  }

  Future<Map<String, dynamic>> getFutureVisualizationById(String id) async {
    try {
      final user = _supabase.auth.currentUser;

      final response = await _supabase.from('future_visualizations').select('''
            *,
            user_profiles!future_visualizations_user_id_fkey (
              username,
              full_name,
              avatar_url
            ),
            future_visualization_milestones (
              id,
              title,
              month_offset,
              created_at
            )
          ''').eq('id', id).maybeSingle();

      if (response == null) {
        throw Exception('Future visualization not found');
      }

      final plan = response;
      final isPublic = plan['public'] as bool? ?? false;
      final userId = plan['user_id'] as String?;

      if (!isPublic && (user == null || userId != user.id)) {
        throw Exception('Access denied: This is a personal plan');
      }

      return response;
    } catch (e) {
      throw Exception('Failed to fetch future visualization: $e');
    }
  }

  Future<Map<String, dynamic>> updateFutureVisualization({
    required String id,
    String? title,
    String? intent,
    String? visionDescription,
    int? months,
    List<String>? focusAreas,
    String? ask,
    String? offer,
    bool? isPublic,
    List<Map<String, dynamic>>? milestones,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final existing = await _supabase
          .from('future_visualizations')
          .select('user_id')
          .eq('id', id)
          .single();

      if (existing['user_id'] != user.id) {
        throw Exception('You can only update your own plans');
      }

      final updateData = <String, dynamic>{};
      if (title != null) updateData['title'] = title;
      if (intent != null) updateData['intent'] = intent;
      if (visionDescription != null) {
        updateData['vision_description'] = visionDescription;
      }
      if (months != null) updateData['months'] = months;
      if (focusAreas != null) updateData['focus_areas'] = focusAreas;
      if (ask != null) updateData['ask'] = ask;
      if (offer != null) updateData['offer'] = offer;
      if (isPublic != null) updateData['public'] = isPublic;
      updateData['updated_at'] = DateTime.now().toIso8601String();

      if (updateData.isNotEmpty) {
        await _supabase
            .from('future_visualizations')
            .update(updateData)
            .eq('id', id);
      }

      if (milestones != null) {
        await _supabase
            .from('future_visualization_milestones')
            .delete()
            .eq('future_visualization_id', id);

        if (milestones.isNotEmpty) {
          final milestoneData = <Map<String, dynamic>>[];
          for (final milestone in milestones) {
            milestoneData.add({
              'future_visualization_id': id,
              'title': milestone['title'] as String,
              'month_offset': milestone['monthOffset'] as int,
            });
          }
          await _supabase
              .from('future_visualization_milestones')
              .insert(milestoneData);
        }
      }

      return await getFutureVisualizationById(id);
    } catch (e) {
      throw Exception('Failed to update future visualization: $e');
    }
  }

  Future<void> deleteFutureVisualization(String id) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final existing = await _supabase
          .from('future_visualizations')
          .select('user_id')
          .eq('id', id)
          .single();

      if (existing['user_id'] != user.id) {
        throw Exception('You can only delete your own plans');
      }

      await _supabase.from('future_visualizations').delete().eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete future visualization: $e');
    }
  }

  Map<String, dynamic> formatVisualizationForUI(
      Map<String, dynamic> visualization) {
    final milestones = List<Map<String, dynamic>>.from(
        visualization['future_visualization_milestones'] ?? []);

    milestones.sort((a, b) {
      final aOffset = a['month_offset'] as int? ?? 0;
      final bOffset = b['month_offset'] as int? ?? 0;
      return aOffset.compareTo(bOffset);
    });

    final milestoneDetails = milestones
        .map((m) => {
              'title': m['title'] as String,
              'monthOffset': m['month_offset'] as int,
            })
        .toList();

    final userProfile = visualization['user_profiles'];
    final owner = userProfile != null
        ? (userProfile['full_name'] ??
            userProfile['username'] ??
            'Unknown User')
        : 'Unknown User';

    DateTime? createdAt;
    try {
      if (visualization['created_at'] != null) {
        final dateStr = visualization['created_at'] as String;
        createdAt = DateTime.parse(dateStr);
      }
    } catch (e) {
      createdAt = DateTime.now();
    }

    return {
      'id': visualization['id'],
      'title': visualization['title'],
      'intent': visualization['intent'],
      'visionDescription': visualization['vision_description'],
      'months': visualization['months'],
      'focus': List<String>.from(visualization['focus_areas'] ?? []),
      'milestoneDetails': milestoneDetails,
      'ask': visualization['ask'],
      'offer': visualization['offer'],
      'public': visualization['public'] ?? true,
      'owner': owner,
      'createdAt': createdAt ?? DateTime.now(),
      'user_id': visualization['user_id'],
      'user_profiles': userProfile,
    };
  }
}
