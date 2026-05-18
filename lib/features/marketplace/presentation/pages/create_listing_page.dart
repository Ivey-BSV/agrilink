import 'package:flutter/material.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/providers/marketplace_provider.dart';
import 'package:cap/shared/widgets/cached_image_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class CreateListingPage extends StatefulWidget {
  const CreateListingPage({super.key});

  @override
  State<CreateListingPage> createState() => _CreateListingPageState();
}

class _CreateListingPageState extends State<CreateListingPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _conditionController = TextEditingController();
  bool _isLoading = false;
  String? _selectedImageUrl;
  final ImagePicker _picker = ImagePicker();
  final List<String> _selectedTags = [];
  final Map<String, TextEditingController> _specValueControllers = {};
  final Map<String, TextEditingController> _specLabelControllers = {};
  final List<String> _specKeys = [];
  static const int _maxTags = 5;

  static const Map<String, List<String>> _tagCategories = {
    'Farming Methods & Practices': [
      'Organic',
      'Regenerative',
      'Biodynamic',
      'No-Till',
      'Low-Till',
      'Rotational Grazing',
      'Silvopasture',
      'Pasture Management',
      'Composting',
      'Cover Crops',
      'Seed Saving',
      'Pest Management',
      'Weed Control',
      'Soil Health',
      'Soil Regeneration',
      'Water Management',
      'Drip Irrigation',
      'Irrigation',
      'Yield Optimization',
    ],
    'Crops & Products': [
      'Cash Crops',
      'Blueberries',
      'Lavender',
      'Cut Flowers',
      'Floriculture',
      'Heritage Varietals',
      'Artisanal Products',
      'Value-Added Products',
      'Dairy',
      'Livestock',
      'Pastured Animals',
      'Grass-Fed',
    ],
    'Technology & Equipment': [
      'AgTech',
      'Equipment',
      'Tractors',
      'Greenhouses',
      'Hydroponics',
      'Fertilizers',
    ],
    'Sustainability & Environment': [
      'Biodiversity',
      'Pollinator Habitats',
      'Pollinators',
      'Wetland Restoration',
      'Sustainability',
      'Local Food',
      'Fair Trade',
    ],
    'Community & Education': [
      'Community Engagement',
      'Education',
      'Farm Tours',
      'Workshops',
      'Youth Programs',
      'Indigenous Learning',
      'Peer Collaboration',
      'Economic Resilience',
      'Succession Planning',
    ],
    'Specialized Practices': [
      'Agritourism',
      'Agroforestry',
      'Aquaculture',
      'Beekeeping',
      'Market Garden',
      'Urban Farming',
      'Weather',
    ],
  };

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _conditionController.dispose();
    for (var controller in _specValueControllers.values) {
      controller.dispose();
    }
    for (var controller in _specLabelControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? picked = await _picker.pickImage(
          source: ImageSource.gallery, imageQuality: 85);
      if (picked == null) return;

      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please log in to upload images.'),
              backgroundColor: Colors.red),
        );
        return;
      }

      final bytes = await picked.readAsBytes();
      final fileExt = picked.name.split('.').last;
      final path =
          '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await supabase.storage.from('marketplace-images').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
                cacheControl: '3600', upsert: true, contentType: 'image/jpeg'),
          );

      final publicUrl =
          supabase.storage.from('marketplace-images').getPublicUrl(path);
      setState(() {
        _selectedImageUrl = publicUrl;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Image uploaded'),
              backgroundColor: AppTheme.primaryGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Image upload failed: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImageUrl = null;
    });
  }

  String _normalizePrice(String priceInput) {
    final trimmed = priceInput.trim();
    if (trimmed.isEmpty) return trimmed;

    if (trimmed.toLowerCase() == 'free') {
      return 'Free';
    }

    final numericValue =
        double.tryParse(trimmed.replaceAll(RegExp(r'[^\d.]'), ''));
    if (numericValue != null && numericValue == 0.0) {
      return 'Free';
    }

    return trimmed;
  }

  Future<Size> _getImageSize(String imageUrl) async {
    try {
      final image = CachedNetworkImageProvider(imageUrl);
      final completer = Completer<Size>();
      final imageStream = image.resolve(const ImageConfiguration());
      late ImageStreamListener listener;
      listener = ImageStreamListener((ImageInfo info, bool _) {
        completer.complete(Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        ));
        imageStream.removeListener(listener);
      });
      imageStream.addListener(listener);
      return completer.future;
    } catch (e) {
      return const Size(1, 1);
    }
  }

  void _addSpecification() {
    setState(() {
      final key = 'spec_${DateTime.now().millisecondsSinceEpoch}';
      _specKeys.add(key);
      _specLabelControllers[key] = TextEditingController();
      _specValueControllers[key] = TextEditingController();
    });
  }

  void _removeSpecification(String key) {
    setState(() {
      _specKeys.remove(key);
      _specLabelControllers[key]?.dispose();
      _specValueControllers[key]?.dispose();
      _specLabelControllers.remove(key);
      _specValueControllers.remove(key);
    });
  }

  Future<void> _submitListing() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter a title'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_priceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter a price'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter a description'),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final provider = Provider.of<MarketplaceProvider>(context, listen: false);

      final Map<String, String> specifications = {};
      for (var key in _specKeys) {
        final label = _specLabelControllers[key]?.text.trim() ?? '';
        final value = _specValueControllers[key]?.text.trim() ?? '';
        if (label.isNotEmpty && value.isNotEmpty) {
          specifications[label] = value;
        }
      }

      final normalizedPrice = _normalizePrice(_priceController.text.trim());

      await provider.createListing(
        title: _titleController.text.trim(),
        price: normalizedPrice,
        description: _descriptionController.text.trim(),
        condition: _conditionController.text.trim().isEmpty
            ? null
            : _conditionController.text.trim(),
        tags: _selectedTags,
        imageUrls: _selectedImageUrl != null ? [_selectedImageUrl!] : [],
        specifications: specifications,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Listing created successfully!'),
              backgroundColor: AppTheme.primaryGreen),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to create listing: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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
          'Create Listing',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontFamily: 'Poppins',
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitListing,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.mintGreen.withValues(alpha: 0.2),
                foregroundColor: AppTheme.primaryGreen,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.primaryGreen),
                      ),
                    )
                  : const Text(
                      'Post',
                      style: TextStyle(
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _titleController,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Title *',
                      hintText: 'Enter listing title',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                    style: const TextStyle(fontSize: 16, fontFamily: 'Poppins'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _priceController,
                    decoration: const InputDecoration(
                      labelText: 'Price *',
                      hintText: 'e.g., \$2.50/lb, \$150/day, Free',
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(fontSize: 16, fontFamily: 'Poppins'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _conditionController,
                    decoration: const InputDecoration(
                      labelText: 'Condition',
                      hintText:
                          'e.g., Excellent, Good Condition, Fresh Harvest',
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(fontSize: 16, fontFamily: 'Poppins'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'Description *',
                      hintText: 'Describe your listing...',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                    style: const TextStyle(fontSize: 16, fontFamily: 'Poppins'),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Attach Image',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_selectedImageUrl == null)
                            ElevatedButton.icon(
                              onPressed:
                                  _isLoading ? null : _pickAndUploadImage,
                              icon: const Icon(Icons.photo_library_outlined),
                              label: const Text('Add Photo'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            )
                          else
                            FutureBuilder<Size>(
                              future: _getImageSize(_selectedImageUrl!),
                              builder: (context, snapshot) {
                                final isPortrait = snapshot.hasData &&
                                    snapshot.data!.height >
                                        snapshot.data!.width;
                                final aspectRatio = isPortrait ? 4 / 5 : 5 / 4;

                                return SizedBox(
                                  width: double.infinity,
                                  child: AspectRatio(
                                    aspectRatio: aspectRatio,
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: Colors.grey[300]!),
                                      ),
                                      child: Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: CachedImageWidget(
                                              imageUrl: _selectedImageUrl!,
                                              width: double.infinity,
                                              height: double.infinity,
                                              fit: BoxFit.cover,
                                              errorWidget: Container(
                                                color: Colors.grey[200],
                                                child: const Center(
                                                  child: Icon(Icons.image,
                                                      size: 48,
                                                      color: Colors.grey),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: 8,
                                            right: 8,
                                            child: GestureDetector(
                                              onTap: () => _removeImage(),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(4),
                                                decoration: const BoxDecoration(
                                                  color: Colors.black54,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.close,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Tags',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              Text(
                                '${_selectedTags.length}/$_maxTags selected',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _selectedTags.length >= _maxTags
                                      ? Colors.orange[700]
                                      : Colors.grey[600],
                                  fontWeight: _selectedTags.length >= _maxTags
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ..._tagCategories.entries
                              .toList()
                              .asMap()
                              .entries
                              .map((mapEntry) {
                            final index = mapEntry.key;
                            final entry = mapEntry.value;
                            final isLast = index == _tagCategories.length - 1;
                            final categoryName = entry.key;
                            final tags = entry.value;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  categoryName,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: tags.map((tag) {
                                    final selected =
                                        _selectedTags.contains(tag);
                                    return FilterChip(
                                      label: Text(
                                        tag,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      selected: selected,
                                      onSelected: (isSelected) {
                                        setState(() {
                                          if (isSelected) {
                                            if (_selectedTags.length >=
                                                _maxTags) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                      'You can select up to $_maxTags tags'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                              return;
                                            }
                                            _selectedTags.add(tag);
                                          } else {
                                            _selectedTags.remove(tag);
                                          }
                                        });
                                      },
                                      selectedColor: AppTheme.primaryGreen
                                          .withValues(alpha: 0.2),
                                      checkmarkColor: AppTheme.primaryGreen,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: const VisualDensity(
                                        horizontal: -2,
                                        vertical: -2,
                                      ),
                                    );
                                  }).toList(),
                                ),
                                if (!isLast) const SizedBox(height: 24),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Specifications',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _addSpecification,
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.primaryGreen,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_specKeys.isEmpty)
                            Text(
                              'No specifications added',
                              style: TextStyle(color: Colors.grey[600]),
                            )
                          else
                            ..._specKeys.asMap().entries.map((entry) {
                              final index = entry.key;
                              final key = entry.value;
                              final isLast = index == _specKeys.length - 1;
                              return Padding(
                                padding:
                                    EdgeInsets.only(bottom: isLast ? 0 : 12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: TextField(
                                        controller: _specLabelControllers[key],
                                        decoration: const InputDecoration(
                                          labelText: 'Label',
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 3,
                                      child: TextField(
                                        controller: _specValueControllers[key],
                                        decoration: const InputDecoration(
                                          labelText: 'Value',
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () =>
                                          _removeSpecification(key),
                                      color: Colors.red,
                                    ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'Listing guidelines',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.info_outline,
                              size: 20,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '• Provide accurate descriptions and pricing\n'
                          '• Include clear, high-quality photos\n'
                          '• Be honest about condition and availability\n'
                          '• Respond promptly to inquiries',
                          style: TextStyle(
                            height: 1.5,
                            fontSize: 13,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
