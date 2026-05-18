import 'package:flutter/material.dart';
import 'package:cap/core/animations/app_animations.dart';
import 'package:cap/shared/utils/farm_display_formatters.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/providers/auth_provider.dart';
import 'package:cap/providers/farm_details_provider.dart';
import 'package:cap/shared/models/farm_details.dart';
import 'package:provider/provider.dart';

class FarmDetailsPage extends StatefulWidget {
  const FarmDetailsPage({super.key});

  @override
  State<FarmDetailsPage> createState() => _FarmDetailsPageState();
}

class _FarmDetailsPageState extends State<FarmDetailsPage> {
  final TextEditingController _farmOverviewController = TextEditingController();
  final TextEditingController _farmNameController = TextEditingController();
  final TextEditingController _farmSizeController = TextEditingController();
  final TextEditingController _visitorGuidelinesController =
      TextEditingController();
  final TextEditingController _farmAccessibilityController =
      TextEditingController();
  final TextEditingController _highwayExitController = TextEditingController();
  final TextEditingController _highwayDirectionsController =
      TextEditingController();
  final TextEditingController _signageInfoController = TextEditingController();

  String _selectedFarmSizeUnit = 'acres';
  String? _selectedFarmingMethod;
  String? _selectedSoilType;
  String? _selectedIrrigationMethod;
  String? _selectedCertification;
  String? _selectedFarmScale;
  DateTime? _selectedEstablishedDate;
  List<String> _selectedCrops = [];
  List<String> _selectedLivestock = [];
  List<String> _selectedFarmTypes = [];
  List<String> _selectedActivities = [];
  List<String> _selectedSpecializations = [];
  List<String> _selectedFarmGoals = [];
  List<String> _selectedValueAddedProducts = [];
  List<String> _selectedAgritourismOfferings = [];
  bool _isOpenFarm = false;

  bool _isLoading = false;

  final List<String> _farmSizeUnits = ['acres', 'hectares'];
  final List<String> _farmingMethods = [
    'conventional',
    'organic',
    'permaculture',
    'biodynamic',
    'regenerative',
    'sustainable',
  ];
  final List<String> _soilTypes = [
    'clay',
    'sandy',
    'loam',
    'silt',
    'clay_loam',
    'sandy_loam',
    'silt_loam',
    'peat',
    'chalk',
    'other',
  ];
  final List<String> _irrigationMethods = [
    'drip_irrigation',
    'sprinkler',
    'flood',
    'furrow',
    'center_pivot',
    'hand_watering',
    'rainfed',
    'subsurface',
    'other',
  ];
  final List<String> _certifications = [
    'organic',
    'usda_organic',
    'fair_trade',
    'rainforest_alliance',
    'biodynamic',
    'regenerative_organic',
    'non_gmo',
    'animal_welfare_approved',
    'other',
  ];
  final List<String> _farmScales = [
    'small-scale',
    'mid-scale',
    'family-scale',
    'homestead',
    'land-trust',
  ];
  final List<String> _farmTypes = [
    'cash_crops',
    'specialty_crops',
    'livestock',
    'mixed',
    'homestead',
  ];
  final List<String> _activities = [
    'agritourism',
    'education',
    'workshops',
    'research',
    'farm_tours',
    'youth_programs',
    'open_farm',
    'farm_day',
    'potluck_events',
  ];

  final List<String> _agritourismOfferings = [
    'farm_tours',
    'u_pick',
    'farm_store',
    'events',
    'workshops',
    'farm_stay',
    'educational_programs',
    'seasonal_activities',
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
  final List<String> _valueAddedProducts = [
    'culinary_oils',
    'artisanal_products',
    'cut_flowers',
    'heritage_varietals',
    'retail_ready',
    'wholesale_ready',
    'preserved_foods',
    'specialty_items',
  ];

  final List<String> _availableCrops = [
    'corn',
    'soybeans',
    'wheat',
    'barley',
    'oats',
    'rice',
    'cotton',
    'potatoes',
    'tomatoes',
    'lettuce',
    'carrots',
    'onions',
    'apples',
    'oranges',
    'grapes',
    'strawberries',
    'blueberries',
    'lavender',
    'cut flowers',
    'heritage varietals',
    'peas',
    'vegetables',
    'herbs',
    'microgreens',
  ];

  final List<String> _availableLivestock = [
    'cattle',
    'pigs',
    'sheep',
    'goats',
    'chickens',
    'ducks',
    'turkeys',
    'horses',
    'donkeys',
    'rabbits',
    'fish',
    'bees',
  ];

  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFarmDetails();
    });
  }

  void _updateFromFarmDetails(FarmDetails? farmDetails) {
    if (farmDetails == null) return;

    setState(() {
      _farmOverviewController.text = farmDetails.farmOverview ?? '';
      _farmNameController.text = farmDetails.farmName ?? '';
      _farmSizeController.text = farmDetails.farmSize?.toString() ?? '';
      _selectedFarmSizeUnit = farmDetails.farmSizeUnit ?? 'acres';

      final farmingMethod = farmDetails.farmingMethod?.toLowerCase();
      _selectedFarmingMethod =
          _farmingMethods.contains(farmingMethod) ? farmingMethod : null;

      final soilType = farmDetails.soilType?.toLowerCase();
      _selectedSoilType = _soilTypes.contains(soilType) ? soilType : null;
      final irrigationMethod = farmDetails.irrigationMethod?.toLowerCase();
      _selectedIrrigationMethod = _irrigationMethods.contains(irrigationMethod)
          ? irrigationMethod
          : null;
      final certification = farmDetails.certification?.toLowerCase();
      _selectedCertification =
          _certifications.contains(certification) ? certification : null;
      _selectedFarmScale = farmDetails.farmScale;
      _selectedEstablishedDate = farmDetails.establishedDate;
      _selectedCrops = List<String>.from(farmDetails.crops ?? []);
      _selectedLivestock = List<String>.from(farmDetails.livestock ?? []);
      _selectedFarmTypes = List<String>.from(farmDetails.farmType ?? []);
      _selectedActivities = List<String>.from(farmDetails.activities ?? []);
      _selectedSpecializations =
          List<String>.from(farmDetails.specializations ?? []);
      _selectedFarmGoals = List<String>.from(farmDetails.farmGoals ?? []);
      _selectedValueAddedProducts =
          List<String>.from(farmDetails.valueAddedProducts ?? []);
      _isOpenFarm = farmDetails.isOpenFarm ?? false;
      _selectedAgritourismOfferings =
          List<String>.from(farmDetails.agritourismOfferings ?? []);
      _visitorGuidelinesController.text = farmDetails.visitorGuidelines ?? '';
      _farmAccessibilityController.text = farmDetails.farmAccessibility ?? '';
      _highwayExitController.text = farmDetails.highwayExit ?? '';
      _highwayDirectionsController.text = farmDetails.highwayDirections ?? '';
      _signageInfoController.text = farmDetails.signageInfo ?? '';
      _isInitialized = true;
    });
  }

  Future<void> _loadFarmDetails() async {
    final authProvider = context.read<AuthProvider>();
    final farmDetailsProvider = context.read<FarmDetailsProvider>();

    if (authProvider.userId != null) {
      await farmDetailsProvider.loadFarmDetails(authProvider.userId!);
    }

    final farmDetails = farmDetailsProvider.currentFarmDetails;
    if (farmDetails != null) {
      _updateFromFarmDetails(farmDetails);
    } else {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _farmOverviewController.dispose();
    _farmNameController.dispose();
    _farmSizeController.dispose();
    _visitorGuidelinesController.dispose();
    _farmAccessibilityController.dispose();
    _highwayExitController.dispose();
    _highwayDirectionsController.dispose();
    _signageInfoController.dispose();
    super.dispose();
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
        title: const Text(
          'Farm Details',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: AppAnimations.scaleIn(
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveFarmDetails,
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
      body: !_isInitialized
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Basic Information'),
                  _buildSettingsCard([
                    _buildTextField(
                      'Farm overview',
                      _farmOverviewController,
                      Icons.notes_outlined,
                      maxLines: 8,
                      hintText:
                          'Region, land, story—anything that helps others understand your farm.',
                    ),
                    _buildTextField(
                        'Farm Name', _farmNameController, Icons.home),
                    Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(
                                left: 16, top: 8, bottom: 8, right: 0),
                            child: TextField(
                              controller: _farmSizeController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(
                                fontWeight: FontWeight.normal,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Farm Size',
                                hintText: '0.0',
                                prefixIcon: const Icon(Icons.straighten,
                                    color: AppTheme.primaryGreen),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: BorderSide(
                                      color: AppTheme.primaryGreen, width: 2),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(
                                left: 0, top: 8, bottom: 8, right: 16),
                            child: DropdownButtonFormField<String>(
                              value: _selectedFarmSizeUnit,
                              isExpanded: true,
                              style: const TextStyle(
                                fontWeight: FontWeight.normal,
                                color: Colors.black,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Unit',
                                prefixIcon: const Icon(Icons.straighten,
                                    color: AppTheme.primaryGreen),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: BorderSide(
                                      color: AppTheme.primaryGreen, width: 2),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 16),
                              ),
                              items: _farmSizeUnits.map((unit) {
                                return DropdownMenuItem(
                                  value: unit,
                                  child: Text(
                                    formatFarmDisplayLabel(unit),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) => setState(
                                  () => _selectedFarmSizeUnit = value!),
                            ),
                          ),
                        ),
                      ],
                    ),
                    _buildDateField(
                        'Established Date', _selectedEstablishedDate),
                  ]),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Farming Practices'),
                  _buildSettingsCard([
                    _buildDropdownField(
                      'Farming Method',
                      _selectedFarmingMethod ?? '',
                      ['', ..._farmingMethods],
                      Icons.eco,
                      (value) => setState(() => _selectedFarmingMethod =
                          value?.isEmpty ?? true ? null : value),
                    ),
                    _buildDropdownField(
                      'Soil Type',
                      _selectedSoilType ?? '',
                      ['', ..._soilTypes],
                      Icons.terrain,
                      (value) => setState(() => _selectedSoilType =
                          value?.isEmpty ?? true ? null : value),
                    ),
                    _buildDropdownField(
                      'Irrigation Method',
                      _selectedIrrigationMethod ?? '',
                      ['', ..._irrigationMethods],
                      Icons.water_drop,
                      (value) => setState(() => _selectedIrrigationMethod =
                          value?.isEmpty ?? true ? null : value),
                    ),
                    _buildDropdownField(
                      'Certification',
                      _selectedCertification ?? '',
                      ['', ..._certifications],
                      Icons.verified,
                      (value) => setState(() => _selectedCertification =
                          value?.isEmpty ?? true ? null : value),
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Crops'),
                  _buildSettingsCard([
                    _buildMultiSelectField(
                        'Crops', _selectedCrops, _availableCrops,
                        maxSelections: 10),
                  ]),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Livestock'),
                  _buildSettingsCard([
                    _buildMultiSelectField(
                        'Livestock', _selectedLivestock, _availableLivestock,
                        maxSelections: 8),
                  ]),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Farm Type & Scale'),
                  _buildSettingsCard([
                    _buildMultiSelectField(
                        'Farm Type', _selectedFarmTypes, _farmTypes,
                        maxSelections: 3),
                    _buildDropdownField(
                      'Farm Scale',
                      _selectedFarmScale ?? '',
                      ['', ..._farmScales],
                      Icons.scale,
                      (value) => setState(() => _selectedFarmScale =
                          value?.isEmpty ?? true ? null : value),
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Activities'),
                  _buildSettingsCard([
                    _buildMultiSelectField(
                        'Activities', _selectedActivities, _activities,
                        maxSelections: 5),
                  ]),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Specializations'),
                  _buildSettingsCard([
                    _buildMultiSelectField('Specializations',
                        _selectedSpecializations, _specializations,
                        maxSelections: 6),
                  ]),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Farm Goals'),
                  _buildSettingsCard([
                    _buildMultiSelectField(
                        'Farm Goals', _selectedFarmGoals, _farmGoals,
                        maxSelections: 5),
                  ]),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Value-Added Products'),
                  _buildSettingsCard([
                    _buildMultiSelectField('Value-Added Products',
                        _selectedValueAddedProducts, _valueAddedProducts,
                        maxSelections: 6),
                  ]),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Farm Accessibility & Agritourism'),
                  _buildSettingsCard([
                    _buildSwitchField('Open Farm', _isOpenFarm,
                        (value) => setState(() => _isOpenFarm = value)),
                    if (_isOpenFarm) ...[
                      _buildTextField('Visitor Guidelines',
                          _visitorGuidelinesController, Icons.info_outline,
                          maxLines: 3),
                      _buildTextField('Farm Accessibility Info',
                          _farmAccessibilityController, Icons.accessible,
                          maxLines: 2),
                      _buildMultiSelectField('Agritourism Offerings',
                          _selectedAgritourismOfferings, _agritourismOfferings,
                          maxSelections: 5),
                    ],
                  ]),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Farm Directions & Signage'),
                  _buildSettingsCard([
                    _buildTextField('Highway Exit', _highwayExitController,
                        Icons.exit_to_app),
                    _buildTextField('Highway Directions',
                        _highwayDirectionsController, Icons.directions,
                        maxLines: 3),
                    _buildTextField('Signage Information',
                        _signageInfoController, Icons.signpost,
                        maxLines: 2),
                  ]),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _showDeleteDialog,
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('Delete Farm Details'),
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
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
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(
          fontWeight: FontWeight.normal,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          prefixIcon: Icon(icon, color: AppTheme.primaryGreen),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: AppTheme.primaryGreen, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField(
    String label,
    String value,
    List<String> options,
    IconData icon,
    ValueChanged<String?> onChanged,
  ) {
    String? normalizedValue;
    if (value.isNotEmpty) {
      final lowerValue = value.toLowerCase();
      final matchingOption = options.firstWhere(
        (opt) => opt.toLowerCase() == lowerValue,
        orElse: () => '',
      );
      normalizedValue = matchingOption.isEmpty ? null : matchingOption;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DropdownButtonFormField<String>(
        value: normalizedValue,
        isExpanded: true,
        style: const TextStyle(
          fontWeight: FontWeight.normal,
          color: Colors.black,
        ),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppTheme.primaryGreen),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: AppTheme.primaryGreen, width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
        items: options.map((option) {
          if (option.isEmpty) {
            return DropdownMenuItem<String>(
              value: null,
              child: Text('None', style: TextStyle(color: Colors.grey[600])),
            );
          }
          return DropdownMenuItem(
            value: option,
            child: Text(
              formatFarmDisplayLabel(option),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildSwitchField(
      String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.normal),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            thumbColor: WidgetStateProperty.all(AppTheme.primaryGreen),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField(String label, DateTime? selectedDate) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: _selectDate,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon:
                Icon(Icons.calendar_today, color: AppTheme.primaryGreen),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: AppTheme.primaryGreen, width: 2),
            ),
          ),
          child: Text(
            selectedDate != null
                ? '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}'
                : 'Select date',
            style: TextStyle(
              color: selectedDate != null ? Colors.black : Colors.grey[600],
              fontWeight: FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMultiSelectField(
      String label, List<String> selectedItems, List<String> availableItems,
      {int? maxSelections}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (maxSelections != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${selectedItems.length}/$maxSelections selected',
                style: TextStyle(
                  fontSize: 12,
                  color: selectedItems.length >= maxSelections
                      ? Colors.orange[700]
                      : Colors.grey[600],
                  fontWeight: selectedItems.length >= maxSelections
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableItems.map((item) {
                final isSelected = selectedItems.contains(item);
                final canSelect = maxSelections == null ||
                    selectedItems.length < maxSelections ||
                    isSelected;
                return FilterChip(
                  label: Text(
                    formatFarmDisplayLabel(item),
                    style: const TextStyle(fontSize: 11),
                  ),
                  selected: isSelected,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: const VisualDensity(
                    horizontal: -2,
                    vertical: -2,
                  ),
                  onSelected: canSelect
                      ? (selected) {
                          if (selected &&
                              maxSelections != null &&
                              selectedItems.length >= maxSelections) {
                            return;
                          }
                          setState(() {
                            if (selected) {
                              if (!selectedItems.contains(item)) {
                                selectedItems.add(item);
                              }
                            } else {
                              selectedItems.remove(item);
                            }
                          });
                        }
                      : null,
                  selectedColor: AppTheme.primaryGreen.withOpacity(0.2),
                  checkmarkColor: AppTheme.primaryGreen,
                  disabledColor: Colors.grey[300],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedEstablishedDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedEstablishedDate) {
      setState(() {
        _selectedEstablishedDate = picked;
      });
    }
  }

  Future<void> _saveFarmDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final farmDetailsProvider = context.read<FarmDetailsProvider>();
      final authProvider = context.read<AuthProvider>();

      if (authProvider.userId == null) {
        throw Exception('User not authenticated');
      }

      final farmSize = _farmSizeController.text.trim().isNotEmpty
          ? double.tryParse(_farmSizeController.text.trim())
          : null;

      final success = await farmDetailsProvider.saveFarmDetails(
        userId: authProvider.userId!,
        farmOverview: _farmOverviewController.text.trim().isEmpty
            ? null
            : _farmOverviewController.text.trim(),
        farmName: _farmNameController.text.trim().isEmpty
            ? null
            : _farmNameController.text.trim(),
        farmSize: farmSize?.toInt(),
        farmSizeUnit: _selectedFarmSizeUnit,
        crops: _selectedCrops.isEmpty ? null : _selectedCrops,
        livestock: _selectedLivestock.isEmpty ? null : _selectedLivestock,
        soilType: _selectedSoilType,
        irrigationMethod: _selectedIrrigationMethod,
        farmingMethod: _selectedFarmingMethod,
        certification: _selectedCertification,
        establishedDate: _selectedEstablishedDate,
        farmType: _selectedFarmTypes.isEmpty ? null : _selectedFarmTypes,
        farmScale: _selectedFarmScale,
        activities: _selectedActivities.isEmpty ? null : _selectedActivities,
        specializations:
            _selectedSpecializations.isEmpty ? null : _selectedSpecializations,
        farmGoals: _selectedFarmGoals.isEmpty ? null : _selectedFarmGoals,
        valueAddedProducts: _selectedValueAddedProducts.isEmpty
            ? null
            : _selectedValueAddedProducts,
        isOpenFarm: _isOpenFarm,
        agritourismOfferings: _selectedAgritourismOfferings.isEmpty
            ? null
            : _selectedAgritourismOfferings,
        farmAccessibility: _farmAccessibilityController.text.trim().isEmpty
            ? null
            : _farmAccessibilityController.text.trim(),
        visitorGuidelines: _visitorGuidelinesController.text.trim().isEmpty
            ? null
            : _visitorGuidelinesController.text.trim(),
        highwayExit: _highwayExitController.text.trim().isEmpty
            ? null
            : _highwayExitController.text.trim(),
        highwayDirections: _highwayDirectionsController.text.trim().isEmpty
            ? null
            : _highwayDirectionsController.text.trim(),
        signageInfo: _signageInfoController.text.trim().isEmpty
            ? null
            : _signageInfoController.text.trim(),
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Farm details saved successfully!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        Navigator.pop(context);
      } else {
        throw Exception(
            farmDetailsProvider.error ?? 'Failed to save farm details');
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

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Farm Details'),
        content: const Text(
          'Are you sure you want to delete your farm details? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteFarmDetails();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteFarmDetails() async {
    final farmDetailsProvider = context.read<FarmDetailsProvider>();
    final authProvider = context.read<AuthProvider>();

    if (authProvider.userId != null) {
      final success =
          await farmDetailsProvider.deleteFarmDetails(authProvider.userId!);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Farm details deleted successfully!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        Navigator.pop(context);
      }
    }
  }
}
