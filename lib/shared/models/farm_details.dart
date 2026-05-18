class FarmDetails {
  final String id;
  final String userId;
  final String? farmOverview;
  final String? farmName;
  final int? farmSize;
  final String? farmSizeUnit;
  final List<String>? crops;
  final List<String>? livestock;
  final String? soilType;
  final String? irrigationMethod;
  final String? farmingMethod;
  final String? certification;
  final DateTime? establishedDate;
  final List<String>? farmType;
  final String? farmScale;
  final List<String>? activities;
  final List<String>? specializations;
  final List<String>? farmGoals;
  final List<String>? valueAddedProducts;
  final bool? isOpenFarm;
  final List<String>? agritourismOfferings;
  final String? farmAccessibility;
  final String? visitorGuidelines;
  final String? highwayExit;
  final String? highwayDirections;
  final String? signageInfo;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  FarmDetails({
    required this.id,
    required this.userId,
    this.farmOverview,
    this.farmName,
    this.farmSize,
    this.farmSizeUnit,
    this.crops,
    this.livestock,
    this.soilType,
    this.irrigationMethod,
    this.farmingMethod,
    this.certification,
    this.establishedDate,
    this.farmType,
    this.farmScale,
    this.activities,
    this.specializations,
    this.farmGoals,
    this.valueAddedProducts,
    this.isOpenFarm,
    this.agritourismOfferings,
    this.farmAccessibility,
    this.visitorGuidelines,
    this.highwayExit,
    this.highwayDirections,
    this.signageInfo,
    this.createdAt,
    this.updatedAt,
  });

  factory FarmDetails.fromJson(Map<String, dynamic> json) {
    return FarmDetails(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      farmOverview: json['farm_overview'] as String?,
      farmName: json['farm_name'] as String?,
      farmSize:
          json['farm_size'] != null ? (json['farm_size'] as num).toInt() : null,
      farmSizeUnit: json['farm_size_unit'] as String?,
      crops: json['crops'] != null
          ? List<String>.from(json['crops'] as List)
          : null,
      livestock: json['livestock'] != null
          ? List<String>.from(json['livestock'] as List)
          : null,
      soilType: json['soil_type'] as String?,
      irrigationMethod: json['irrigation_method'] as String?,
      farmingMethod: json['farming_method'] as String?,
      certification: json['certification'] as String?,
      establishedDate: json['established_date'] != null
          ? DateTime.parse(json['established_date'] as String)
          : null,
      farmType: json['farm_type'] != null
          ? List<String>.from(json['farm_type'] as List)
          : null,
      farmScale: json['farm_scale'] as String?,
      activities: json['activities'] != null
          ? List<String>.from(json['activities'] as List)
          : null,
      specializations: json['specializations'] != null
          ? List<String>.from(json['specializations'] as List)
          : null,
      farmGoals: json['farm_goals'] != null
          ? List<String>.from(json['farm_goals'] as List)
          : null,
      valueAddedProducts: json['value_added_products'] != null
          ? List<String>.from(json['value_added_products'] as List)
          : null,
      isOpenFarm: json['is_open_farm'] as bool?,
      agritourismOfferings: json['agritourism_offerings'] != null
          ? List<String>.from(json['agritourism_offerings'] as List)
          : null,
      farmAccessibility: json['farm_accessibility'] as String?,
      visitorGuidelines: json['visitor_guidelines'] as String?,
      highwayExit: json['highway_exit'] as String?,
      highwayDirections: json['highway_directions'] as String?,
      signageInfo: json['signage_info'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'farm_overview': farmOverview,
      'farm_name': farmName,
      'farm_size': farmSize,
      'farm_size_unit': farmSizeUnit,
      'crops': crops,
      'livestock': livestock,
      'soil_type': soilType,
      'irrigation_method': irrigationMethod,
      'farming_method': farmingMethod,
      'certification': certification,
      'established_date': establishedDate?.toUtc().toIso8601String(),
      'farm_type': farmType,
      'farm_scale': farmScale,
      'activities': activities,
      'specializations': specializations,
      'farm_goals': farmGoals,
      'value_added_products': valueAddedProducts,
      'is_open_farm': isOpenFarm,
      'agritourism_offerings': agritourismOfferings,
      'farm_accessibility': farmAccessibility,
      'visitor_guidelines': visitorGuidelines,
      'highway_exit': highwayExit,
      'highway_directions': highwayDirections,
      'signage_info': signageInfo,
      'created_at': createdAt?.toUtc().toIso8601String(),
      'updated_at': updatedAt?.toUtc().toIso8601String(),
    };
  }

  FarmDetails copyWith({
    String? id,
    String? userId,
    String? farmOverview,
    String? farmName,
    int? farmSize,
    String? farmSizeUnit,
    List<String>? crops,
    List<String>? livestock,
    String? soilType,
    String? irrigationMethod,
    String? farmingMethod,
    String? certification,
    DateTime? establishedDate,
    List<String>? farmType,
    String? farmScale,
    List<String>? activities,
    List<String>? specializations,
    List<String>? farmGoals,
    List<String>? valueAddedProducts,
    bool? isOpenFarm,
    List<String>? agritourismOfferings,
    String? farmAccessibility,
    String? visitorGuidelines,
    String? highwayExit,
    String? highwayDirections,
    String? signageInfo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FarmDetails(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      farmOverview: farmOverview ?? this.farmOverview,
      farmName: farmName ?? this.farmName,
      farmSize: farmSize ?? this.farmSize,
      farmSizeUnit: farmSizeUnit ?? this.farmSizeUnit,
      crops: crops ?? this.crops,
      livestock: livestock ?? this.livestock,
      soilType: soilType ?? this.soilType,
      irrigationMethod: irrigationMethod ?? this.irrigationMethod,
      farmingMethod: farmingMethod ?? this.farmingMethod,
      certification: certification ?? this.certification,
      establishedDate: establishedDate ?? this.establishedDate,
      farmType: farmType ?? this.farmType,
      farmScale: farmScale ?? this.farmScale,
      activities: activities ?? this.activities,
      specializations: specializations ?? this.specializations,
      farmGoals: farmGoals ?? this.farmGoals,
      valueAddedProducts: valueAddedProducts ?? this.valueAddedProducts,
      isOpenFarm: isOpenFarm ?? this.isOpenFarm,
      agritourismOfferings: agritourismOfferings ?? this.agritourismOfferings,
      farmAccessibility: farmAccessibility ?? this.farmAccessibility,
      visitorGuidelines: visitorGuidelines ?? this.visitorGuidelines,
      highwayExit: highwayExit ?? this.highwayExit,
      highwayDirections: highwayDirections ?? this.highwayDirections,
      signageInfo: signageInfo ?? this.signageInfo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'FarmDetails(id: $id, userId: $userId, farmName: $farmName, farmSize: $farmSize $farmSizeUnit)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FarmDetails &&
        other.id == id &&
        other.userId == userId &&
        other.farmName == farmName &&
        other.farmSize == farmSize &&
        other.farmSizeUnit == farmSizeUnit &&
        other.soilType == soilType &&
        other.irrigationMethod == irrigationMethod &&
        other.farmingMethod == farmingMethod &&
        other.certification == certification;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      userId,
      farmName,
      farmSize,
      farmSizeUnit,
      soilType,
      irrigationMethod,
      farmingMethod,
      certification,
    );
  }
}
