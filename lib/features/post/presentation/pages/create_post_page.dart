import 'package:flutter/material.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/providers/post_provider.dart';
import 'package:cap/shared/widgets/cached_image_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  bool _isLoading = false;
  String? _selectedImagePath;
  String? _selectedVideoPath;
  final List<String> _selectedTags = [];
  final ImagePicker _picker = ImagePicker();

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
    _contentController.dispose();
    _locationController.dispose();
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

      await supabase.storage.from('post-images').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
                cacheControl: '3600', upsert: true, contentType: 'image/jpeg'),
          );

      final publicUrl = supabase.storage.from('post-images').getPublicUrl(path);
      setState(() {
        _selectedImagePath = publicUrl;
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

  Future<void> _pickVideo() async {
    try {
      final XFile? picked = await _picker.pickVideo(
          source: ImageSource.gallery, maxDuration: const Duration(minutes: 5));
      if (picked == null) return;

      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please log in to upload videos.'),
              backgroundColor: Colors.red),
        );
        return;
      }

      final bytes = await picked.readAsBytes();
      final fileExt = picked.name.split('.').last;
      final path =
          '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await supabase.storage.from('post-videos').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
                cacheControl: '3600', upsert: true, contentType: 'video/mp4'),
          );

      final publicUrl = supabase.storage.from('post-videos').getPublicUrl(path);
      setState(() {
        _selectedVideoPath = publicUrl;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Video uploaded'),
              backgroundColor: AppTheme.primaryGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Video upload failed: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
      }
    }
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

  Future<void> _createPost() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a title'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final postProvider = context.read<PostProvider>();
      await postProvider.createPost(
        _contentController.text.trim(),
        imageUrl: _selectedImagePath ?? _selectedVideoPath,
        tags: _selectedTags,
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        title: _titleController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post created successfully!'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating post: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
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
          'Create Post',
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
              onPressed: _isLoading ? null : _createPost,
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              maxLength: 80,
              style: const TextStyle(
                fontWeight: FontWeight.normal,
              ),
              decoration: InputDecoration(
                labelText: 'Title *',
                hintText: 'Give your post a clear title',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide:
                      BorderSide(color: AppTheme.primaryGreen, width: 2),
                ),
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _contentController,
              maxLines: 4,
              maxLength: 500,
              style: const TextStyle(
                fontWeight: FontWeight.normal,
              ),
              decoration: InputDecoration(
                labelText: 'Description',
                hintText:
                    'Share your farming experience, tips, or questions...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide:
                      BorderSide(color: AppTheme.primaryGreen, width: 2),
                ),
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _locationController.text.isNotEmpty
                  ? _locationController.text
                  : null,
              isExpanded: false,
              menuMaxHeight: 320,
              style: const TextStyle(
                fontWeight: FontWeight.normal,
                color: Colors.black,
              ),
              decoration: InputDecoration(
                labelText: 'Location',
                prefixIcon: const Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide:
                      BorderSide(color: AppTheme.primaryGreen, width: 2),
                ),
                isDense: true,
              ),
              items: _ontarioCounties
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(
                          c,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.normal),
                        ),
                      ))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _locationController.text = v ?? '';
                });
              },
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Attach Media',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_selectedImagePath == null &&
                        _selectedVideoPath == null)
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
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
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _pickVideo,
                              icon: const Icon(Icons.videocam_outlined),
                              label: const Text('Add Video'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    AppTheme.primaryGreen.withValues(alpha: 0.1),
                                foregroundColor: AppTheme.primaryGreen,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                    color:
                                        AppTheme.primaryGreen.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          if (_selectedImagePath != null)
                            FutureBuilder<Size>(
                              future: _getImageSize(_selectedImagePath!),
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
                                              imageUrl: _selectedImagePath!,
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
                                              onTap: () => setState(() =>
                                                  _selectedImagePath = null),
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
                          if (_selectedVideoPath != null)
                            Container(
                              width: double.infinity,
                              height: 200,
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                                color: Colors.black,
                              ),
                              child: Stack(
                                children: [
                                  const Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.play_circle_filled,
                                          size: 64,
                                          color: Colors.white70,
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'Video attached',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: GestureDetector(
                                      onTap: () => setState(
                                          () => _selectedVideoPath = null),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
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
                        ],
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
                              final selected = _selectedTags.contains(tag);
                              return FilterChip(
                                label: Text(
                                  tag,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                selected: selected,
                                onSelected: (isSelected) {
                                  setState(() {
                                    if (isSelected) {
                                      if (_selectedTags.length >= _maxTags) {
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
                                selectedColor:
                                    AppTheme.primaryGreen.withValues(alpha: 0.2),
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
                          'Posting guidelines',
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
                    '• Share sustainable farming practices\n'
                    '• Ask questions about agriculture\n'
                    '• Post harvest updates and tips\n'
                    '• Be respectful and supportive',
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
