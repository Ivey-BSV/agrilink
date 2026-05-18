import 'package:flutter/material.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/features/profile/presentation/pages/user_profile_page.dart';
import 'package:cap/shared/utils/farm_display_formatters.dart';
import 'package:cap/providers/auth_provider.dart';
import 'package:cap/providers/farm_details_provider.dart';
import 'package:cap/providers/profile_provider.dart';
import 'package:cap/shared/models/farm_details.dart';
import 'package:cap/shared/models/user_profile.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

class FarmDirectoryPage extends StatefulWidget {
  final bool hideAppBar;
  final Function(VoidCallback)? onFilterCallbackReady;
  final Function(int)? onFilterCountChanged;

  const FarmDirectoryPage(
      {super.key,
      this.hideAppBar = false,
      this.onFilterCallbackReady,
      this.onFilterCountChanged});

  @override
  State<FarmDirectoryPage> createState() => _FarmDirectoryPageState();
}

class _FarmDirectoryPageState extends State<FarmDirectoryPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<String> _selectedFarmTypes = [];
  String? _selectedFarmScale;
  List<String> _selectedActivities = [];
  List<String> _selectedSpecializations = [];
  List<String> _selectedFarmGoals = [];
  String? _selectedFarmingMethod;
  String? _selectedCertification;

  List<Map<String, dynamic>> _farms = [];
  bool _isLoading = false;

  final List<String> _farmTypes = [
    'cash_crops',
    'specialty_crops',
    'livestock',
    'mixed',
    'homestead',
  ];
  final List<String> _farmScales = [
    'small-scale',
    'mid-scale',
    'family-scale',
    'homestead',
    'land-trust',
  ];
  final List<String> _activities = [
    'agritourism',
    'education',
    'workshops',
    'research',
    'farm_tours',
    'youth_programs',
  ];
  final List<String> _specializations = [
    'wetland_restoration',
    'pollinator_habitats',
    'value_added',
    'heritage_varietals',
    'biodiversity_enhancement',
    'soil_regeneration',
    'rotational_grazing',
    'agroforestry',
  ];
  final List<String> _farmGoals = [
    'economic_resilience',
    'succession_planning',
    'community_engagement',
    'environmental_legacy',
    'local_food_sovereignty',
    'peer_collaboration',
  ];
  final List<String> _farmingMethods = [
    'conventional',
    'organic',
    'permaculture',
    'biodynamic',
    'regenerative',
    'sustainable',
  ];

  int _getFilterCount() {
    return _selectedFarmTypes.length +
        (_selectedFarmScale != null ? 1 : 0) +
        _selectedActivities.length +
        _selectedSpecializations.length +
        _selectedFarmGoals.length +
        (_selectedFarmingMethod != null ? 1 : 0) +
        (_selectedCertification != null ? 1 : 0);
  }

  void _notifyFilterCountChanged() {
    widget.onFilterCountChanged?.call(_getFilterCount());
  }

  @override
  void initState() {
    super.initState();
    _loadFarms();

    if (widget.onFilterCallbackReady != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onFilterCallbackReady?.call(showFilters);
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyFilterCountChanged();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFarms() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final farmProvider = context.read<FarmDetailsProvider>();
      final profileProvider = context.read<ProfileProvider>();
      final authProvider = context.read<AuthProvider>();
      final currentUserId = authProvider.userId;

      final hasFarmFilters = _selectedFarmTypes.isNotEmpty ||
          _selectedFarmScale != null ||
          _selectedActivities.isNotEmpty ||
          _selectedSpecializations.isNotEmpty ||
          _selectedFarmGoals.isNotEmpty ||
          _selectedFarmingMethod != null ||
          _selectedCertification != null;

      List<Map<String, dynamic>> farmsWithProfiles = [];

      if (hasFarmFilters) {
        final farms = await farmProvider.searchFarms(
          farmType: _selectedFarmTypes.isEmpty ? null : _selectedFarmTypes,
          farmScale: _selectedFarmScale,
          activities: _selectedActivities.isEmpty ? null : _selectedActivities,
          specializations: _selectedSpecializations.isEmpty
              ? null
              : _selectedSpecializations,
          farmGoals: _selectedFarmGoals.isEmpty ? null : _selectedFarmGoals,
          farmingMethod: _selectedFarmingMethod,
          certification: _selectedCertification,
          limit: 100,
        );

        if (!mounted) return;

        for (final farm in farms) {
          if (!mounted) return;
          try {
            final profile = currentUserId != null
                ? await profileProvider.loadUserProfileById(
                    farm.userId, currentUserId)
                : await profileProvider.loadUserProfileById(
                    farm.userId, farm.userId);
            if (profile != null) {
              farmsWithProfiles.add({
                'farm': farm,
                'profile': profile,
              });
            }
          } catch (e) { /* ignored */ }
        }
      } else {
        final allProfiles = await profileProvider.searchProfiles(limit: 100);

        if (!mounted) return;

        for (final profile in allProfiles) {
          if (!mounted) return;
          try {
            FarmDetails? farm;
            try {
              await farmProvider.loadFarmDetails(profile.id);
              farm = farmProvider.currentFarmDetails;
            } catch (e) {
              farm = null;
            }

            farmsWithProfiles.add({
              'farm': farm,
              'profile': profile,
            });
          } catch (e) { /* ignored */ }
        }
      }

      if (!mounted) return;

      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        farmsWithProfiles.retainWhere((item) {
          final farm = item['farm'] as FarmDetails?;
          final profile = item['profile'] as UserProfile;
          return (farm?.farmName?.toLowerCase().contains(query) ?? false) ||
              (profile.fullName?.toLowerCase().contains(query) ?? false) ||
              (profile.location?.toLowerCase().contains(query) ?? false) ||
              (farm?.crops?.any((crop) => crop.toLowerCase().contains(query)) ??
                  false);
        });
      }

      farmsWithProfiles.sort((a, b) {
        final profileA = a['profile'] as UserProfile;
        final profileB = b['profile'] as UserProfile;
        final dateA = profileA.createdAt;
        final dateB = profileB.createdAt;

        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;

        return dateA.compareTo(dateB);
      });

      if (!mounted) return;
      setState(() {
        _farms = farmsWithProfiles;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading farms: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildBody();

    if (widget.hideAppBar) {
      return body;
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Farm Directory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: showFilters,
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Colors.grey[200]!, width: 1),
            ),
          ),
          child: SizedBox(
            height: 32,
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Search farms by name, location, or crops...',
                hintStyle: const TextStyle(fontSize: 12),
                prefixIcon: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 7),
                  child: Icon(Icons.search, size: 16),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 24,
                  minHeight: 16,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _searchController.clear();
                          });
                          _loadFarms();
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.all(7),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primaryGreen),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
                _loadFarms();
              },
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadFarms,
            child: _isLoading
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.5,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                    ],
                  )
                : _farms.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.5,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.agriculture,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No farms found',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Try adjusting your filters',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: _farms.length,
                        itemBuilder: (context, index) {
                          final item = _farms[index];
                          final farm = item['farm'] as FarmDetails?;
                          final profile = item['profile'] as UserProfile;
                          return _buildFarmCard(farm, profile);
                        },
                      ),
          ),
        ),
      ],
    );
  }

  Widget _buildFarmCard(FarmDetails? farm, UserProfile profile) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserProfilePage(userId: profile.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.primaryGradient,
                    ),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.transparent,
                      backgroundImage: profile.avatarUrl != null &&
                              profile.avatarUrl!.isNotEmpty
                          ? CachedNetworkImageProvider(profile.avatarUrl!)
                          : null,
                      child: (profile.avatarUrl == null ||
                              profile.avatarUrl!.isEmpty)
                          ? Text(
                              (profile.fullName?.isNotEmpty ?? false)
                                  ? profile.fullName![0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.fullName ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (profile.displayUsername != null &&
                                profile.displayUsername!.isNotEmpty) ...[
                              Text(
                                '@${profile.displayUsername}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                            if (profile.location != null) ...[
                              if (profile.displayUsername != null &&
                                  profile.displayUsername!.isNotEmpty)
                                Text(
                                  ' • ',
                                  style: TextStyle(color: Colors.grey[400]),
                                ),
                              Text(
                                profile.location!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (farm?.farmName != null ||
                  farm?.farmSize != null ||
                  farm?.establishedDate != null ||
                  farm?.farmingMethod != null ||
                  profile.farmType != null ||
                  profile.experienceLevel != null ||
                  farm?.certification != null ||
                  farm?.farmScale != null ||
                  (farm?.crops != null && farm!.crops!.isNotEmpty) ||
                  (farm?.livestock != null && farm!.livestock!.isNotEmpty) ||
                  (farm?.farmType != null && farm!.farmType!.isNotEmpty) ||
                  (farm?.activities != null && farm!.activities!.isNotEmpty))
                const SizedBox(height: 12),
              if (farm?.farmName != null) ...[
                Text(
                  farm!.farmName!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
              ],
              if (farm?.farmSize != null ||
                  farm?.establishedDate != null ||
                  farm?.farmingMethod != null) ...[
                Row(
                  children: [
                    if (farm?.farmSize != null) ...[
                      Text(
                        '${farm!.farmSize} ${farm.farmSizeUnit ?? 'acres'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    if (farm?.establishedDate != null) ...[
                      if (farm?.farmSize != null)
                        Text(
                          ' • ',
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                      Text(
                        formatFarmEstablishedDate(farm!.establishedDate!),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    if (farm?.farmingMethod != null) ...[
                      if (farm?.farmSize != null ||
                          farm?.establishedDate != null)
                        Text(
                          ' • ',
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                      Expanded(
                        child: Text(
                          formatFarmDisplayLabel(farm!.farmingMethod!),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
              ],
              if (profile.farmType != null ||
                  profile.experienceLevel != null) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (profile.farmType != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          formatFarmDisplayLabel(profile.farmType!),
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.primaryGreen,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    if (profile.experienceLevel != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          formatFarmDisplayLabel(profile.experienceLevel!),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              if (farm?.certification != null || farm?.farmScale != null) ...[
                Row(
                  children: [
                    if (farm?.certification != null) ...[
                      Icon(Icons.verified, size: 14, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        formatFarmDisplayLabel(farm!.certification!),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                    if (farm?.farmScale != null) ...[
                      if (farm?.certification != null)
                        Text(
                          ' • ',
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                      Text(
                        formatFarmDisplayLabel(farm!.farmScale!),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
              ],
              if (farm?.crops != null && farm!.crops!.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.eco, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        farm.crops!
                            .map((crop) => formatFarmDisplayLabel(crop))
                            .join(', '),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (farm?.livestock != null && farm!.livestock!.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.pets, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        farm.livestock!
                            .map((animal) => formatFarmDisplayLabel(animal))
                            .join(', '),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (farm?.farmType != null && farm!.farmType!.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.agriculture, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        farm.farmType!
                            .map((type) => formatFarmDisplayLabel(type))
                            .join(', '),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (farm?.activities != null && farm!.activities!.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.event, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        farm.activities!
                            .map((activity) => formatFarmDisplayLabel(activity))
                            .join(', '),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.9,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter Farms',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedFarmTypes.clear();
                            _selectedFarmScale = null;
                            _selectedActivities.clear();
                            _selectedSpecializations.clear();
                            _selectedFarmGoals.clear();
                            _selectedFarmingMethod = null;
                            _selectedCertification = null;
                          });
                          _loadFarms();
                          _notifyFilterCountChanged();
                          setLocalState(() {});
                        },
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final totalSelected = _selectedFarmTypes.length +
                          (_selectedFarmScale != null ? 1 : 0) +
                          _selectedActivities.length +
                          _selectedSpecializations.length +
                          _selectedFarmGoals.length +
                          (_selectedFarmingMethod != null ? 1 : 0) +
                          (_selectedCertification != null ? 1 : 0);
                      return Text(
                        '$totalSelected selected',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFilterSection(
                              'Farm Type', _farmTypes, _selectedFarmTypes,
                              (selected) {
                            setState(() {
                              _selectedFarmTypes = selected;
                            });
                            _loadFarms();
                            _notifyFilterCountChanged();
                            setLocalState(() {});
                          }),
                          const SizedBox(height: 20),
                          _buildFilterSection(
                              'Farm Scale',
                              _farmScales,
                              _selectedFarmScale != null
                                  ? [_selectedFarmScale!]
                                  : [], (selected) {
                            setState(() {
                              _selectedFarmScale =
                                  selected.isEmpty ? null : selected.first;
                            });
                            _loadFarms();
                            _notifyFilterCountChanged();
                            setLocalState(() {});
                          }, isSingleSelect: true),
                          const SizedBox(height: 20),
                          _buildFilterSection(
                              'Activities', _activities, _selectedActivities,
                              (selected) {
                            setState(() {
                              _selectedActivities = selected;
                            });
                            _loadFarms();
                            _notifyFilterCountChanged();
                            setLocalState(() {});
                          }),
                          const SizedBox(height: 20),
                          _buildFilterSection(
                              'Specializations',
                              _specializations,
                              _selectedSpecializations, (selected) {
                            setState(() {
                              _selectedSpecializations = selected;
                            });
                            _loadFarms();
                            _notifyFilterCountChanged();
                            setLocalState(() {});
                          }),
                          const SizedBox(height: 20),
                          _buildFilterSection(
                              'Farm Goals', _farmGoals, _selectedFarmGoals,
                              (selected) {
                            setState(() {
                              _selectedFarmGoals = selected;
                            });
                            _loadFarms();
                            _notifyFilterCountChanged();
                            setLocalState(() {});
                          }),
                          const SizedBox(height: 20),
                          _buildFilterSection(
                              'Farming Method',
                              _farmingMethods,
                              _selectedFarmingMethod != null
                                  ? [_selectedFarmingMethod!]
                                  : [], (selected) {
                            setState(() {
                              _selectedFarmingMethod =
                                  selected.isEmpty ? null : selected.first;
                            });
                            _loadFarms();
                            _notifyFilterCountChanged();
                            setLocalState(() {});
                          }, isSingleSelect: true),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterSection(String title, List<String> options,
      List<String> selected, Function(List<String>) onChanged,
      {bool isSingleSelect = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = selected.contains(option);
            return FilterChip(
              label: Text(formatFarmDisplayLabel(option)),
              selected: isSelected,
              onSelected: (selectedValue) {
                if (isSingleSelect) {
                  onChanged(selectedValue ? [option] : []);
                } else {
                  final newSelected = List<String>.from(selected);
                  if (selectedValue) {
                    newSelected.add(option);
                  } else {
                    newSelected.remove(option);
                  }
                  onChanged(newSelected);
                }
              },
              selectedColor: AppTheme.primaryGreen.withValues(alpha: 0.2),
              checkmarkColor: AppTheme.primaryGreen,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: const VisualDensity(
                horizontal: -2,
                vertical: -2,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
