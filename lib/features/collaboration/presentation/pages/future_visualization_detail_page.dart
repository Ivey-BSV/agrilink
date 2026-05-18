import 'package:flutter/material.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/services/future_visualization_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FutureVisualizationDetailPage extends StatefulWidget {
  final Map<String, dynamic>? plan;
  final String? planId;

  const FutureVisualizationDetailPage({
    super.key,
    this.plan,
    this.planId,
  }) : assert(plan != null || planId != null,
            'Either plan or planId must be provided');

  @override
  State<FutureVisualizationDetailPage> createState() =>
      _FutureVisualizationDetailPageState();
}

class _FutureVisualizationDetailPageState
    extends State<FutureVisualizationDetailPage> {
  final FutureVisualizationService _service = FutureVisualizationService();
  Map<String, dynamic>? _plan;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  bool _isOwner = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    if (widget.plan != null) {
      _plan = widget.plan;
      _checkOwnership();
      _isLoading = false;
    } else if (widget.planId != null) {
      _loadPlan();
    }
  }

  void _checkOwnership() {
    if (_plan != null) {
      final currentUser = Supabase.instance.client.auth.currentUser;
      final planUserId = _plan!['user_id'] as String?;
      _isOwner = currentUser != null && planUserId == currentUser.id;
    }
  }

  Future<void> _loadPlan() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final planData =
          await _service.getFutureVisualizationById(widget.planId!);
      setState(() {
        _plan = _service.formatVisualizationForUI(planData);
        _checkOwnership();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _confirmDeletePlan() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Plan?'),
        content: Text(
            'Are you sure you want to permanently delete "${_plan!['title']}"? This cannot be undone.'),
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
              await _deletePlan();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePlan() async {
    if (_isDeleting || _plan == null) return;
    setState(() {
      _isDeleting = true;
    });
    try {
      await _service.deleteFutureVisualization(_plan!['id'] as String);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete plan: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'Future Visualization',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_hasError || _plan == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'Future Visualization',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  'Failed to load plan',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ?? 'An unknown error occurred',
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: widget.planId != null ? _loadPlan : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final plan = _plan!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          plan['public'] == false ? 'My Personal Plans' : 'Community Plans',
          style:
              const TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              plan['title'] ?? 'Untitled Vision',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'by ${plan['owner']} • ${_formatTimeAgo(plan['createdAt'] as DateTime)}',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Intent'),
            const SizedBox(height: 8),
            _buildInfoBox(plan['intent'] ?? 'Not specified'),
            const SizedBox(height: 20),
            _buildSectionTitle('Future Vision'),
            const SizedBox(height: 8),
            _buildInfoBox(
              plan['visionDescription'] ??
                  'A clear vision of sustainable farming practices that benefit both the farm and the local community.',
            ),
            const SizedBox(height: 20),
            _buildSectionTitle('Time Horizon'),
            const SizedBox(height: 8),
            _buildInfoBox('${plan['months'] ?? 18} months'),
            const SizedBox(height: 20),
            _buildSectionTitle('Focus Areas'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: ((plan['focus'] as List?) ?? ['Soil', 'Water'])
                  .map((f) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppTheme.primaryGreen.withOpacity(0.3)),
                        ),
                        child: Text(
                          f,
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.primaryGreen,
                              fontWeight: FontWeight.w500),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),
            _buildSectionTitle('Milestones'),
            const SizedBox(height: 8),
            ...((plan['milestoneDetails'] as List?) ??
                    _getDefaultMilestones(plan['months'] as int? ?? 18))
                .map((m) => _buildMilestoneCard(m)),
            const SizedBox(height: 20),
            _buildSectionTitle('Reciprocity'),
            const SizedBox(height: 8),
            if (plan['ask'] != null && (plan['ask'] as String).isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.help_outline,
                        size: 20, color: Colors.orange),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ask',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(plan['ask'] as String,
                            style: TextStyle(color: Colors.grey[700])),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (plan['offer'] != null &&
                (plan['offer'] as String).isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.handshake,
                        size: 20, color: AppTheme.primaryGreen),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Offer',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(plan['offer'] as String,
                            style: TextStyle(color: Colors.grey[700])),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            if ((plan['ask'] == null || (plan['ask'] as String).isEmpty) &&
                (plan['offer'] == null || (plan['offer'] as String).isEmpty))
              _buildInfoBox('No reciprocity information provided.'),
            const SizedBox(height: 32),
            if (_isOwner) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isDeleting ? null : _confirmDeletePlan,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isDeleting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Delete Plan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.black,
      ),
    );
  }

  Widget _buildInfoBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Text(
        text,
        style:
            const TextStyle(fontSize: 15, height: 1.5, color: Colors.black87),
      ),
    );
  }

  Widget _buildMilestoneCard(Map<String, dynamic> milestone) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.flag, size: 18, color: AppTheme.primaryGreen),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    milestone['title'] ?? 'Milestone',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Month ${milestone['monthOffset'] ?? 0}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getDefaultMilestones(int months) {
    if (months <= 12) {
      return [
        {'title': 'Set up composting system', 'monthOffset': 2},
        {'title': 'Reduce water usage by 15%', 'monthOffset': 6},
        {'title': 'Host community seed exchange', 'monthOffset': 12},
      ];
    } else {
      return [
        {'title': 'Set up composting system', 'monthOffset': 3},
        {'title': 'Install water-efficient irrigation', 'monthOffset': 6},
        {'title': 'Reduce water usage by 20%', 'monthOffset': 12},
        {'title': 'Establish community partnerships', 'monthOffset': 18},
        {'title': 'Host annual seed exchange event', 'monthOffset': 24},
      ];
    }
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 1) return '${diff.inDays} days ago';
    if (diff.inHours >= 1) return '${diff.inHours} hours ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes} minutes ago';
    return 'Just now';
  }
}
