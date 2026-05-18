import 'package:flutter/material.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/features/collaboration/presentation/pages/offer_detail_page.dart';
import 'package:cap/providers/reciprocity_ring_provider.dart';
import 'package:provider/provider.dart';

class AllOffersPage extends StatefulWidget {
  final List<Map<String, dynamic>> allOffers;

  const AllOffersPage({super.key, required this.allOffers});

  @override
  State<AllOffersPage> createState() => _AllOffersPageState();
}

class _AllOffersPageState extends State<AllOffersPage> {
  String _filterCategory = 'All';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final provider = context.read<ReciprocityRingProvider>();
    await provider.loadOffers();
  }

  int _getInterestCount(Map<String, dynamic> offer) {
    return context.read<ReciprocityRingProvider>().getInterestCount(offer);
  }

  List<Map<String, dynamic>> get _allOffers {
    final provider = context.watch<ReciprocityRingProvider>();
    return [...widget.allOffers, ...provider.offers];
  }

  @override
  Widget build(BuildContext context) {
    final filteredOffers = _getFilteredOffers();

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.backgroundLight,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'All Offers',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Stack(
              children: [
                const Icon(Icons.filter_list, color: Colors.black),
                if (_filterCategory != 'All')
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryGreen,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 8,
                        minHeight: 8,
                      ),
                    ),
                  ),
              ],
            ),
            onSelected: (value) {
              setState(() {
                _filterCategory = value;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'All',
                child: Row(
                  children: [
                    if (_filterCategory == 'All')
                      const Icon(Icons.check,
                          color: AppTheme.primaryGreen, size: 20)
                    else
                      const SizedBox(width: 20),
                    const SizedBox(width: 8),
                    const Text('All Categories'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'Equipment',
                child: Row(
                  children: [
                    if (_filterCategory == 'Equipment')
                      const Icon(Icons.check,
                          color: AppTheme.primaryGreen, size: 20)
                    else
                      const SizedBox(width: 20),
                    const SizedBox(width: 8),
                    const Text('Equipment'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'Logistics',
                child: Row(
                  children: [
                    if (_filterCategory == 'Logistics')
                      const Icon(Icons.check,
                          color: AppTheme.primaryGreen, size: 20)
                    else
                      const SizedBox(width: 20),
                    const SizedBox(width: 8),
                    const Text('Logistics'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'Documents',
                child: Row(
                  children: [
                    if (_filterCategory == 'Documents')
                      const Icon(Icons.check,
                          color: AppTheme.primaryGreen, size: 20)
                    else
                      const SizedBox(width: 20),
                    const SizedBox(width: 8),
                    const Text('Documents'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'Advisory',
                child: Row(
                  children: [
                    if (_filterCategory == 'Advisory')
                      const Icon(Icons.check,
                          color: AppTheme.primaryGreen, size: 20)
                    else
                      const SizedBox(width: 20),
                    const SizedBox(width: 8),
                    const Text('Advisory'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'Time Sensitive',
                child: Row(
                  children: [
                    if (_filterCategory == 'Time Sensitive')
                      const Icon(Icons.check,
                          color: AppTheme.primaryGreen, size: 20)
                    else
                      const SizedBox(width: 20),
                    const SizedBox(width: 8),
                    const Text('Time Sensitive'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'Knowledge',
                child: Row(
                  children: [
                    if (_filterCategory == 'Knowledge')
                      const Icon(Icons.check,
                          color: AppTheme.primaryGreen, size: 20)
                    else
                      const SizedBox(width: 20),
                    const SizedBox(width: 8),
                    const Text('Knowledge'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'Services',
                child: Row(
                  children: [
                    if (_filterCategory == 'Services')
                      const Icon(Icons.check,
                          color: AppTheme.primaryGreen, size: 20)
                    else
                      const SizedBox(width: 20),
                    const SizedBox(width: 8),
                    const Text('Services'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'Warm Intro',
                child: Row(
                  children: [
                    if (_filterCategory == 'Warm Intro')
                      const Icon(Icons.check,
                          color: AppTheme.primaryGreen, size: 20)
                    else
                      const SizedBox(width: 20),
                    const SizedBox(width: 8),
                    const Text('Warm Intro'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'Certification',
                child: Row(
                  children: [
                    if (_filterCategory == 'Certification')
                      const Icon(Icons.check,
                          color: AppTheme.primaryGreen, size: 20)
                    else
                      const SizedBox(width: 20),
                    const SizedBox(width: 8),
                    const Text('Certification'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: Column(
          children: [
            if (_filterCategory != 'All')
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppTheme.backgroundLight,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.primaryGreen.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.filter_alt,
                            size: 16,
                            color: AppTheme.primaryGreen,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Filtered: $_filterCategory',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _filterCategory = 'All';
                              });
                            },
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: filteredOffers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined,
                              size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No offers found',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try adjusting your filters',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredOffers.length,
                      itemBuilder: (context, index) {
                        return _buildOfferCard(filteredOffers[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredOffers() {
    var filtered = List<Map<String, dynamic>>.from(_allOffers);

    if (_filterCategory != 'All') {
      filtered = filtered.where((offer) {
        final tags = offer['tags'] as List<dynamic>? ?? [];
        return tags.contains(_filterCategory);
      }).toList();
    }

    return _getSortedOffers(filtered);
  }

  List<Map<String, dynamic>> _getSortedOffers(
      List<Map<String, dynamic>> offers) {
    final sorted = List<Map<String, dynamic>>.from(offers);

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

      return priorityA.compareTo(priorityB);
    });

    return sorted;
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
                    backgroundColor: AppTheme.primaryGreen.withOpacity(0.15),
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
                        ),
                        const SizedBox(height: 2),
                        Text(
                          offer['location'] as String? ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      offer['window'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.red[700],
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
}
