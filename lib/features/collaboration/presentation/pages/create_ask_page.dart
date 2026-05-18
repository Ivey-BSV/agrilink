import 'package:flutter/material.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/providers/auth_provider.dart';
import 'package:cap/providers/reciprocity_ring_provider.dart';
import 'package:provider/provider.dart';

class CreateAskPage extends StatefulWidget {
  const CreateAskPage({super.key});

  @override
  State<CreateAskPage> createState() => _CreateAskPageState();
}

class _CreateAskPageState extends State<CreateAskPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _needController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final List<String> _selectedTags = [];
  String? _selectedTimingPreset;

  static const int _maxTags = 2;

  static const List<String> _availableTags = [
    'Equipment',
    'Logistics',
    'Documents',
    'Advisory',
    'Time Sensitive',
    'Knowledge',
    'Services',
    'Warm Intro',
    'Certification',
  ];

  static const List<String> _timingPresets = [
    'Flexible timeline',
    'Needed this week',
    'Needed this month',
    'Needed ASAP',
    'Custom',
  ];

  final List<String> _ontarioCounties = const [
    'Middlesex',
    'Algoma',
    'Brant',
    'Bruce',
    'Chatham-Kent',
    'Cochrane',
    'Dufferin',
    'Durham',
    'Elgin',
    'Essex',
    'Frontenac',
    'Grey',
    'Haliburton',
    'Halton',
    'Hamilton',
    'Hastings',
    'Huron',
    'Kawartha Lakes',
    'Kenora',
    'Lambton',
    'Lanark',
    'Leeds and Grenville',
    'Lennox and Addington',
    'Manitoulin',
    'Muskoka',
    'Niagara',
    'Nipissing',
    'Norfolk',
    'Northumberland',
    'Ottawa',
    'Oxford',
    'Parry Sound',
    'Peel',
    'Perth',
    'Peterborough',
    'Prescott and Russell',
    'Prince Edward',
    'Rainy River',
    'Renfrew',
    'Simcoe',
    'Stormont, Dundas and Glengarry',
    'Sudbury',
    'Thunder Bay',
    'Timiskaming',
    'Toronto',
    'Waterloo',
    'Wellington',
    'York',
  ];

  @override
  void initState() {
    super.initState();

    _needController.addListener(() => setState(() {}));
    _timeController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _needController.dispose();
    _timeController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  bool _isFormValid() {
    final need = _needController.text.trim();

    if (need.isEmpty) return false;

    if (_selectedTimingPreset == null) return false;
    if (_selectedTimingPreset == 'Custom' &&
        _timeController.text.trim().isEmpty) {
      return false;
    }

    if (_selectedTags.length > _maxTags) return false;

    return true;
  }

  Future<void> _submitAsk() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedTags.length > _maxTags) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select no more than $_maxTags tags'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.userId;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to submit an ask'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final timing = _selectedTimingPreset == 'Custom'
        ? _timeController.text.trim()
        : (_selectedTimingPreset ?? '');

    final provider = context.read<ReciprocityRingProvider>();
    final success = await provider.createAsk(
      userId: userId,
      need: _needController.text.trim(),
      timing: timing,
      location: _locationController.text.trim().isNotEmpty
          ? _locationController.text.trim()
          : null,
      tags: _selectedTags.isNotEmpty ? _selectedTags : null,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ask submitted successfully!'),
          backgroundColor: AppTheme.primaryGreen,
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to submit ask'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'Create an Ask',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppTheme.primaryGreen,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Be specific about what you need, when you need it, and any constraints. This helps others respond effectively.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _needController,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: 'What do you need? *',
                  hintText:
                      'Describe what you\'re looking for in detail. Include any specific requirements, timing constraints, or preferences.',
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.primaryGreen),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please describe what you need';
                  }
                  if (value.trim().length < 20) {
                    return 'Please provide more detail (at least 20 characters)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ButtonTheme(
                alignedDropdown: true,
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedTimingPreset,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Deadline or timing *',
                    hintText: 'Select a timing option',
                    border: const OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.primaryGreen),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.calendar_today_outlined),
                  ),
                  items: _timingPresets
                      .map((preset) => DropdownMenuItem(
                            value: preset,
                            child: Text(preset),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedTimingPreset = value;
                      if (value != 'Custom') {
                        _timeController.text = value ?? '';
                      } else {
                        _timeController.clear();
                      }
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Please select a timing option';
                    }
                    return null;
                  },
                ),
              ),
              if (_selectedTimingPreset == 'Custom') ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _timeController,
                  decoration: InputDecoration(
                    labelText: 'Custom timing *',
                    hintText: 'e.g., Needed by Dec 4, Needed by Jan 15',
                    border: const OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.primaryGreen),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.edit_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please specify your custom timing';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 20),
              ButtonTheme(
                alignedDropdown: true,
                child: DropdownButtonFormField<String>(
                  initialValue: _locationController.text.isNotEmpty
                      ? _locationController.text
                      : null,
                  isExpanded: true,
                  menuMaxHeight: 320,
                  decoration: InputDecoration(
                    labelText: 'Location',
                    hintText: 'Select a location',
                    border: const OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.primaryGreen),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.location_on_outlined),
                  ),
                  items: _ontarioCounties
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(
                              c,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      _locationController.text = v ?? '';
                    });
                  },
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Tags',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select relevant categories (optional)',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _availableTags.map((tag) {
                  final isSelected = _selectedTags.contains(tag);
                  return FilterChip(
                    label: Text(tag),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          if (_selectedTags.length < _maxTags) {
                            _selectedTags.add(tag);
                          }
                        } else {
                          _selectedTags.remove(tag);
                        }
                      });
                    },
                    selectedColor: AppTheme.primaryGreen.withValues(alpha: 0.2),
                    checkmarkColor: AppTheme.primaryGreen,
                    labelStyle: TextStyle(
                      color:
                          isSelected ? AppTheme.primaryGreen : Colors.grey[700],
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),
              if (_selectedTags.length >= _maxTags)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Maximum $_maxTags tags selected',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[700],
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isFormValid() ? () => _submitAsk() : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    disabledForegroundColor: Colors.grey[600],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Submit Ask',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
