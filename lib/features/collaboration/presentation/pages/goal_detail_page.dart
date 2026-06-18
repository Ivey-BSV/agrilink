import 'package:flutter/material.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/features/collaboration/presentation/widgets/community_circle_roles_section.dart';
import 'package:cap/features/collaboration/presentation/widgets/goal_shared_files_section.dart';
import 'package:cap/services/goal_service.dart';
import 'package:cap/shared/constants/circle_roles.dart';
import 'package:cap/shared/widgets/network_circle_avatar.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GoalDetailPage extends StatefulWidget {
  final String goalId;
  final String title;
  final String type;
  final String? author;
  final String? deadline;
  final double? progress;
  final List<Map<String, dynamic>>? milestones;
  final bool isJoined;
  final int participants;
  final String? description;

  const GoalDetailPage({
    super.key,
    required this.goalId,
    required this.title,
    required this.type,
    this.author,
    this.deadline,
    this.progress,
    this.milestones,
    this.isJoined = false,
    this.participants = 0,
    this.description,
  });

  @override
  State<GoalDetailPage> createState() => _GoalDetailPageState();
}

class _GoalDetailPageState extends State<GoalDetailPage> {
  final GoalService _goalService = GoalService();
  late List<Map<String, dynamic>> _localMilestones;
  late double _localProgress;
  late bool _localIsJoined;
  bool _showAllParticipants = false;
  bool _isLoading = false;
  bool _isCompleted = false;
  bool _isCreator = false;
  List<Map<String, dynamic>> _participants = [];
  String? _creatorUserId;
  Map<String, int> _participantContributions = {};
  List<Map<String, dynamic>> _circleRoles = [];

  @override
  void initState() {
    super.initState();
    _localMilestones = widget.milestones != null
        ? List<Map<String, dynamic>>.from(widget.milestones!)
        : [];
    _localProgress = widget.progress ?? 0.0;
    _localIsJoined = widget.isJoined;
    _loadGoalData();
  }

  void _confirmDeleteGoal() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project?'),
        content: Text(
            'Are you sure you want to permanently delete "${widget.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await _deleteGoal();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteGoal() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });
    try {
      await _goalService.deleteGoal(widget.goalId);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete project: $e')),
        );
      }
    }
  }

  Future<void> _loadGoalData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final goalData = await _goalService.getGoalById(widget.goalId);

      if (widget.type == 'Community') {
        try {
          await _goalService.ensureCommunityCircleRoles(widget.goalId);
        } catch (_) {}
        try {
          final circle =
              await _goalService.getCommunityGoalCircleRoles(widget.goalId);
          goalData['community_goal_circle_roles'] = circle;
        } catch (_) {
          goalData['community_goal_circle_roles'] = <dynamic>[];
        }

        final hasJoined =
            await _goalService.hasJoinedCommunityGoal(widget.goalId);
        _localIsJoined = hasJoined;

        final currentUser = Supabase.instance.client.auth.currentUser;
        _isCreator = currentUser?.id == goalData['user_id'];
        _creatorUserId = goalData['user_id'];
      } else {
        final currentUser = Supabase.instance.client.auth.currentUser;
        _isCreator = currentUser?.id == goalData['user_id'];
        _creatorUserId = goalData['user_id'];
      }

      final formattedGoal = _goalService.formatGoalForUI(goalData);

      if (widget.type == 'Community') {
        _participantContributions =
            await _goalService.getParticipantContributions(widget.goalId);
      }

      setState(() {
        _localMilestones =
            List<Map<String, dynamic>>.from(formattedGoal['milestones'] ?? []);
        _localProgress = formattedGoal['progress'] ?? 0.0;
        _isCompleted = formattedGoal['status'] == 'completed';
        _participants = List<Map<String, dynamic>>.from(
            goalData['community_goal_participants'] ?? []);
        if (widget.type == 'Community') {
          _circleRoles = _goalService.parseCircleRolesFromGoal(goalData);
        } else {
          _circleRoles = [];
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      _localMilestones = widget.milestones != null
          ? List<Map<String, dynamic>>.from(widget.milestones!)
          : [];
      _localProgress = widget.progress ?? 0.0;
      _localIsJoined = widget.isJoined;
    }
  }

  void _updateProgress() {
    if (_localMilestones.isEmpty) {
      _localProgress = 0.0;
    } else {
      int completed =
          _localMilestones.where((m) => m['completed'] == true).length;
      _localProgress = completed / _localMilestones.length;
    }
  }

  Future<void> _joinOrLeaveGoal() async {
    try {
      setState(() {
        _isLoading = true;
      });

      if (_localIsJoined) {
        await _goalService.leaveCommunityGoal(widget.goalId);
        if (!mounted) return;
        setState(() {
          _localIsJoined = false;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Left "${widget.title}" project!')),
        );
      } else {
        await _goalService.joinCommunityGoal(widget.goalId);
        if (!mounted) return;
        setState(() {
          _localIsJoined = true;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Joined "${widget.title}" project!')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Failed to ${_localIsJoined ? 'leave' : 'join'} project: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic>? _circleRoleRow(String slug) {
    for (final r in _circleRoles) {
      if (r['role'] == slug) return r;
    }
    return null;
  }

  Set<String> _circleOccupantIdsExceptRole(String roleSlug) {
    final taken = <String>{};
    for (final r in _circleRoles) {
      if ((r['role'] as String?) == roleSlug) continue;
      final u = r['user_id'] as String?;
      if (u != null) taken.add(u);
    }
    return taken;
  }

  Future<void> _onCircleRoleTap(String role) async {
    final row = _circleRoleRow(role);
    if (row == null) return;
    final occupant = row['user_id'] as String?;
    final uid = Supabase.instance.client.auth.currentUser?.id;

    if (_isCreator) {
      await _showCreatorAssignRoleSheet(role);
      return;
    }

    if (!_localIsJoined || uid == null) return;

    if (occupant == null) {
      await _confirmClaimRole(role);
    } else if (occupant == uid) {
      await _confirmReleaseRole(role);
    }
  }

  Future<void> _showCreatorAssignRoleSheet(String role) async {
    final row = _circleRoleRow(role);
    final currentOccupant = row?['user_id'] as String?;
    final takenElsewhere = _circleOccupantIdsExceptRole(role);

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final sheetChildren = <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'Assign ${kCommunityCircleRoleLabels[role] ?? role}',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person_off_outlined),
            title: const Text('Leave seat vacant'),
            onTap: () async {
              Navigator.pop(ctx);
              try {
                await _goalService.releaseCommunityCircleRole(
                    widget.goalId, role);
                if (mounted) await _loadGoalData();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not update role: $e')),
                  );
                }
              }
            },
          ),
          const Divider(),
        ];

        for (final p in _participants) {
          final pid = p['user_id'] as String?;
          if (pid == null) continue;
          if (takenElsewhere.contains(pid) && pid != currentOccupant) {
            continue;
          }
          final prof = p['user_profiles'];
          final name = prof is Map
              ? ((prof['full_name'] as String?)?.trim().isNotEmpty == true
                      ? prof['full_name'] as String
                      : null) ??
                  (prof['username'] as String?) ??
                  'Member'
              : 'Member';
          final avatar = prof is Map ? prof['avatar_url'] as String? : null;
          sheetChildren.add(
            ListTile(
              leading: NetworkCircleAvatar(
                radius: 20,
                imageUrl: avatar,
                fallbackLetter: '?',
              ),
              title: Text(name),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  await _goalService.setCommunityCircleRoleUser(
                    goalId: widget.goalId,
                    role: role,
                    userId: pid,
                  );
                  if (mounted) await _loadGoalData();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not assign: $e')),
                    );
                  }
                }
              },
            ),
          );
        }

        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: sheetChildren,
          ),
        );
      },
    );
  }

  Future<void> _confirmClaimRole(String role) async {
    final label = kCommunityCircleRoleLabels[role] ?? role;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Take $label?'),
        content: Text(
          'You will be listed as $label for this circle. Others can see who '
          'holds each seat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Claim seat'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _goalService.claimCommunityCircleRole(widget.goalId, role);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You are now $label.')),
        );
        await _loadGoalData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not claim seat: $e')),
        );
      }
    }
  }

  Future<void> _confirmReleaseRole(String role) async {
    final label = kCommunityCircleRoleLabels[role] ?? role;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Step down from $label?'),
        content: const Text(
          'The seat will be open for someone else to claim.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Step down'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _goalService.releaseCommunityCircleRole(widget.goalId, role);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You stepped down as $label.')),
        );
        await _loadGoalData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update: $e')),
        );
      }
    }
  }

  bool _canComplete() {
    final canComplete = !_isCompleted && _localProgress >= 1.0;
    return canComplete;
  }

  void _confirmCompleteGoal() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Complete Project'),
          content: Text(
              'Are you sure you want to mark "${widget.title}" as completed?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _completeGoal();
              },
              child: const Text('Complete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _completeGoal() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _goalService.updateGoalCompletionStatus(widget.goalId, true);

      final goalData = await _goalService.getGoalById(widget.goalId);
      if (!mounted) return;
      final formattedGoal = _goalService.formatGoalForUI(goalData);

      setState(() {
        _isCompleted = formattedGoal['status'] == 'completed';
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Project "${widget.title}" marked as completed!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _confirmUncompleteGoal() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Uncomplete Project'),
          content: Text(
              'Are you sure you want to mark "${widget.title}" as incomplete?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _uncompleteGoal();
              },
              child: const Text('Uncomplete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _uncompleteGoal() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _goalService.updateGoalCompletionStatus(widget.goalId, false);
      if (!mounted) return;
      setState(() {
        _isCompleted = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Project "${widget.title}" marked as incomplete!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleMilestoneCompletion(
      String milestoneId, bool completed) async {
    try {
      await _goalService.updateMilestoneStatus(milestoneId, completed);
      if (!mounted) return;

      setState(() {
        for (var milestone in _localMilestones) {
          if (milestone['id'] == milestoneId) {
            milestone['completed'] = completed;
            break;
          }
        }
        _updateProgress();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update milestone: $e')),
      );
    }
  }

  List<Widget> _buildParticipantsList() {
    final sortedParticipants = List<Map<String, dynamic>>.from(_participants);
    sortedParticipants.sort((a, b) {
      final aContribution = _calculateParticipantContribution(a);
      final bContribution = _calculateParticipantContribution(b);

      if (aContribution != bContribution) {
        return bContribution.compareTo(aContribution);
      }

      final aJoined = a['created_at'] as String?;
      final bJoined = b['created_at'] as String?;
      if (aJoined != null && bJoined != null) {
        return DateTime.parse(aJoined).compareTo(DateTime.parse(bJoined));
      }
      return 0;
    });

    final participantsToShow = _showAllParticipants
        ? sortedParticipants
        : sortedParticipants.take(3).toList();

    return participantsToShow.asMap().entries.map((entry) {
      int index = entry.key;
      Map<String, dynamic> participant = entry.value;

      final userProfile = participant['user_profiles'];
      final name = userProfile?['full_name'] ??
          (userProfile?['username'] as String?)?.toLowerCase() ??
          'Unknown User';

      final isCreator = participant['user_id'] == _creatorUserId;

      final isTopContributor = index == 0;

      final contribution = _calculateParticipantContribution(participant);

      final label = isCreator ? 'Creator' : 'Participant';

      final avatarUrl = userProfile?['avatar_url'];
      final userId = participant['user_id'] as String?;

      return Column(
        children: [
          _buildParticipantItem(
            name,
            label,
            '$contribution%',
            isTopContributor,
            avatarUrl: avatarUrl,
            userId: userId,
          ),
          if (index < participantsToShow.length - 1) const SizedBox(height: 12),
        ],
      );
    }).toList();
  }

  int _calculateParticipantContribution(Map<String, dynamic> participant) {
    final totalMilestones = _localMilestones.length;
    if (totalMilestones == 0) return 0;

    final userId = participant['user_id'] as String?;
    if (userId == null) return 0;

    final milestonesCompleted = _participantContributions[userId] ?? 0;

    final contributionPercentage =
        ((milestonesCompleted / totalMilestones) * 100).round();

    return contributionPercentage.clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    final bool isCommunityGoal = widget.type == 'Community';

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundLight,
        elevation: 0,
        title: Text(
          'Project Details',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              shadowColor: Colors.black.withValues(alpha: 0.15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isCommunityGoal
                                          ? AppTheme.grainGold
                                              .withValues(alpha: 0.12)
                                          : Colors.blue.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      isCommunityGoal ? 'Community' : 'Farm',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isCommunityGoal
                                            ? AppTheme.grainGold
                                            : Colors.blue,
                                      ),
                                    ),
                                  ),
                                  if (widget.deadline != null) ...[
                                    const SizedBox(width: 12),
                                    Icon(Icons.schedule,
                                        size: 14, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Text(
                                      widget.deadline!,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600]),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (isCommunityGoal && widget.author != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.person,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Created by ${widget.author}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Project Description',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 4,
              shadowColor: Colors.black.withValues(alpha: 0.15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  widget.description ??
                      (isCommunityGoal
                          ? 'This community project aims to promote sustainable farming practices across our region. By switching to cover cropping on 10% of farms by winter, we can improve soil health, reduce erosion, and create a more resilient agricultural ecosystem. This collaborative effort will benefit all participating farmers and the environment.'
                          : 'This farm project focuses on improving your farm\'s productivity and sustainability. By implementing new techniques and technologies, you can increase crop yield while reducing environmental impact. This project will help you become more efficient and profitable while contributing to sustainable agriculture.'),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            GoalSharedFilesSection(
              goalId: widget.goalId,
              canUpload: _isCreator || (isCommunityGoal && _localIsJoined),
            ),
            if (isCommunityGoal && !_isLoading) ...[
              const SizedBox(height: 24),
              if (_circleRoles.isEmpty)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Circle roles are not available yet. Ask an admin to run '
                      'the Supabase migration that creates '
                      '`community_goal_circle_roles`, then refresh.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[800],
                        height: 1.4,
                      ),
                    ),
                  ),
                )
              else
                CommunityCircleRolesSection(
                  rows: _circleRoles,
                  isCreator: _isCreator,
                  isJoined: _localIsJoined,
                  currentUserId: Supabase.instance.client.auth.currentUser?.id,
                  onRoleRowTap: _onCircleRoleTap,
                ),
            ],
            const SizedBox(height: 24),
            Text(
              'Progress Tracking',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 4,
              shadowColor: Colors.black.withValues(alpha: 0.15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Overall Progress',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          '${((_localProgress * 100).toInt())}%',
                          style: TextStyle(
                            fontSize: 14,
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
                          value: _localProgress,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.primaryGreen,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Milestones Completed',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          '${_localMilestones.where((m) => m['completed'] == true).length}/${_localMilestones.length}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Milestones',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 4,
              shadowColor: Colors.black.withValues(alpha: 0.15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: _localMilestones.isNotEmpty
                      ? _localMilestones.asMap().entries.map((entry) {
                          int index = entry.key;
                          Map<String, dynamic> milestone = entry.value;
                          return Column(
                            children: [
                              _buildMilestoneItem(
                                milestone['title'],
                                milestone['completed']
                                    ? 'Completed'
                                    : 'Pending',
                                milestone['completed'],
                                '2024-${(index + 1).toString().padLeft(2, '0')}-15',
                                milestone,
                              ),
                              if (index < _localMilestones.length - 1)
                                const SizedBox(height: 12),
                            ],
                          );
                        }).toList()
                      : [
                          _buildMilestoneItem(
                            'No milestones available',
                            'N/A',
                            false,
                            'N/A',
                            null,
                          ),
                        ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (isCommunityGoal) ...[
              Text(
                'Participants (${_participants.length})',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 4,
                shadowColor: Colors.black.withValues(alpha: 0.15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      ..._buildParticipantsList(),
                      if (!_showAllParticipants &&
                          _participants.length > 3) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _showAllParticipants = true;
                            });
                          },
                          child: Text(
                            'Show all ${_participants.length} participants',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.primaryGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      if (_showAllParticipants && _participants.length > 3) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _showAllParticipants = false;
                            });
                          },
                          child: Text(
                            'Show less',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.primaryGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            if (isCommunityGoal) ...[
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: _isLoading
                      ? null
                      : () {
                          if (_isCompleted) {
                            if (_isCreator) {
                              _confirmUncompleteGoal();
                            }
                          } else if (_canComplete() && _isCreator) {
                            _confirmCompleteGoal();
                          } else {
                            _joinOrLeaveGoal();
                          }
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _isCompleted
                          ? AppTheme.grainGold
                          : _canComplete() && _isCreator
                              ? AppTheme.primaryGreen
                              : (_localIsJoined
                                  ? AppTheme.primaryGreen.withValues(alpha: 0.1)
                                  : AppTheme.primaryGreen),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isCompleted) ...[
                          Icon(Icons.check_circle,
                              size: 20, color: Colors.white),
                          const SizedBox(width: 8),
                        ] else if (_canComplete() && _isCreator) ...[
                          Icon(Icons.check_circle_outline,
                              size: 20, color: Colors.white),
                          const SizedBox(width: 8),
                        ] else if (_localIsJoined) ...[
                          Icon(Icons.check,
                              size: 20, color: AppTheme.primaryGreen),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          _isCompleted
                              ? (_isCreator ? 'Completed' : 'Project Completed')
                              : _canComplete() && _isCreator
                                  ? 'Complete Project'
                                  : (_localIsJoined
                                      ? 'Joined'
                                      : 'Join This Project'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _isCompleted
                                ? Colors.white
                                : _canComplete() && _isCreator
                                    ? Colors.white
                                    : (_localIsJoined
                                        ? AppTheme.primaryGreen
                                        : Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_isCreator) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _confirmDeleteGoal,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Delete Project'),
                  ),
                ),
              ],
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Edit project feature coming soon!'),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryGreen,
                        side: BorderSide(
                            color: AppTheme.primaryGreen, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Edit',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: _localProgress >= 1.0
                          ? () {
                              if (_isCompleted) {
                                _confirmUncompleteGoal();
                              } else {
                                _confirmCompleteGoal();
                              }
                            }
                          : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _isCompleted
                              ? Colors.blue
                              : (_localProgress >= 1.0
                                  ? AppTheme.primaryGreen
                                  : Colors.grey[300]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isCompleted
                                  ? Icons.check_circle
                                  : Icons.check_circle_outline,
                              size: 18,
                              color: _isCompleted
                                  ? Colors.white
                                  : (_localProgress >= 1.0
                                      ? Colors.white
                                      : Colors.grey[500]),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isCompleted
                                  ? 'Completed'
                                  : (_localProgress >= 1.0
                                      ? 'Complete Project'
                                      : 'Complete'),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _isCompleted
                                    ? Colors.white
                                    : (_localProgress >= 1.0
                                        ? Colors.white
                                        : Colors.grey[500]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _confirmDeleteGoal,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Delete Project'),
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMilestoneItem(String title, String status, bool isCompleted,
      String date, Map<String, dynamic>? milestone) {
    return Row(
      children: [
        GestureDetector(
          onTap: _isCompleted
              ? null
              : () {
                  final milestoneId = milestone?['id'] as String?;
                  if (milestoneId != null) {
                    _toggleMilestoneCompletion(
                        milestoneId, !(milestone?['completed'] ?? false));
                  } else {
                    setState(() {
                      if (milestone != null) {
                        milestone['completed'] =
                            !(milestone['completed'] ?? false);
                        _updateProgress();
                      }
                    });
                  }
                },
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: _isCompleted
                  ? Colors.grey[400]
                  : (isCompleted ? AppTheme.primaryGreen : Colors.grey[300]!),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: _isCompleted
                    ? Colors.grey[400]!
                    : (isCompleted ? AppTheme.primaryGreen : Colors.grey[400]!),
                width: 2,
              ),
            ),
            child: isCompleted
                ? const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 14,
                  )
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isCompleted ? Colors.grey[600] : Colors.black,
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                ),
              ),
              Text(
                '$status • $date',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantItem(
      String name, String farm, String contribution, bool isCreator,
      {String? avatarUrl, String? userId}) {
    return Row(
      children: [
        GestureDetector(
          onTap: userId != null
              ? () {
                  context.push('/user-profile/$userId');
                }
              : null,
          child: NetworkCircleAvatar(
            radius: 20,
            backgroundColor: isCreator
                ? AppTheme.primaryGreen.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.1),
            imageUrl: avatarUrl,
            fallbackLetter: name.isNotEmpty ? name[0].toUpperCase() : '?',
            fallbackTextStyle: TextStyle(
              color: isCreator ? AppTheme.primaryGreen : Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: userId != null
                ? () {
                    context.push('/user-profile/$userId');
                  }
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                    decoration: userId != null ? TextDecoration.none : null,
                  ),
                ),
                Text(
                  farm,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            contribution,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryGreen,
            ),
          ),
        ),
        if (isCreator) ...[
          const SizedBox(width: 8),
          Icon(
            Icons.star,
            color: AppTheme.grainGold,
            size: 16,
          ),
        ],
      ],
    );
  }
}
