import 'package:flutter/material.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/providers/auth_provider.dart';
import 'package:cap/providers/reciprocity_ring_provider.dart';
import 'package:provider/provider.dart';

class CreateOfferPage extends StatefulWidget {
  const CreateOfferPage({super.key});

  @override
  State<CreateOfferPage> createState() => _CreateOfferPageState();
}

class _CreateOfferPageState extends State<CreateOfferPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _offerController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _windowController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final List<String> _selectedTags = [];
  String? _selectedWindowPreset;

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

  static const List<String> _windowPresets = [
    'Ongoing',
    'This week',
    'This month',
    'Next month',
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

    _offerController.addListener(() => setState(() {}));
    _windowController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _offerController.dispose();
    _descriptionController.dispose();
    _windowController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  bool _isFormValid() {
    final offer = _offerController.text.trim();

    if (offer.isEmpty) return false;

    if (_selectedWindowPreset == null) return false;
    if (_selectedWindowPreset == 'Custom' &&
        _windowController.text.trim().isEmpty) {
      return false;
    }

    if (_selectedTags.length > _maxTags) return false;

    return true;
  }

  Future<void> _submitOffer() async {
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
          content: Text('Please log in to publish an offer'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final window = _selectedWindowPreset == 'Custom'
        ? _windowController.text.trim()
        : (_selectedWindowPreset ?? '');

    final provider = context.read<ReciprocityRingProvider>();
    final success = await provider.createOffer(
      userId: userId,
      offer: _offerController.text.trim(),
      window: window,
      description: _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : null,
      location: _locationController.text.trim().isNotEmpty
          ? _locationController.text.trim()
          : null,
      tags: _selectedTags.isNotEmpty ? _selectedTags : null,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Offer published successfully!'),
          backgroundColor: AppTheme.primaryGreen,
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to publish offer'),
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
          'Create an Offer',
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
                        'Share what you can offer to help others in the ring. Be clear about availability and any conditions.',
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
                controller: _offerController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'What can you share? *',
                  hintText:
                      'Brief summary of your offer (e.g., "4-ton flatbed trailer available for shared harvest runs")',
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
                    return 'Please describe what you can offer';
                  }
                  if (value.trim().length < 10) {
                    return 'Please provide more detail (at least 10 characters)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Additional details',
                  hintText:
                      'Provide more context, conditions, or specifics about your offer (optional)',
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
              ),
              const SizedBox(height: 20),
              ButtonTheme(
                alignedDropdown: true,
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedWindowPreset,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Availability window *',
                    hintText: 'Select an availability option',
                    border: const OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.primaryGreen),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.access_time_outlined),
                  ),
                  items: _windowPresets
                      .map((preset) => DropdownMenuItem(
                            value: preset,
                            child: Text(preset),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedWindowPreset = value;
                      if (value != 'Custom') {
                        _windowController.text = value ?? '';
                      } else {
                        _windowController.clear();
                      }
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Please select an availability option';
                    }
                    return null;
                  },
                ),
              ),
              if (_selectedWindowPreset == 'Custom') ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _windowController,
                  decoration: InputDecoration(
                    labelText: 'Custom availability *',
                    hintText:
                        'e.g., Nov 20 – Dec 2, Fridays 2-4pm, Dec 15 – Feb 28',
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
                      return 'Please specify your custom availability';
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
                  onPressed: _isFormValid() ? () => _submitOffer() : null,
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
                    'Publish Offer',
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
