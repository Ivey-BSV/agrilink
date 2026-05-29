import 'package:flutter/material.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/features/collaboration/presentation/pages/create_goal_page.dart';
import 'package:cap/features/collaboration/presentation/pages/goal_detail_page.dart';
import 'package:cap/services/goal_service.dart';
import 'package:cap/shared/widgets/network_circle_avatar.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GoalSettingPage extends StatefulWidget {
  const GoalSettingPage({super.key});

  @override
  State<GoalSettingPage> createState() => _GoalSettingPageState();
}

class _GoalSettingPageState extends State<GoalSettingPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GoalService _goalService = GoalService();

  List<Map<String, dynamic>> _communityGoals = [];
  List<Map<String, dynamic>> _personalGoals = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final connectionOk = await _goalService.testConnection();
      if (!connectionOk) {
        throw Exception('Database connection failed');
      }

      final communityGoals = await _goalService.getCommunityGoals();
      final personalGoals = await _goalService.getPersonalGoals();

      final formattedCommunityGoals = <Map<String, dynamic>>[];
      for (final goal in communityGoals) {
        final formattedGoal = _goalService.formatGoalForUI(goal);

        final hasJoined = await _goalService.hasJoinedCommunityGoal(goal['id']);
        formattedGoal['isJoined'] = hasJoined;
        formattedCommunityGoals.add(formattedGoal);
      }

      final formattedPersonalGoals = personalGoals
          .map((goal) => _goalService.formatGoalForUI(goal))
          .toList();

      if (!mounted) return;
      setState(() {
        _communityGoals = [...formattedCommunityGoals];
        _personalGoals = [...formattedPersonalGoals];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;

        _communityGoals = [];
        _personalGoals = [];
      });
    }
  }

  double _calculateProgress(List<Map<String, dynamic>> milestones) {
    if (milestones.isEmpty) return 0.0;
    int completed = milestones.where((m) => m['completed'] == true).length;
    return completed / milestones.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Projects',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _loadGoals,
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.black),
            onPressed: () {
              final currentTab = _tabController.index;
              final goalType = currentTab == 0 ? 'Community' : 'Personal';

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      CreateGoalPage(initialGoalType: goalType),
                ),
              ).then((_) {
                _loadGoals();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey, width: 0.5),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.primaryGreen,
              labelColor: AppTheme.primaryGreen,
              unselectedLabelColor: Colors.grey,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              tabs: const [
                Tab(text: 'Community Projects'),
                Tab(text: 'Farm Projects'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCommunityGoalsTab(),
                _buildPersonalGoalsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityGoalsTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Failed to load community projects',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Showing demo data',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadGoals,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final sortedGoals = List<Map<String, dynamic>>.from(_communityGoals);
    sortedGoals.sort((a, b) {
      final aJoined = a['isJoined'] ?? false;
      final bJoined = b['isJoined'] ?? false;

      if (aJoined != bJoined) {
        return bJoined ? 1 : -1;
      }

      return (a['deadlineDate'] as DateTime)
          .compareTo(b['deadlineDate'] as DateTime);
    });

    return RefreshIndicator(
      onRefresh: _loadGoals,
      color: AppTheme.primaryGreen,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (sortedGoals.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(48),
                  child: Column(
                    children: [
                      Icon(
                        Icons.groups,
                        size: 80,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No community projects yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Be the first to create a community project or wait for others to share theirs',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...sortedGoals.map((goal) => _buildCommunityGoalCard(goal)),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalGoalsTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Failed to load farm projects',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadGoals,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final sortedGoals = List<Map<String, dynamic>>.from(_personalGoals);
    sortedGoals.sort((a, b) {
      return (a['deadlineDate'] as DateTime)
          .compareTo(b['deadlineDate'] as DateTime);
    });

    return RefreshIndicator(
      onRefresh: _loadGoals,
      color: AppTheme.primaryGreen,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (sortedGoals.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(48),
                  child: Column(
                    children: [
                      Icon(
                        Icons.task_alt,
                        size: 80,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No farm projects yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create your first farm project to track your farming progress',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...sortedGoals.map((goal) => _buildPersonalGoalCard(goal)),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunityGoalCard(Map<String, dynamic> goal) {
    final isCompleted = goal['status'] == 'completed';
    final progress = _calculateProgress(goal['milestones']);
    final canComplete = !isCompleted && progress >= 1.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.grainGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Community',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.grainGold,
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.groups, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${goal['participants']} ${goal['participants'] == 1 ? 'participant' : 'participants'}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              goal['title'],
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              goal['description'],
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progress',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Text(
                      '${(_calculateProgress(goal['milestones']) * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 8,
                    child: LinearProgressIndicator(
                      value: _calculateProgress(goal['milestones']),
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryGreen,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                GestureDetector(
                  onTap: goal['authorUserId'] != null
                      ? () {
                          context.push('/user-profile/${goal['authorUserId']}');
                        }
                      : null,
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.primaryGradient,
                    ),
                    child: NetworkCircleAvatar(
                      radius: 16,
                      imageUrl: goal['authorAvatarUrl'] as String?,
                      fallbackLetter: goal['author'][0],
                      fallbackTextStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: goal['authorUserId'] != null
                      ? () {
                          context.push('/user-profile/${goal['authorUserId']}');
                        }
                      : null,
                  child: Text(
                    goal['author'],
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      goal['deadline'],
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (isCompleted) {
                        _confirmUncompleteGoal(goal);
                      } else if (canComplete) {
                        _confirmCompleteGoal(goal);
                      } else {
                        goal['isJoined']
                            ? _confirmLeave(goal)
                            : _confirmJoin(goal);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? AppTheme.grainGold
                            : canComplete
                                ? AppTheme.primaryGreen
                                : ((goal['isJoined'] ?? false)
                                    ? AppTheme.primaryGreen
                                    : Colors.transparent),
                        border: Border.all(
                          color: isCompleted
                              ? AppTheme.grainGold
                              : canComplete
                                  ? AppTheme.primaryGreen
                                  : ((goal['isJoined'] ?? false)
                                      ? AppTheme.primaryGreen
                                      : AppTheme.primaryGreen),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isCompleted) ...[
                            Icon(Icons.check_circle,
                                size: 18, color: Colors.white),
                            const SizedBox(width: 6),
                          ] else if (canComplete) ...[
                            Icon(Icons.check_circle_outline,
                                size: 18, color: Colors.white),
                            const SizedBox(width: 6),
                          ] else if (goal['isJoined'] ?? false) ...[
                            Icon(Icons.check, size: 18, color: Colors.white),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            isCompleted
                                ? 'Completed'
                                : canComplete
                                    ? 'Complete Project'
                                    : ((goal['isJoined'] ?? false)
                                        ? 'Joined'
                                        : 'Join Project'),
                            style: TextStyle(
                              color: isCompleted
                                  ? Colors.white
                                  : canComplete
                                      ? Colors.white
                                      : ((goal['isJoined'] ?? false)
                                          ? Colors.white
                                          : AppTheme.primaryGreen),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _navigateToGoalDetails(goal),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryGreen,
                      side:
                          BorderSide(color: AppTheme.primaryGreen, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('View Details'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalGoalCard(Map<String, dynamic> goal) {
    final isCompleted = goal['status'] == 'completed';
    final progress = _calculateProgress(goal['milestones']);
    final canComplete = !isCompleted && progress >= 1.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Farm',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      goal['deadline'],
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              goal['title'],
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              goal['description'],
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progress',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Text(
                      '${(_calculateProgress(goal['milestones']) * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 8,
                    child: LinearProgressIndicator(
                      value: _calculateProgress(goal['milestones']),
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryGreen,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (canComplete || isCompleted) ...[
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (isCompleted) {
                          _confirmUncompleteGoal(goal);
                        } else {
                          _confirmCompleteGoal(goal);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color:
                              isCompleted ? Colors.blue : AppTheme.primaryGreen,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isCompleted) ...[
                              Icon(Icons.check_circle,
                                  size: 18, color: Colors.white),
                              const SizedBox(width: 6),
                            ] else ...[
                              Icon(Icons.check_circle_outline,
                                  size: 18, color: Colors.white),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              isCompleted ? 'Completed' : 'Complete Project',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _navigateToPersonalGoalDetails(goal),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryGreen,
                        side: BorderSide(
                            color: AppTheme.primaryGreen, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('View Details'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _navigateToPersonalGoalDetails(goal),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryGreen,
                    side: BorderSide(color: AppTheme.primaryGreen, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('View Details'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _joinCommunityGoal(Map<String, dynamic> goal) async {
    try {
      await _goalService.joinCommunityGoal(goal['id']);
      if (!mounted) return;
      setState(() {
        goal['participants'] = (goal['participants'] ?? 0) + 1;
        goal['isJoined'] = true;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
          SnackBar(content: Text('Joined "${goal['title']}" project!')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to join project: $e')));
    }
  }

  void _leaveCommunityGoal(Map<String, dynamic> goal) async {
    try {
      await _goalService.leaveCommunityGoal(goal['id']);
      if (!mounted) return;
      setState(() {
        goal['participants'] = (goal['participants'] ?? 1) - 1;
        goal['isJoined'] = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
          SnackBar(content: Text('Left "${goal['title']}" project!')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to leave project: $e')));
    }
  }

  void _confirmUncompleteGoal(Map<String, dynamic> goal) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Uncomplete Project'),
          content: Text(
              'Are you sure you want to mark "${goal['title']}" as incomplete?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _uncompleteGoal(goal);
              },
              child: const Text('Uncomplete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _uncompleteGoal(Map<String, dynamic> goal) async {
    try {
      if (goal['id'] != null && !goal['id'].toString().startsWith('demo_')) {
        await _goalService.updateGoalCompletionStatus(goal['id'], false);
      }

      if (!mounted) return;
      setState(() {
        goal['status'] = 'active';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Project "${goal['title']}" marked as incomplete!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _completeGoal(Map<String, dynamic> goal) async {
    try {
      if (goal['id'] != null && !goal['id'].toString().startsWith('demo_')) {
        await _goalService.updateGoalCompletionStatus(goal['id'], true);
      }

      if (!mounted) return;
      setState(() {
        goal['status'] = 'completed';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Project "${goal['title']}" marked as completed!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _confirmCompleteGoal(Map<String, dynamic> goal) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Complete Project'),
          content: Text(
              'Are you sure you want to mark "${goal['title']}" as completed?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _completeGoal(goal);
              },
              child: const Text('Complete'),
            ),
          ],
        );
      },
    );
  }

  void _confirmJoin(Map<String, dynamic> goal) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Project?'),
        content: Text('Do you want to join "${goal['title']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _joinCommunityGoal(goal);
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  void _confirmLeave(Map<String, dynamic> goal) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Project?'),
        content: Text('Are you sure you want to leave "${goal['title']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              _leaveCommunityGoal(goal);
            },
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  void _navigateToGoalDetails(Map<String, dynamic> goal) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GoalDetailPage(
          goalId: goal['id'] ?? goal['title'],
          title: goal['title'],
          type: 'Community',
          author: goal['author'],
          progress: _calculateProgress(goal['milestones']),
          milestones: goal['milestones'],
          isJoined: goal['isJoined'] ?? false,
          participants: goal['participants'] ?? 0,
          description: goal['description'],
        ),
      ),
    );
  }

  void _navigateToPersonalGoalDetails(Map<String, dynamic> goal) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GoalDetailPage(
          goalId: goal['id'] ?? goal['title'],
          title: goal['title'],
          type: 'Personal',
          deadline: goal['deadline'],
          progress: _calculateProgress(goal['milestones']),
          milestones: goal['milestones'],
          isJoined: false,
          participants: 0,
          description: goal['description'],
        ),
      ),
    );
  }
}
