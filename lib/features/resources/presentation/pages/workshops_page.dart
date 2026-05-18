import 'package:flutter/material.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/features/collaboration/presentation/pages/workshop_detail_page.dart';

class WorkshopsPage extends StatelessWidget {
  const WorkshopsPage({super.key});

  Map<String, String?> _parseWorkshopTitle(String title) {
    final tentativeMatch = RegExp(
      r'^Tentative\s+(Social\s+Event\s+#?\d+)\s*-?\s*(.*)$',
      caseSensitive: false,
    ).firstMatch(title);
    if (tentativeMatch != null) {
      final tag = tentativeMatch.group(1)?.trim();
      final cleanTitle = tentativeMatch.group(2)?.trim() ?? '';
      return {'tag': tag, 'title': cleanTitle.isEmpty ? title : cleanTitle};
    }

    final workshopAndSocialMatch = RegExp(
      r'^(Workshop\s+\d+)\s*&\s*Social\s+Event\s+\d+\s*-?\s*(.*)$',
      caseSensitive: false,
    ).firstMatch(title);
    if (workshopAndSocialMatch != null) {
      final tag = workshopAndSocialMatch.group(1)?.trim();
      final cleanTitle = workshopAndSocialMatch.group(2)?.trim() ?? '';
      return {'tag': tag, 'title': cleanTitle.isEmpty ? title : cleanTitle};
    }

    final workshopMatch = RegExp(
      r'^(Workshop\s+\d+)\s*-?\s*(.*)$',
      caseSensitive: false,
    ).firstMatch(title);
    if (workshopMatch != null) {
      final tag = workshopMatch.group(1)?.trim();
      final cleanTitle = workshopMatch.group(2)?.trim() ?? '';
      return {'tag': tag, 'title': cleanTitle.isEmpty ? title : cleanTitle};
    }

    final socialEventMatch = RegExp(
      r'^(Social\s+Event\s+#?\d+)\s*-?\s*(.*)$',
      caseSensitive: false,
    ).firstMatch(title);
    if (socialEventMatch != null) {
      final tag = socialEventMatch.group(1)?.trim();
      final cleanTitle = socialEventMatch.group(2)?.trim() ?? '';
      return {'tag': tag, 'title': cleanTitle.isEmpty ? title : cleanTitle};
    }

    final workshopsMatch = RegExp(
      r'^(Workshops\s+\d+\s*&\s*\d+)\s*-?\s*(.*)$',
      caseSensitive: false,
    ).firstMatch(title);
    if (workshopsMatch != null) {
      final tag = workshopsMatch.group(1)?.trim();
      final cleanTitle = workshopsMatch.group(2)?.trim() ?? '';
      return {'tag': tag, 'title': cleanTitle.isEmpty ? title : cleanTitle};
    }

    return {'tag': null, 'title': title};
  }

  bool _isDateUpcoming(String dateString) {
    try {
      String cleaned = dateString.replaceAll(
        RegExp(
          r'^(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday),\s*',
          caseSensitive: false,
        ),
        '',
      );

      final yearPattern = RegExp(r'(\d{4})');
      final monthPattern = RegExp(
        r'(January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)',
        caseSensitive: false,
      );
      final dayPattern = RegExp(r'(\d+)(?:st|nd|rd|th)?');

      final yearMatch = yearPattern.firstMatch(cleaned);
      final monthMatch = monthPattern.firstMatch(cleaned);
      final dayMatch = dayPattern.firstMatch(cleaned);

      if (monthMatch == null || dayMatch == null) {
        return true;
      }

      final monthMap = {
        'january': 1,
        'jan': 1,
        'february': 2,
        'feb': 2,
        'march': 3,
        'mar': 3,
        'april': 4,
        'apr': 4,
        'may': 5,
        'june': 6,
        'jun': 6,
        'july': 7,
        'jul': 7,
        'august': 8,
        'aug': 8,
        'september': 9,
        'sep': 9,
        'october': 10,
        'oct': 10,
        'november': 11,
        'nov': 11,
        'december': 12,
        'dec': 12,
      };

      final month = monthMap[monthMatch.group(1)!.toLowerCase()];
      if (month == null) return true;

      final day = int.parse(dayMatch.group(1)!);
      final year = yearMatch != null
          ? int.parse(yearMatch.group(1)!)
          : DateTime.now().year;

      final eventDate = DateTime(year, month, day);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final eventDay = DateTime(eventDate.year, eventDate.month, eventDate.day);
      return eventDay.isAfter(today) || eventDay.isAtSameMomentAs(today);
    } catch (_) {
      return true;
    }
  }

  List<Map<String, dynamic>> _workshops() {
    return [
      {
        'id': '1',
        'title': 'Social Event 1',
        'date': 'Friday, October 24th, 2025',
        'location': 'UTRCA',
        'description':
            'We will meet one another and socialize, discussing dreams and challenges.',
      },
      {
        'id': '2',
        'title': 'Workshop 1 - Connectivity and Reciprocity',
        'date': 'Friday, November 7th, 2025',
        'location': 'UTRCA',
        'description':
            'We will explore each others\' needs and seek opportunities to offer support, forming a network of reciprocal collaborations.',
      },
      {
        'id': '3',
        'title': 'Workshop 2 - Learning Through Stories',
        'date': 'Monday, December 1st, 2025',
        'location': 'UTRCA',
        'description':
            'We will consolidate the emergent collaborative network and learn indigenous stories of agroecology and community in our region.',
      },
      {
        'id': '4',
        'title': 'Workshop 3 - Systems Problems to Tackle Together',
        'date': 'Friday, January 9th, 2026',
        'location': 'Keyser Creek',
        'description':
            'We will discuss problems that affect all farmers in the cohort, directly or indirectly, and explore their systematic root causes.',
      },
      {
        'id': '5',
        'title': 'Tentative Social Event #2 - Farm Bus Tour',
        'date': 'Friday, January 23rd, 2026',
        'location': 'Approx 4 farms',
        'description': 'Farm Bus Tour',
      },
      {
        'id': '6',
        'title': 'Workshop 4 - Toward Systems Solutions to Build Together',
        'date': 'Monday, January 26th, 2026',
        'location': 'Arrowwood',
        'description':
            'We will reconnect farm-level needs and offer to help with the set of problems and root causes affecting our farms and the broader food system. Then, we will brainstorm potential solutions and collective actions.',
      },
      {
        'id': '7',
        'title': 'Workshop 5 & Social Event 2 - Connectivity with Value Chain',
        'date': 'Thursday, February 5th, 2026',
        'location': 'Ivey',
        'description':
            'We will connect with processors, retailers and financial services firms that have a regenerative orientation, and learn how they can help and what farmers could offer in return. We will hear from regenerative farm leaders in EU and elsewhere.',
      },
      {
        'id': '8',
        'title': 'Workshop 6 - Strengthening Solutions',
        'date': 'Friday, February 27th, 2026',
        'location': 'UTRCA',
        'description':
            'We will review what we\'ve discovered and work collectively toward creating a short-list of most valuable collective actions. Such actions will build upon solutions developed in other geographies or industries.',
      },
      {
        'id': '9',
        'title': 'Workshop 7 - Planning and Enabling Collective Action',
        'date': 'Friday, March 13th, 2026',
        'location': 'UTRCA',
        'description':
            'We will roadmap future collaborative work, building upon financial and organizational support offered by the CAP research team.',
      },
      {
        'id': '10',
        'title': 'Workshops 8 & 9 - Act, Pivot and Make Progress',
        'date': 'TBD - Spring/Summer 2026',
        'location': 'TBD',
        'description': 'Details to be determined.',
      },
    ].map((w) {
      return {
        ...w,
        'isUpcoming': w['id'] == '10' ? true : _isDateUpcoming(w['date']!),
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final workshops = _workshops();
    final upcoming = workshops.where((w) => w['isUpcoming'] == true).toList();
    final past = workshops.where((w) => w['isUpcoming'] == false).toList();

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.backgroundLight,
        title: const Text(
          'Workshops',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (upcoming.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12, top: 8),
              child: Text(
                'Upcoming',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
              ),
            ),
            ..._buildSeparatedWorkshopCards(context, upcoming),
          ],
          if (past.isNotEmpty) ...[
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Past Workshops',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
              ),
            ),
            ..._buildSeparatedWorkshopCards(context, past),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildSeparatedWorkshopCards(
    BuildContext context,
    List<Map<String, dynamic>> workshops,
  ) {
    if (workshops.isEmpty) return const [];
    final widgets = <Widget>[];
    for (var i = 0; i < workshops.length; i++) {
      widgets.add(_buildCard(context, workshops[i]));
      if (i < workshops.length - 1) {
        widgets.add(const SizedBox(height: 10));
      }
    }
    return widgets;
  }

  Widget _buildCard(BuildContext context, Map<String, dynamic> workshop) {
    final parsed = _parseWorkshopTitle(workshop['title'] as String);
    final displayTitle = parsed['title']!.isEmpty
        ? (workshop['description'] as String? ?? workshop['title'] as String)
        : parsed['title']!;
    final isUpcoming = workshop['isUpcoming'] as bool;
    final statusText = isUpcoming ? 'Upcoming' : 'Completed';
    final statusColor = isUpcoming ? AppTheme.primaryGreen : Colors.grey[700]!;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WorkshopDetailPage(
                workshopId: workshop['id'] as String,
                title: workshop['title'] as String,
                date: workshop['date'] as String,
                location: workshop['location'] as String,
                description: workshop['description'] as String,
                isUpcoming: workshop['isUpcoming'] as bool,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.groups,
                  color: AppTheme.primaryGreen,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${workshop['date']} · ${workshop['location']}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (parsed['tag'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        parsed['tag']!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
