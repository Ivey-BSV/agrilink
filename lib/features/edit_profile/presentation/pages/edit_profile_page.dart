import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cap/core/animations/app_animations.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/core/utils/username_utils.dart';
import 'package:cap/providers/auth_provider.dart';
import 'package:cap/providers/profile_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _isUploadingImage = false;

  String? _selectedFarmType;
  String? _selectedExperienceLevel;
  String? _selectedCounty;

  bool _isLoading = false;

  final List<String> _farmTypes = [
    'Aquaculture',
    'Crop Farming',
    'Dairy Farming',
    'Horticulture',
    'Livestock Farming',
    'Mixed Farming',
    'Organic Farming',
    'Poultry Farming',
  ];

  final List<String> _ontarioCounties = [
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
    "Prince Edward",
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

  final List<String> _experienceLevels = [
    'Beginner',
    'Intermediate',
    'Advanced',
    'Expert',
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
    });
  }

  String? _matchOption(String? incoming, List<String> options) {
    if (incoming == null) return null;
    final lower = incoming.toLowerCase();
    for (final opt in options) {
      if (opt.toLowerCase() == lower) return opt;
    }
    return null;
  }

  Future<void> _loadUserData() async {
    final authProvider = context.read<AuthProvider>();
    final profileProvider = context.read<ProfileProvider>();

    _emailController.text = authProvider.userEmail ?? '';

    if (authProvider.userId != null) {
      await profileProvider.loadProfile(authProvider.userId!);
    }

    final profile = profileProvider.currentProfile;
    if (profile != null) {
      _usernameController.text = normalizeUsername(profile.username ?? '');
      _fullNameController.text = profile.fullName ?? '';
      _bioController.text = profile.bio ?? '';
      _locationController.text = profile.location ?? '';
      if (profile.location != null &&
          _ontarioCounties.contains(profile.location)) {
        _selectedCounty = profile.location;
      }

      _selectedFarmType = _matchOption(profile.farmType, _farmTypes);
      _selectedExperienceLevel =
          _matchOption(profile.experienceLevel, _experienceLevels);
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  String _getInitialLetter(String name) {
    if (name.isEmpty) return 'U';
    return name[0];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundLight,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: AppAnimations.fadeIn(
          child: Text(
            'Edit Profile',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: AppAnimations.scaleIn(
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.mintGreen.withOpacity(0.2),
                  foregroundColor: AppTheme.primaryGreen,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: AppTheme.primaryGreen.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                ),
                child: _isLoading
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.primaryGreen),
                        ),
                      )
                    : const Text(
                        'Save',
                        style: TextStyle(
                          color: AppTheme.primaryGreen,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
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
            _buildProfilePictureSection(),
            const SizedBox(height: 24),
            _buildSectionHeader('Basic Information'),
            _buildSettingsCard([
              _buildTextField(
                'Username',
                _usernameController,
                Icons.person,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'[\s@]')),
                ],
                hintText: 'Letters, numbers, underscores (no spaces or @)',
              ),
              _buildTextField('Full Name', _fullNameController, Icons.badge),
              _buildTextField(
                'Email',
                _emailController,
                Icons.email,
                keyboardType: TextInputType.emailAddress,
                enabled: false,
              ),
              _buildTextField(
                'Bio',
                _bioController,
                Icons.description,
                maxLines: 3,
                hintText:
                    'Tell us about yourself and your farming experience...',
                alwaysShowLabel: true,
              ),
            ]),
            const SizedBox(height: 24),
            _buildSectionHeader('Farm Information'),
            _buildSettingsCard([
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: DropdownButtonFormField<String>(
                  value: _selectedCounty,
                  isExpanded: true,
                  style: const TextStyle(
                    fontWeight: FontWeight.normal,
                    color: Colors.black,
                  ),
                  decoration: InputDecoration(
                    labelText: 'County Location',
                    hintText: 'County Location',
                    prefixIcon:
                        Icon(Icons.location_on, color: AppTheme.primaryGreen),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide:
                          BorderSide(color: AppTheme.primaryGreen, width: 2),
                    ),
                  ),
                  items: _ontarioCounties
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(
                              c,
                              style: const TextStyle(
                                  fontWeight: FontWeight.normal),
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCounty = v),
                ),
              ),
              _buildDropdownField(
                'Farm Type',
                _selectedFarmType,
                _farmTypes,
                Icons.agriculture,
                (value) => setState(() => _selectedFarmType = value),
                hint: 'Farm Type',
              ),
              _buildDropdownField(
                'Experience Level',
                _selectedExperienceLevel,
                _experienceLevels,
                Icons.trending_up,
                (value) => setState(() => _selectedExperienceLevel = value),
                hint: 'Experience Level',
              ),
            ]),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withOpacity(0.05)),
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
                          'Farm details guide',
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
                    'Farm details like farm name, size, crops, livestock, and practices are managed separately. Go to your Profile → "Farm Details" → "Edit" to update them.',
                    style: TextStyle(
                      height: 1.5,
                      fontSize: 13,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _confirmResetProfileData,
                icon: const Icon(Icons.restore),
                label: const Text('Reset Profile Data'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.errorRed,
                  side: const BorderSide(color: AppTheme.errorRed),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePictureSection() {
    final authProvider = context.watch<AuthProvider>();
    final profileProvider = context.watch<ProfileProvider>();
    final user = authProvider;
    final profile = profileProvider.currentProfile;

    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _isUploadingImage
                ? null
                : () => _pickImage(ImageSource.gallery),
            child: Stack(
              children: [
                AppAnimations.scaleIn(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.primaryGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryGreen.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.transparent,
                      backgroundImage: _selectedImage != null
                          ? FileImage(_selectedImage!)
                          : (profile?.avatarUrl != null &&
                                  profile!.avatarUrl!.isNotEmpty)
                              ? CachedNetworkImageProvider(profile.avatarUrl!)
                              : null,
                      child: _selectedImage == null &&
                              (profile?.avatarUrl == null ||
                                  profile!.avatarUrl!.isEmpty)
                          ? Text(
                              _getInitialLetter(
                                  profile?.fullName ?? user.userName ?? 'U'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 60,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
                if (_isUploadingImage)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.5),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(
                      _isUploadingImage
                          ? Icons.hourglass_empty
                          : Icons.photo_library,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _isUploadingImage ? 'Uploading...' : 'Tap to choose from gallery',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType? keyboardType,
    int maxLines = 1,
    String? hintText,
    bool enabled = true,
    EdgeInsetsGeometry? outerPadding,
    List<TextInputFormatter>? inputFormatters,
    bool alwaysShowLabel = false,
  }) {
    return Padding(
      padding: outerPadding ??
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        enabled: enabled,
        inputFormatters: inputFormatters,
        style: const TextStyle(
          fontWeight: FontWeight.normal,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          floatingLabelBehavior: alwaysShowLabel
              ? FloatingLabelBehavior.always
              : FloatingLabelBehavior.auto,
          prefixIcon: Icon(icon, color: AppTheme.primaryGreen),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: AppTheme.primaryGreen, width: 2),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField(
    String label,
    String? value,
    List<String> options,
    IconData icon,
    ValueChanged<String?> onChanged, {
    String? hint,
    EdgeInsetsGeometry? outerPadding,
  }) {
    return Padding(
      padding: outerPadding ??
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        style: const TextStyle(
          fontWeight: FontWeight.normal,
          color: Colors.black,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: AppTheme.primaryGreen),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: AppTheme.primaryGreen, width: 2),
          ),
        ),
        items: options.map((option) {
          return DropdownMenuItem(
            value: option,
            child: Text(
              option,
              style: const TextStyle(fontWeight: FontWeight.normal),
            ),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 400,
        maxHeight: 400,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _isUploadingImage = true;
        });

        if (!mounted) return;
        final authProvider = context.read<AuthProvider>();
        final profileProvider = context.read<ProfileProvider>();

        if (authProvider.userId != null) {
          final success = await profileProvider.uploadProfilePicture(
            authProvider.userId!,
            _selectedImage!,
          );

          if (success != null && mounted) {
            setState(() {
              _selectedImage = null;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profile picture updated successfully!'),
                backgroundColor: AppTheme.primaryGreen,
              ),
            );
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text(profileProvider.error ?? 'Failed to upload image'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }

        setState(() {
          _isUploadingImage = false;
        });
      }
    } catch (e) {
      setState(() {
        _isUploadingImage = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final profileProvider = context.read<ProfileProvider>();
      final authProvider = context.read<AuthProvider>();

      if (authProvider.userId == null) {
        throw Exception('User not authenticated');
      }

      final usernameErr = validateUsernameField(_usernameController.text);
      if (usernameErr != null) {
        throw Exception(usernameErr);
      }
      final normalizedUsername = normalizeUsername(_usernameController.text);

      final profileSuccess = await profileProvider.updateProfile(
        username: normalizedUsername,
        fullName: _fullNameController.text.trim().isEmpty
            ? null
            : _fullNameController.text.trim(),
        bio: _bioController.text.trim().isEmpty
            ? null
            : _bioController.text.trim(),
        location: (_selectedCounty ?? _locationController.text.trim()).isEmpty
            ? null
            : (_selectedCounty ?? _locationController.text.trim()),
        farmType: _selectedFarmType,
        experienceLevel: _selectedExperienceLevel,
        avatarUrl: profileProvider.currentProfile?.avatarUrl,
      );

      if (!profileSuccess) {
        throw Exception(profileProvider.error ?? 'Failed to update profile');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.errorRed,
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

  void _confirmResetProfileData() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Reset Profile Data',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'This will clear your bio, location, farm info, farming practices, crops and livestock. Your username and full name will be kept. Continue?',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _resetProfileData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text(
              'Reset',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resetProfileData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final profileProvider = context.read<ProfileProvider>();

      if (authProvider.userId == null) {
        throw Exception('User not authenticated');
      }

      await profileProvider.updateProfile(
        username: normalizeUsername(_usernameController.text),
        fullName: _fullNameController.text.trim().isEmpty
            ? null
            : _fullNameController.text.trim(),
        bio: null,
        location: null,
        farmType: null,
        experienceLevel: null,
        avatarUrl: profileProvider.currentProfile?.avatarUrl,
      );

      _bioController.clear();
      _locationController.clear();
      _selectedCounty = null;
      _selectedFarmType = null;
      _selectedExperienceLevel = null;

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile data reset successfully'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.errorRed,
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
}
