import 'package:flutter/material.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/services/poll_service.dart';

class CreatePollPage extends StatefulWidget {
  const CreatePollPage({super.key});

  @override
  State<CreatePollPage> createState() => _CreatePollPageState();
}

class _CreatePollPageState extends State<CreatePollPage> {
  final PollService _polls = PollService();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final List<TextEditingController> _options = [
    TextEditingController(),
    TextEditingController(),
  ];
  bool _allowsMultiple = false;
  bool _submitting = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await _polls.createPoll(
        title: _title.text,
        description: _description.text,
        allowsMultiple: _allowsMultiple,
        closesAt: null,
        optionLabels: _options.map((c) => c.text).toList(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
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
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'New poll',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Publish'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'Question',
              hintText: 'What do you want to ask?',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _description,
            decoration: const InputDecoration(
              labelText: 'Details (optional)',
              hintText: 'Add context so people vote thoughtfully.',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Allow multiple answers'),
            subtitle: const Text(
              'Voters can pick more than one choice.',
              style: TextStyle(fontSize: 12),
            ),
            value: _allowsMultiple,
            activeThumbColor: AppTheme.primaryGreen,
            onChanged: (v) => setState(() => _allowsMultiple = v),
          ),
          const SizedBox(height: 8),
          Text(
            'Answer choices',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _options.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _options[i],
                    decoration: InputDecoration(
                      labelText: 'Choice ${i + 1}',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                if (_options.length > 2)
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _options[i].dispose();
                        _options.removeAt(i);
                      });
                    },
                    icon: const Icon(Icons.remove_circle_outline),
                    color: Colors.grey[600],
                  ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          if (_options.length < 8)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  setState(() => _options.add(TextEditingController()));
                },
                icon: const Icon(Icons.add),
                label: const Text('Add choice'),
              ),
            ),
        ],
      ),
    );
  }
}
