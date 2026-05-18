import 'package:flutter/material.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/services/future_visualization_service.dart';

class FutureVisualizationPage extends StatefulWidget {
  const FutureVisualizationPage({super.key});

  @override
  State<FutureVisualizationPage> createState() =>
      _FutureVisualizationPageState();
}

class _FutureVisualizationPageState extends State<FutureVisualizationPage> {
  int _step = 0;
  bool _isCreating = false;
  final FutureVisualizationService _service = FutureVisualizationService();

  String? _intent;
  final TextEditingController _visionController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();

  double _months = 18;
  final Set<String> _focus = <String>{};
  static const int _maxFocusAreas = 2;

  final List<_Milestone> _milestones = [];

  final TextEditingController _askController = TextEditingController();
  final TextEditingController _offerController = TextEditingController();

  bool _isPublic = true;

  @override
  void dispose() {
    _visionController.dispose();
    _titleController.dispose();
    _askController.dispose();
    _offerController.dispose();

    for (final milestone in _milestones) {
      milestone.titleController.dispose();
    }
    super.dispose();
  }

  bool _isStepValid() {
    switch (_step) {
      case 0:
        return _titleController.text.trim().isNotEmpty &&
            _intent != null &&
            _visionController.text.trim().isNotEmpty;
      case 1:
        return _focus.isNotEmpty;
      case 2:
        if (_milestones.isEmpty) return false;
        for (final milestone in _milestones) {
          if (milestone.title.trim().isEmpty ||
              milestone.monthOffset < 1 ||
              milestone.monthOffset > _months.round()) {
            return false;
          }
        }
        return true;
      case 3:
      case 4:
        return true;
      default:
        return false;
    }
  }

  String? _getStepValidationMessage() {
    switch (_step) {
      case 0:
        if (_titleController.text.trim().isEmpty) {
          return 'Please provide a title for your plan';
        }
        if (_intent == null) {
          return 'Please select what you are aiming for';
        }
        if (_visionController.text.trim().isEmpty) {
          return 'Please describe your vision';
        }
        return null;
      case 1:
        if (_focus.isEmpty) {
          return 'Please select at least one focus area';
        }
        return null;
      case 2:
        if (_milestones.isEmpty) {
          return 'Please add at least one milestone';
        }
        for (int i = 0; i < _milestones.length; i++) {
          final milestone = _milestones[i];
          if (milestone.title.trim().isEmpty) {
            return 'Milestone ${i + 1} needs a description';
          }
          if (milestone.monthOffset < 1 ||
              milestone.monthOffset > _months.round()) {
            return 'Milestone ${i + 1} month (${milestone.monthOffset}) is invalid. Must be between 1 and ${_months.round()} months';
          }
        }
        return null;
      default:
        return null;
    }
  }

  void _next() {
    if (!_isStepValid()) {
      final message = _getStepValidationMessage();
      if (message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
      return;
    }

    if (_step < 4) {
      setState(() => _step += 1);
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step -= 1);
    }
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildStepperHeader(),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildStepContent(),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepperHeader() {
    final titles = [
      'Intent',
      'Horizon & Focus',
      'Milestones',
      'Reciprocity',
      'Privacy & Review',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          for (int i = 0; i < titles.length; i++) ...[
            _StepDot(active: i == _step, completed: i < _step),
            if (i < titles.length - 1)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  color: i < _step ? AppTheme.primaryGreen : Colors.grey[300],
                ),
              ),
          ]
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return _buildIntentStep();
      case 1:
        return _buildHorizonStep();
      case 2:
        return _buildMilestonesStep();
      case 3:
        return _buildReciprocityStep();
      case 4:
      default:
        return _buildReviewStep();
    }
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          if (_step > 0)
            OutlinedButton(
              onPressed: _isCreating ? null : _back,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black,
                side: BorderSide(color: Colors.black.withValues(alpha: 0.12)),
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Back'),
            ),
          if (_step > 0) const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: (_isCreating || (_step < 4 && !_isStepValid()))
                  ? null
                  : () {
                      if (_step < 4) {
                        _next();
                      } else {
                        _createVision();
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isCreating
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(_step < 4 ? 'Next' : 'Create Plan'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntentStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Plan Title',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            const Text('*', style: TextStyle(color: Colors.red, fontSize: 18)),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _titleController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Give your future visualization a title',
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text('What are you aiming for?',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            const Text('*', style: TextStyle(color: Colors.red, fontSize: 18)),
          ],
        ),
        const SizedBox(height: 12),
        RadioGroup<String?>(
          groupValue: _intent,
          onChanged: (v) => setState(() => _intent = v),
          child: Column(
            children: [
              _radio('Community impact'),
              _radio('Improve soil health'),
              _radio('Boost yield'),
              _radio('Reduce costs'),
              _radio('Other'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text('Describe your farm 1–3 years from now',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(width: 4),
            const Text('*', style: TextStyle(color: Colors.red, fontSize: 18)),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _visionController,
          onChanged: (_) => setState(() {}),
          maxLines: 6,
          decoration: InputDecoration(
            hintText:
                'Paint a clear picture of your future farm (practices, outcomes, community effects, environment)',
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _radio(String label) {
    return RadioListTile<String?>(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      value: label,
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppTheme.primaryGreen;
        }
        return null;
      }),
    );
  }

  Widget _buildHorizonStep() {
    const options = [
      'Soil',
      'Water',
      'Inputs',
      'Market',
      'Equipment',
      'Community'
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Time horizon',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: _months,
                onChanged: (v) {
                  final newMonths = v.roundToDouble();
                  setState(() {
                    _months = newMonths;

                    for (final milestone in _milestones) {
                      if (milestone.monthOffset > newMonths.round()) {
                        milestone.monthOffset = newMonths.round();
                      }
                    }
                  });
                },
                min: 6,
                max: 36,
                divisions: 30,
                label: '${_months.round()} months',
                activeColor: AppTheme.primaryGreen,
                inactiveColor: AppTheme.primaryGreen.withValues(alpha: 0.2),
              ),
            ),
            const SizedBox(width: 12),
            Text('${_months.round()} months'),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text('Focus areas',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(width: 4),
                const Text('*',
                    style: TextStyle(color: Colors.red, fontSize: 18)),
              ],
            ),
            Text(
              '${_focus.length}/$_maxFocusAreas',
              style: TextStyle(
                color: _focus.length >= _maxFocusAreas
                    ? Colors.orange[700]
                    : Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final opt in options)
              FilterChip(
                selected: _focus.contains(opt),
                label: Text(opt),
                onSelected: (sel) => setState(() {
                  if (sel) {
                    if (_focus.length < _maxFocusAreas) {
                      _focus.add(opt);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Maximum $_maxFocusAreas focus areas allowed'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  } else {
                    _focus.remove(opt);
                  }
                }),
                selectedColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildMilestonesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Milestones',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            const Text('*', style: TextStyle(color: Colors.red, fontSize: 18)),
          ],
        ),
        const SizedBox(height: 8),
        Text('Add your own milestones and set when you plan to achieve them.',
            style: TextStyle(color: Colors.grey[700])),
        const SizedBox(height: 12),
        if (_milestones.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No milestones yet. Tap "Add milestone" to get started.',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ...List.generate(_milestones.length, (i) => _buildMilestoneTile(i)),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => setState(() {
            _milestones.add(_Milestone(title: '', monthOffset: 1));
          }),
          icon: const Icon(Icons.add),
          label: const Text('Add milestone'),
        ),
      ],
    );
  }

  Widget _buildMilestoneTile(int index) {
    final milestone = _milestones[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    key: ValueKey('milestone_title_$index'),
                    controller: milestone.titleController,
                    onChanged: (v) {
                      milestone.title = v;
                      setState(() {});
                    },
                    maxLines: null,
                    minLines: 2,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      hintText: 'Enter milestone description',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => setState(() {
                    _milestones[index].titleController.dispose();
                    _milestones.removeAt(index);
                  }),
                  icon: const Icon(Icons.delete_outline, color: Colors.grey),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.schedule, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Month:',
                  style: TextStyle(color: Colors.grey[700], fontSize: 14),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 120,
                  child: DropdownButtonFormField<int>(
                    initialValue: milestone.monthOffset.clamp(1, _months.round()),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 14),
                    items: List.generate(
                      _months.round(),
                      (i) => DropdownMenuItem<int>(
                        value: i + 1,
                        child: Text(
                          'Month ${i + 1}',
                          style: const TextStyle(color: Colors.black),
                        ),
                      ),
                    ),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          milestone.monthOffset = value;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReciprocityStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reciprocity',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('Ask (what help do you need?)'),
        const SizedBox(height: 6),
        TextField(
          controller: _askController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'e.g., manure for compost, irrigation tips, shared tools',
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 16),
        Text('Offer (what can you share?)'),
        const SizedBox(height: 6),
        TextField(
          controller: _offerController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'e.g., seed starts, field help, equipment time',
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Privacy & Review',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Row(
          children: [
            Switch(
              value: _isPublic,
              thumbColor: WidgetStateProperty.all(AppTheme.primaryGreen),
              onChanged:
                  _isCreating ? null : (v) => setState(() => _isPublic = v),
            ),
            const SizedBox(width: 8),
            Text(_isPublic
                ? 'Public (visible in community)'
                : 'Personal (visible only to you)'),
          ],
        ),
        const SizedBox(height: 16),
        _reviewTile(
            'Title',
            _titleController.text.isEmpty
                ? '(No title)'
                : _titleController.text.trim()),
        _reviewTile('Intent', _intent ?? '(Not selected)'),
        _reviewTile('Horizon', '${_months.round()} months'),
        _reviewTile('Focus', _focus.isEmpty ? 'None' : _focus.join(', ')),
        _reviewTile(
            'Vision',
            _visionController.text.isEmpty
                ? '(No description)'
                : _visionController.text.trim()),
        const SizedBox(height: 8),
        Text('Milestones', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        ..._milestones.map((m) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.flag, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(child: Text('${m.title} — Month ${m.monthOffset}')),
                ],
              ),
            )),
        const SizedBox(height: 8),
        _reviewTile(
            'Ask',
            _askController.text.isEmpty
                ? '(None)'
                : _askController.text.trim()),
        _reviewTile(
            'Offer',
            _offerController.text.isEmpty
                ? '(None)'
                : _offerController.text.trim()),
      ],
    );
  }

  Widget _reviewTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 110,
              child:
                  Text(label, style: const TextStyle(color: Colors.black54))),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _createVision() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a title for your plan')),
      );
      return;
    }

    if (_intent == null || _intent!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select what you are aiming for')),
      );
      return;
    }

    if (_visionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe your vision')),
      );
      return;
    }

    if (_focus.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one focus area')),
      );
      return;
    }

    if (_milestones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one milestone')),
      );
      return;
    }

    for (int i = 0; i < _milestones.length; i++) {
      final milestone = _milestones[i];
      if (milestone.title.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Milestone ${i + 1} needs a description')),
        );
        return;
      }
      if (milestone.monthOffset < 1 ||
          milestone.monthOffset > _months.round()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Milestone ${i + 1} month (${milestone.monthOffset}) is invalid. Must be between 1 and ${_months.round()} months')),
        );
        return;
      }
    }

    setState(() => _isCreating = true);

    try {
      final milestonesData = _milestones
          .map((m) => {
                'title': m.title.trim(),
                'monthOffset': m.monthOffset,
              })
          .toList();

      await _service.createFutureVisualization(
        title: _titleController.text.trim(),
        intent: _intent!,
        visionDescription: _visionController.text.trim(),
        months: _months.round(),
        focusAreas: _focus.toList(),
        milestones: milestonesData,
        ask: _askController.text.trim().isEmpty
            ? null
            : _askController.text.trim(),
        offer: _offerController.text.trim().isEmpty
            ? null
            : _offerController.text.trim(),
        isPublic: _isPublic,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isPublic
              ? 'Future Vision created (Public)'
              : 'Future Vision created (Personal)'),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create plan: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }
}

class _StepDot extends StatelessWidget {
  final bool active;
  final bool completed;
  const _StepDot({required this.active, required this.completed});

  @override
  Widget build(BuildContext context) {
    Color color = completed
        ? AppTheme.primaryGreen
        : active
            ? AppTheme.primaryGreen
            : Colors.grey[300]!;
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: completed
            ? AppTheme.primaryGreen.withValues(alpha: 0.15)
            : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
    );
  }
}

class _Milestone {
  _Milestone({required this.title, required this.monthOffset})
      : titleController = TextEditingController(text: title);

  String title;
  int monthOffset;
  final TextEditingController titleController;

  void dispose() {
    titleController.dispose();
  }
}
