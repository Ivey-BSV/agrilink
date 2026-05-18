import 'package:flutter/material.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/features/polls/presentation/pages/create_poll_page.dart';
import 'package:cap/features/polls/presentation/pages/poll_detail_page.dart';
import 'package:cap/services/poll_service.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PollsListPage extends StatefulWidget {
  const PollsListPage({super.key});

  @override
  State<PollsListPage> createState() => _PollsListPageState();
}

class _PollsListPageState extends State<PollsListPage> {
  final PollService _polls = PollService();
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _polls.listPolls();
      if (!mounted) return;
      setState(() {
        _rows = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = Supabase.instance.client.auth.currentUser != null;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundLight,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Polls',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButton: signedIn
          ? FloatingActionButton.extended(
              onPressed: () async {
                final created = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreatePollPage(),
                  ),
                );
                if (created == true && mounted) await _load();
              },
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('New poll'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppTheme.primaryGreen,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(
                        'Could not load polls.\n\n'
                        'If this is new, run the Supabase migration '
                        '`20260419150000_polls.sql`.\n\n$_error',
                        style: TextStyle(color: Colors.grey[800], height: 1.4),
                      ),
                    ],
                  )
                : !signedIn
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(24),
                        children: [
                          Icon(Icons.how_to_vote_outlined,
                              size: 56, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(
                            'Sign in to see polls and vote.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      )
                    : _rows.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(24),
                            children: [
                              Icon(Icons.poll_outlined,
                                  size: 56, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              Text(
                                'No polls yet.\nTap New poll to ask the group a question.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey[700],
                                  height: 1.45,
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                            itemCount: _rows.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final row = _rows[index];
                              final id = row['id'] as String;
                              final title = row['title'] as String? ?? 'Poll';
                              final multi = row['allows_multiple'] == true;
                              final status =
                                  row['status'] as String? ?? 'active';
                              final created = row['created_at'] as String?;
                              DateTime? dt;
                              if (created != null) {
                                dt = DateTime.tryParse(created);
                              }
                              final when = dt != null
                                  ? DateFormat.yMMMd().format(dt.toLocal())
                                  : '';
                              final author = _polls.creatorLabel(row);

                              return Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () async {
                                    await Navigator.push<void>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            PollDetailPage(pollId: id),
                                      ),
                                    );
                                    if (mounted) await _load();
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                title,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                            if (status != 'active')
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[200],
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: const Text(
                                                  'Closed',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '$author · $when'
                                          '${multi ? ' · Multi-select' : ''}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
      ),
    );
  }
}
