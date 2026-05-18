import 'package:flutter/material.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/features/events/presentation/pages/create_event_page.dart';
import 'package:cap/features/events/presentation/widgets/event_details_bottom_sheet.dart';
import 'package:cap/shared/utils/event_date_format.dart';
import 'package:cap/providers/event_provider.dart';
import 'package:cap/shared/models/event.dart';
import 'package:cap/shared/widgets/linkified_text.dart';
import 'package:provider/provider.dart';

class EventsPage extends StatefulWidget {
  final bool hideAppBar;

  const EventsPage({super.key, this.hideAppBar = false});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  String _selectedCategory = 'All';
  bool _showPastEvents = false;
  final List<String> _categories = [
    'All',
    'Farm Tours',
    'Markets',
    'Community',
    'Education',
    'Potluck',
    'Farm Day',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EventProvider>().loadEvents();
    });
  }

  List<Event> _getFilteredEvents() {
    final events = context.read<EventProvider>().events;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    List<Event> filtered = events.where((event) {
      final eventDay = DateTime(
        event.eventDate.year,
        event.eventDate.month,
        event.eventDate.day,
      );
      final isPast = eventDay.isBefore(today);
      final matchesCategory =
          _selectedCategory == 'All' || event.category == _selectedCategory;

      if (!_showPastEvents && isPast) {
        return false;
      }
      return matchesCategory;
    }).toList();

    return filtered;
  }

  List<Event> _getUpcomingEvents(List<Event> events) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return events.where((event) {
      final eventDay = DateTime(
        event.eventDate.year,
        event.eventDate.month,
        event.eventDate.day,
      );
      return eventDay.isAfter(today) || eventDay.isAtSameMomentAs(today);
    }).toList();
  }

  List<Event> _getPastEvents(List<Event> events) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return events.where((event) {
      final eventDay = DateTime(
        event.eventDate.year,
        event.eventDate.month,
        event.eventDate.day,
      );
      return eventDay.isBefore(today);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: widget.hideAppBar
          ? null
          : AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Events',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              actions: [
                IconButton(
                  icon: Icon(
                      _showPastEvents ? Icons.event_available : Icons.history),
                  tooltip:
                      _showPastEvents ? 'Hide Past Events' : 'Show Past Events',
                  onPressed: () {
                    setState(() {
                      _showPastEvents = !_showPastEvents;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const CreateEventPage()),
                    ).then((_) {
                      if (!context.mounted) return;
                      context.read<EventProvider>().loadEvents();
                    });
                  },
                ),
              ],
            ),
      body: Column(
        children: [
          _buildCategoryFilter(),
          Expanded(
            child: Consumer<EventProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final filteredEvents = _getFilteredEvents();

                if (filteredEvents.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No events found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try selecting a different category or create a new event',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (_showPastEvents) {
                  final upcomingEvents = _getUpcomingEvents(filteredEvents);
                  final pastEvents = _getPastEvents(filteredEvents);

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (upcomingEvents.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Upcoming Events',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryGreen,
                                ),
                          ),
                        ),
                        ...upcomingEvents.map((event) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _buildEventCard(event, provider),
                            )),
                        if (pastEvents.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              'Past Events',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[600],
                                  ),
                            ),
                          ),
                          ...pastEvents.map((event) => Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Opacity(
                                  opacity: 0.6,
                                  child: _buildEventCard(event, provider),
                                ),
                              )),
                        ],
                      ] else if (pastEvents.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Past Events',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[600],
                                ),
                          ),
                        ),
                        ...pastEvents.map((event) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Opacity(
                                opacity: 0.6,
                                child: _buildEventCard(event, provider),
                              ),
                            )),
                      ],
                    ],
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredEvents.length,
                  itemBuilder: (context, index) {
                    return _buildEventCard(filteredEvents[index], provider);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'Filter by Category',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (widget.hideAppBar)
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 40, minHeight: 40),
                  icon: Icon(
                    _showPastEvents ? Icons.event_available : Icons.history,
                    color: Colors.black87,
                  ),
                  tooltip:
                      _showPastEvents ? 'Hide past events' : 'Show past events',
                  onPressed: () {
                    setState(() {
                      _showPastEvents = !_showPastEvents;
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((category) {
                final isSelected = category == _selectedCategory;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = category;
                      });
                    },
                    selectedColor: AppTheme.primaryGreen.withValues(alpha: 0.2),
                    checkmarkColor: AppTheme.primaryGreen,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(Event event, EventProvider provider) {
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
    final isRegistered = provider.isUserRegisteredSync(event.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showEventDetails(event, provider),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      event.category,
                      style: TextStyle(
                        color: AppTheme.primaryGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (event.isCoHosted)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.infoBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Co-hosted',
                        style: TextStyle(
                          color: AppTheme.infoBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                event.title,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              LinkifiedText(
                text: event.description,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    formatEventDateIso(event.eventDate),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'at',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      event.time,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.location_on,
                      size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(event.location,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.people, size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    isUnlimited
                        ? '${event.currentAttendees} attendees (Unlimited)'
                        : '${event.currentAttendees}/${event.maxAttendees} attendees',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (isPast)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _showEventDetails(event, provider),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Details'),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _showEventDetails(event, provider),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Details'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isFull && !isRegistered
                            ? null
                            : () {
                                if (isRegistered) {
                                  _unregisterFromEvent(event, provider);
                                } else {
                                  _registerForEvent(event, provider);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isRegistered
                              ? AppTheme.errorRed
                              : AppTheme.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(isRegistered ? 'Unregister' : 'Register'),
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

  void _showEventDetails(Event event, EventProvider provider) {
    showEventDetailsFor(
      context,
      event,
      eventProvider: provider,
      onRegisterToggle: (isRegistered) {
        if (isRegistered) {
          _unregisterFromEvent(event, provider);
        } else {
          _registerForEvent(event, provider);
        }
      },
    );
  }

  Future<void> _registerForEvent(Event event, EventProvider provider) async {
    final success = await provider.registerForEvent(event.id);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registered for ${event.title}'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to register'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _unregisterFromEvent(Event event, EventProvider provider) async {
    final success = await provider.unregisterFromEvent(event.id);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unregistered from ${event.title}'),
          backgroundColor: AppTheme.warningOrange,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to unregister'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
