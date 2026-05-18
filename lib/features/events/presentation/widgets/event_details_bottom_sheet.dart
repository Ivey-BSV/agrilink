import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/features/events/presentation/widgets/share_event_bottom_sheet.dart';
import 'package:cap/providers/event_provider.dart';
import 'package:cap/shared/models/event.dart';
import 'package:cap/shared/utils/event_date_format.dart';
import 'package:cap/shared/widgets/linkified_text.dart';
import 'package:flutter/material.dart';

IconData eventCategoryIcon(String category) {
  switch (category) {
    case 'Workshops':
      return Icons.work;
    case 'Farm Tours':
      return Icons.agriculture;
    case 'Markets':
      return Icons.store;
    case 'Community':
    case 'Potluck':
      return Icons.group;
    case 'Education':
      return Icons.school;
    case 'Farm Day':
      return Icons.event;
    case 'Other':
      return Icons.more_horiz;
    default:
      return Icons.event;
  }
}

Widget _eventInfoRow(
  BuildContext context,
  IconData icon,
  String label,
  String value,
) {
  return Row(
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.primaryGreen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: AppTheme.primaryGreen,
          size: 20,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    ],
  );
}

void showEventDetailsBottomSheet(
  BuildContext context, {
  required Event event,
  required bool isRegistered,
  required bool isPast,
  required bool isFull,
  required VoidCallback onShare,
  required VoidCallback onRegisterToggle,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    isDismissible: true,
    enableDrag: true,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.58,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.backgroundLight,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 6),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            eventCategoryIcon(event.category),
                            color: AppTheme.primaryGreen,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event.title,
                                style:
                                    Theme.of(context).textTheme.headlineSmall,
                              ),
                              Text(
                                event.category,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Description',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    LinkifiedText(
                      text: event.description,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    _eventInfoRow(
                      context,
                      Icons.calendar_today,
                      'Date',
                      formatEventDateIso(event.eventDate),
                    ),
                    const SizedBox(height: 12),
                    _eventInfoRow(
                      context,
                      Icons.access_time,
                      'Time',
                      event.time,
                    ),
                    const SizedBox(height: 12),
                    _eventInfoRow(
                      context,
                      Icons.location_on,
                      'Location',
                      event.location,
                    ),
                    const SizedBox(height: 12),
                    _eventInfoRow(
                      context,
                      Icons.people,
                      'Attendees',
                      event.maxAttendees == 0
                          ? '${event.currentAttendees} (Unlimited)'
                          : '${event.currentAttendees}/${event.maxAttendees}',
                    ),
                    if (event.isCoHosted && event.coHostNames.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Co-hosts',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: event.coHostNames.map((name) {
                          return Chip(label: Text(name));
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (!isPast)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: onShare,
                              icon: const Icon(Icons.share),
                              label: const Text('Share'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: isFull && !isRegistered
                                  ? null
                                  : onRegisterToggle,
                              icon: Icon(
                                isRegistered ? Icons.cancel : Icons.check,
                              ),
                              label: Text(
                                isRegistered ? 'Unregister' : 'Register',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isRegistered
                                    ? AppTheme.errorRed
                                    : AppTheme.primaryGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

Future<void> showEventDetailsFor(
  BuildContext context,
  Event event, {
  required EventProvider eventProvider,
  required void Function(bool isRegistered) onRegisterToggle,
}) async {
  final isRegistered = await eventProvider.isUserRegistered(event.id);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final eventDay = DateTime(
    event.eventDate.year,
    event.eventDate.month,
    event.eventDate.day,
  );
  final isPast = eventDay.isBefore(today);
  final isUnlimited = event.maxAttendees == 0;
  final isFull = !isUnlimited && event.currentAttendees >= event.maxAttendees;

  if (!context.mounted) return;

  showEventDetailsBottomSheet(
    context,
    event: event,
    isRegistered: isRegistered,
    isPast: isPast,
    isFull: isFull,
    onShare: () {
      Navigator.pop(context);
      showShareEventBottomSheet(context, event);
    },
    onRegisterToggle: () {
      Navigator.pop(context);
      onRegisterToggle(isRegistered);
    },
  );
}
