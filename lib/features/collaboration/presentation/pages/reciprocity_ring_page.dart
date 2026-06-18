import 'package:flutter/material.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/features/collaboration/presentation/pages/all_asks_page.dart';
import 'package:cap/features/collaboration/presentation/pages/all_offers_page.dart';
import 'package:cap/features/collaboration/presentation/pages/ask_detail_page.dart';
import 'package:cap/features/collaboration/presentation/pages/create_ask_page.dart';
import 'package:cap/features/collaboration/presentation/pages/create_offer_page.dart';
import 'package:cap/features/collaboration/presentation/pages/offer_detail_page.dart';
import 'package:cap/providers/reciprocity_ring_provider.dart';
import 'package:provider/provider.dart';

class ReciprocityRingPage extends StatefulWidget {
  const ReciprocityRingPage({super.key});

  @override
  State<ReciprocityRingPage> createState() => _ReciprocityRingPageState();
}

class _ReciprocityRingPageState extends State<ReciprocityRingPage> {
  final bool _sortAscending = true;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final provider = context.read<ReciprocityRingProvider>();
    await Future.wait([
      provider.loadAsks(),
      provider.loadOffers(),
    ]);
  }

  int _getResponseCount(Map<String, dynamic> ask) {
    final responses = ask['responses'] as List<dynamic>?;
    return responses?.length ?? 0;
  }

  int _getInterestCount(Map<String, dynamic> offer) {
    return context.read<ReciprocityRingProvider>().getInterestCount(offer);
  }

  List<Map<String, dynamic>> get _allAsks {
    final provider = context.watch<ReciprocityRingProvider>();
    return provider.asks;
  }

  List<Map<String, dynamic>> get _allOffers {
    final provider = context.watch<ReciprocityRingProvider>();
    return provider.offers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.backgroundLight,
        title: const Text(
          'Reciprocity Ring',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _showCircleOverview,
            icon: const Icon(Icons.info_outline, color: Colors.black87),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCircleSummary(),
              const SizedBox(height: 20),
              _buildQuickActions(),
              const SizedBox(height: 24),
              _buildMetricsRow(),
              const SizedBox(height: 32),
              _buildSectionHeaderWithViewAll(
                'Open Asks',
                '${_allAsks.length} total • ${_allAsks.where((a) => _getResponseCount(a) == 0).length} need responses',
                onViewAll: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AllAsksPage(allAsks: []),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              ..._getSortedAsks().take(3).map(_buildAskCard),
              if (_allAsks.length > 3) ...[
                const SizedBox(height: 12),
                _buildViewAllButton(
                  'View all ${_allAsks.length} asks',
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AllAsksPage(allAsks: []),
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 28),
              _buildSectionHeaderWithViewAll(
                'Recent Offers',
                '${_allOffers.length} available',
                onViewAll: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AllOffersPage(allOffers: []),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              ..._getSortedOffers().take(3).map(_buildOfferCard),
              if (_allOffers.length > 3) ...[
                const SizedBox(height: 12),
                _buildViewAllButton(
                  'View all ${_allOffers.length} offers',
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AllOffersPage(allOffers: []),
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 28),
              _buildGuidelines(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCircleSummary() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.handshake, color: AppTheme.primaryGreen),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Fall 2025 Cohort Ring',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Active',
                    style: TextStyle(
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSummaryItemFullWidth('Focus', 'Equipment & knowledge swap'),
            const SizedBox(height: 16),
            Container(
              height: 1,
              color: Colors.black.withValues(alpha: 0.08),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildSummaryItem('Participants', '28 farms'),
                _buildDivider(),
                _buildSummaryItem('Cycle ends', 'Dec 31'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItemFullWidth(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: Colors.black.withValues(alpha: 0.08),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateAskPage(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.campaign_outlined),
            label: const Text(
              'Make an ask',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateOfferPage(),
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              side: BorderSide(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.4)),
              foregroundColor: AppTheme.primaryGreen,
            ),
            icon: const Icon(Icons.volunteer_activism_outlined),
            label: const Text(
              'Offer support',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsRow() {
    final totalAsks = _allAsks.length;
    final totalResponses = _allAsks.fold<int>(
      0,
      (sum, ask) => sum + _getResponseCount(ask),
    );
    final avgResponses =
        totalAsks > 0 ? (totalResponses / totalAsks).toStringAsFixed(1) : '0.0';

    final provider = context.watch<ReciprocityRingProvider>();
    final medianHours = provider.getMedianTurnaroundTime();
    String turnaroundValue;
    if (medianHours == 0.0) {
      turnaroundValue = '—';
    } else if (medianHours < 1.0) {
      turnaroundValue = '${(medianHours * 60).round()}m';
    } else if (medianHours < 24.0) {
      turnaroundValue = '${medianHours.round()}h';
    } else {
      final days = (medianHours / 24.0).toStringAsFixed(1);
      turnaroundValue = '${days}d';
    }

    return Row(
      children: [
        Expanded(
          child: _buildMetricBox(
            label: 'Open asks',
            value: '$totalAsks',
            trend: 'Total active',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricBox(
            label: 'Responses avg.',
            value: avgResponses,
            trend: 'Per ask',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricBox(
            label: 'Turnaround',
            value: turnaroundValue,
            trend: 'Median time',
          ),
        ),
      ],
    );
  }

  Widget _buildMetricBox({
    required String label,
    required String value,
    required String trend,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: Colors.black.withValues(alpha: 0.05), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            trend,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getSortedAsks() {
    final sorted = List<Map<String, dynamic>>.from(_allAsks);

    int getPriority(String timeStr) {
      final lower = timeStr.toLowerCase();

      if (lower.contains('this week')) return 0;

      if (lower.contains('flexible')) return 999;

      final dateMatch = RegExp(r'(?:by|before|until)\s+([A-Za-z]+)\s+(\d+)',
              caseSensitive: false)
          .firstMatch(timeStr);
      if (dateMatch != null) {
        final monthStr = dateMatch.group(1)!.toLowerCase();
        final day = int.tryParse(dateMatch.group(2)!) ?? 0;

        final monthMap = {
          'jan': 1,
          'january': 1,
          'feb': 2,
          'february': 2,
          'mar': 3,
          'march': 3,
          'apr': 4,
          'april': 4,
          'may': 5,
          'jun': 6,
          'june': 6,
          'jul': 7,
          'july': 7,
          'aug': 8,
          'august': 8,
          'sep': 9,
          'september': 9,
          'oct': 10,
          'october': 10,
          'nov': 11,
          'november': 11,
          'dec': 12,
          'december': 12,
        };

        final month = monthMap[monthStr] ?? 12;
        final now = DateTime.now();
        final targetDate = DateTime(now.year, month, day);

        final finalDate = targetDate.isBefore(now)
            ? DateTime(now.year + 1, month, day)
            : targetDate;

        return finalDate.difference(now).inDays;
      }

      return 100;
    }

    sorted.sort((a, b) {
      final priorityA = getPriority(a['time'] as String);
      final priorityB = getPriority(b['time'] as String);

      if (_sortAscending) {
        return priorityA.compareTo(priorityB);
      } else {
        return priorityB.compareTo(priorityA);
      }
    });

    return sorted;
  }

  List<Map<String, dynamic>> _getSortedOffers() {
    final sorted = List<Map<String, dynamic>>.from(_allOffers);

    int getPriority(String windowStr) {
      final lower = windowStr.toLowerCase();

      if (lower.contains('this week')) return 0;

      if (lower.contains('flexible')) return 999;

      final dateMatch = RegExp(r'(?:until|by|before)\s+([A-Za-z]+)\s+(\d+)',
              caseSensitive: false)
          .firstMatch(windowStr);
      if (dateMatch != null) {
        final monthStr = dateMatch.group(1)!.toLowerCase();
        final day = int.tryParse(dateMatch.group(2)!) ?? 0;

        final monthMap = {
          'jan': 1,
          'january': 1,
          'feb': 2,
          'february': 2,
          'mar': 3,
          'march': 3,
          'apr': 4,
          'april': 4,
          'may': 5,
          'jun': 6,
          'june': 6,
          'jul': 7,
          'july': 7,
          'aug': 8,
          'august': 8,
          'sep': 9,
          'september': 9,
          'oct': 10,
          'october': 10,
          'nov': 11,
          'november': 11,
          'dec': 12,
          'december': 12,
        };

        final month = monthMap[monthStr] ?? 12;
        final now = DateTime.now();
        final targetDate = DateTime(now.year, month, day);

        final finalDate = targetDate.isBefore(now)
            ? DateTime(now.year + 1, month, day)
            : targetDate;

        return finalDate.difference(now).inDays;
      }

      return 100;
    }

    sorted.sort((a, b) {
      final priorityA = getPriority(a['window'] as String);
      final priorityB = getPriority(b['window'] as String);

      if (_sortAscending) {
        return priorityA.compareTo(priorityB);
      } else {
        return priorityB.compareTo(priorityA);
      }
    });

    return sorted;
  }

  Widget _buildSectionHeaderWithViewAll(
    String title,
    String subtitle, {
    required VoidCallback onViewAll,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onViewAll,
          child: const Text('View All'),
        ),
      ],
    );
  }

  Widget _buildViewAllButton(String text, VoidCallback onTap) {
    return Center(
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: AppTheme.primaryGreen.withValues(alpha: 0.3)),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: AppTheme.primaryGreen,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildAskCard(Map<String, dynamic> ask) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AskDetailPage(ask: ask),
            ),
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        AppTheme.primaryGreen.withValues(alpha: 0.15),
                    child: Text(
                      ask['avatar'] as String,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryGreen,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ask['owner'] as String,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          ask['location'] as String? ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        ask['time'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.red[700],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                ask['need'] as String,
                style: const TextStyle(height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.chat_bubble_outline,
                      size: 18, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    '${_getResponseCount(ask)} ${_getResponseCount(ask) == 1 ? 'response' : 'responses'}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AskDetailPage(ask: ask),
                        ),
                      );
                    },
                    child: Text(
                      'Respond',
                      style: TextStyle(
                        color: AppTheme.primaryGreen,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
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

  Widget _buildOfferCard(Map<String, dynamic> offer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OfferDetailPage(offer: offer),
            ),
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        AppTheme.primaryGreen.withValues(alpha: 0.15),
                    child: Text(
                      offer['avatar'] as String,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryGreen,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          offer['owner'] as String,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          offer['location'] as String? ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        offer['window'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.red[700],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                offer['offer'] as String,
                style: const TextStyle(height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.favorite_outline,
                      size: 18, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    '${_getInterestCount(offer)} ${_getInterestCount(offer) == 1 ? 'person interested' : 'people interested'}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'View details',
                    style: TextStyle(
                      color: AppTheme.primaryGreen,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
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

  Widget _buildGuidelines() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Participation guide',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _showCircleOverview,
                icon: const Icon(Icons.open_in_new, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '• Frame asks with context, timing, and constraints so your peers can actually respond.\n'
            '• Close the loop by marking resolved asks—this keeps the ring flowing.\n'
            '• Offers can be skills, intros, labor, or assets. Think creatively about what you can unlock.',
            style: TextStyle(height: 1.6),
          ),
        ],
      ),
    );
  }

  void _showCircleOverview() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'How the ring works',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Each cycle pairs asks with offers so every farm leaves with something useful. '
              'Keep updates flowing – the facilitation team will nudge when items stall.',
              style: TextStyle(height: 1.6),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
