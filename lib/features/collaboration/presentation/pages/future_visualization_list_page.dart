import 'package:flutter/material.dart';
import 'package:cap/shared/utils/relative_time_format.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/features/collaboration/presentation/pages/future_visualization_detail_page.dart';
import 'package:cap/features/collaboration/presentation/pages/future_visualization_page.dart';
import 'package:cap/services/future_visualization_service.dart';

class FutureVisualizationListPage extends StatefulWidget {
  const FutureVisualizationListPage({super.key});

  @override
  State<FutureVisualizationListPage> createState() =>
      _FutureVisualizationListPageState();
}

class _FutureVisualizationListPageState
    extends State<FutureVisualizationListPage> {
  final FutureVisualizationService _service = FutureVisualizationService();
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  List<Map<String, dynamic>> _myPlans = [];
  List<Map<String, dynamic>> _communityPlans = [];

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    List<Map<String, dynamic>> myPlans = [];
    List<Map<String, dynamic>> communityPlans = [];
    String? firstError;

    try {
      final myPlansData = await _service.getMyPrivatePlans();
      myPlans =
          myPlansData.map((p) => _service.formatVisualizationForUI(p)).toList();
    } catch (e) {
      firstError ??= 'Failed to fetch private plans: ${e.toString()}';
      myPlans = const [];
    }

    try {
      final communityPlansData = await _service.getCommunityPlans();
      communityPlans = communityPlansData
          .map((p) => _service.formatVisualizationForUI(p))
          .toList();
    } catch (e) {
      firstError ??= 'Failed to fetch community plans: ${e.toString()}';
      communityPlans = const [];
    }

    setState(() {
      _myPlans = myPlans;
      _communityPlans = communityPlans;
      _isLoading = false;
      if (firstError != null) {
        _hasError = true;
        _errorMessage = firstError;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Future Visualization',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _isLoading ? null : _loadPlans,
          ),
          IconButton(
            tooltip: 'Create Future Vision',
            icon: const Icon(Icons.add, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const FutureVisualizationPage()),
              ).then((shouldRefresh) {
                if (shouldRefresh == true) {
                  _loadPlans();
                }
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPlans,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_hasError) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange[700]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage != null
                                  ? _errorMessage!
                                  : 'Unable to load from server. Showing empty state.',
                              style: TextStyle(color: Colors.orange[900]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_myPlans.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12, top: 8),
                      child: Text(
                        'My Personal Plans',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                      ),
                    ),
                    ..._myPlans.map((p) => _buildPlanCard(p)),
                    const SizedBox(height: 24),
                  ],
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: 12,
                      top: _myPlans.isNotEmpty ? 0 : 8,
                    ),
                    child: Text(
                      'Community Plans',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                    ),
                  ),
                  if (_communityPlans.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'No community plans yet. Be the first to create one!',
                          style: TextStyle(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    ..._communityPlans.map((p) => _buildPlanCard(p)),
                ],
              ),
            ),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final focusList = plan['focus'] as List;
    final milestonesCount = (plan['milestones'] as List?)?.length ?? 0;
    final isPrivate = plan['public'] == false;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openPlan(plan),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                plan['title'],
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.flag_outlined,
                    size: 14,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    plan['intent'],
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 12,
                          color: AppTheme.primaryGreen,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${plan['months']} months',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.primaryGreen,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (milestonesCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 12,
                            color: Colors.blue[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$milestonesCount milestone${milestonesCount > 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ...focusList.take(2).map((focus) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isPrivate
                              ? Colors.blue.withValues(alpha: 0.15)
                              : AppTheme.grainGold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          focus,
                          style: TextStyle(
                            fontSize: 10,
                            color: isPrivate ? Colors.blue : AppTheme.grainGold,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (!isPrivate) ...[
                    Icon(
                      Icons.person_outline,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      plan['owner'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    formatFriendlyRelativeTime(plan['createdAt'] as DateTime),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openPlan(Map<String, dynamic> plan) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FutureVisualizationDetailPage(plan: plan),
      ),
    );
  }
}
