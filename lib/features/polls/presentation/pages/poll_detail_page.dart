import 'package:flutter/material.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/services/poll_service.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PollDetailPage extends StatefulWidget {
  const PollDetailPage({super.key, required this.pollId});

  final String pollId;

  @override
  State<PollDetailPage> createState() => _PollDetailPageState();
}

class _PollDetailPageState extends State<PollDetailPage> {
  final PollService _polls = PollService();
  Map<String, dynamic>? _detail;
  Map<String, int> _voteCounts = {};
  bool _loading = true;
  String? _error;
  Set<String> _selected = {};
  bool _saving = false;

  String? get _uid => Supabase.instance.client.auth.currentUser?.id;

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
      final d = await _polls.getPollDetail(widget.pollId);
      final counts = await _polls.voteCountsByPollId(widget.pollId);
      final uid = _uid;
      final selected = uid != null
          ? await _polls.mySelectedOptionIdsForPoll(widget.pollId, uid)
          : <String>{};
      if (!mounted) return;
      setState(() {
        _detail = d;
        _voteCounts = counts;
        _selected = selected;
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

  bool get _isCreator {
    final d = _detail;
    final uid = _uid;
    if (d == null || uid == null) return false;
    return d['created_by'] == uid;
  }

  bool get _canVote {
    final d = _detail;
    if (d == null || _uid == null) return false;
    if (d['status'] != 'active') return false;
    final closesAt = d['closes_at'] as String?;
    if (closesAt != null) {
      final end = DateTime.tryParse(closesAt);
      if (end != null && DateTime.now().toUtc().isAfter(end.toUtc())) {
        return false;
      }
    }
    return true;
  }

  Future<void> _saveVote() async {
    if (!_canVote || _saving) return;
    setState(() => _saving = true);
    try {
      await _polls.submitVote(
        pollId: widget.pollId,
        optionIds: _selected.toList(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vote saved.')),
        );
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _closePoll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Close poll?'),
        content: const Text('No new votes will be accepted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _polls.closePoll(widget.pollId);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  Future<void> _deletePoll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete poll?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _polls.deletePoll(widget.pollId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'Poll',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_isCreator && _detail != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.black),
              onSelected: (v) {
                if (v == 'close') _closePoll();
                if (v == 'delete') _deletePoll();
              },
              itemBuilder: (context) => [
                if ((_detail!['status'] as String?) == 'active')
                  const PopupMenuItem(
                    value: 'close',
                    child: Text('Close poll'),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child:
                      Text('Delete poll', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppTheme.primaryGreen,
                  child: _buildBody(),
                ),
    );
  }

  Widget _buildBody() {
    final d = _detail!;
    final title = d['title'] as String? ?? '';
    final body = d['description'] as String?;
    final multi = d['allows_multiple'] == true;
    final status = d['status'] as String? ?? 'active';
    final created = d['created_at'] as String?;
    DateTime? dt;
    if (created != null) dt = DateTime.tryParse(created);
    final when =
        dt != null ? DateFormat.yMMMd().add_jm().format(dt.toLocal()) : '';
    final author = _polls.creatorLabel(d);
    final options = List<Map<String, dynamic>>.from(d['poll_options'] ?? []);
    final counts = _voteCounts;
    final total = _polls.totalVotes(counts);
    final uid = _uid;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$author · $when'
          '${multi ? ' · Multiple answers allowed' : ' · Pick one'}',
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
        if (status != 'active') ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Closed — results below',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
        ],
        if (body != null && body.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            body.trim(),
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[800],
              height: 1.45,
            ),
          ),
        ],
        const SizedBox(height: 20),
        Text(
          'Choices',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        if (multi)
          ...options.map((opt) {
            final id = opt['id'] as String;
            final label = opt['label'] as String? ?? '';
            final c = counts[id] ?? 0;
            final pct = total > 0 ? (100 * c / total).round() : 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: CheckboxListTile(
                value: _selected.contains(id),
                onChanged: _canVote
                    ? (v) {
                        setState(() {
                          if (v == true) {
                            _selected.add(id);
                          } else {
                            _selected.remove(id);
                          }
                        });
                      }
                    : null,
                title: Text(label),
                subtitle: Text('$c votes · $pct%'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                tileColor: Colors.white,
                fillColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return AppTheme.primaryGreen;
                  }
                  return null;
                }),
              ),
            );
          })
        else
          RadioGroup<String>(
            groupValue: _selected.length == 1 ? _selected.first : null,
            onChanged: (v) {
              if (!_canVote || v == null) return;
              setState(() => _selected = {v});
            },
            child: Column(
              children: options.map((opt) {
                final id = opt['id'] as String;
                final label = opt['label'] as String? ?? '';
                final c = counts[id] ?? 0;
                final pct = total > 0 ? (100 * c / total).round() : 0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: RadioListTile<String>(
                    value: id,
                    title: Text(label),
                    subtitle: Text('$c votes · $pct%'),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    tileColor: Colors.white,
                    fillColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return AppTheme.primaryGreen;
                      }
                      return null;
                    }),
                  ),
                );
              }).toList(),
            ),
          ),
        if (uid == null) ...[
          const SizedBox(height: 16),
          Text(
            'Sign in to vote.',
            style: TextStyle(color: Colors.grey[700]),
          ),
        ] else if (_canVote) ...[
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _saveVote,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save my vote'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            multi
                ? 'Select all that apply, then tap Save.'
                : 'Pick one choice, then tap Save. You can change your vote anytime while the poll is open.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
        const SizedBox(height: 24),
        Text(
          'Total votes: $total',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }
}
