class UserProfile {
  final String id;
  final String? username;
  final String? fullName;
  final String? bio;
  final String? location;
  final String? farmType;
  final String? experienceLevel;
  final String? avatarUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int followerCount;
  final int followingCount;
  final bool isFollowing;

  final String? accessTier;

  final String? registrationStatus;

  final String? accountKind;
  final String? appRole;
  final double? acreage;
  final String? cropTypes;
  final String? practiceStage;

  String? get displayUsername => username?.toLowerCase();

  UserProfile({
    required this.id,
    this.username,
    this.fullName,
    this.bio,
    this.location,
    this.farmType,
    this.experienceLevel,
    this.avatarUrl,
    this.createdAt,
    this.updatedAt,
    this.followerCount = 0,
    this.followingCount = 0,
    this.isFollowing = false,
    this.accessTier,
    this.registrationStatus,
    this.accountKind,
    this.appRole,
    this.acreage,
    this.cropTypes,
    this.practiceStage,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      username: json['username'] as String?,
      fullName: json['full_name'] as String?,
      bio: json['bio'] as String?,
      location: json['location'] as String?,
      farmType: json['farm_type'] as String?,
      experienceLevel: json['experience_level'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      followerCount: json['follower_count'] as int? ?? 0,
      followingCount: json['following_count'] as int? ?? 0,
      isFollowing: json['is_following'] as bool? ?? false,
      accessTier: json['access_tier'] as String?,
      registrationStatus: json['registration_status'] as String?,
      accountKind: json['account_kind'] as String?,
      appRole: json['app_role'] as String?,
      acreage: (json['acreage'] as num?)?.toDouble(),
      cropTypes: json['crop_types'] as String?,
      practiceStage: json['practice_stage'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'full_name': fullName,
      'bio': bio,
      'location': location,
      'farm_type': farmType,
      'experience_level': experienceLevel,
      'avatar_url': avatarUrl,
      'created_at': createdAt?.toUtc().toIso8601String(),
      'updated_at': updatedAt?.toUtc().toIso8601String(),
      'follower_count': followerCount,
      'following_count': followingCount,
      'is_following': isFollowing,
      'access_tier': accessTier,
      'registration_status': registrationStatus,
      'account_kind': accountKind,
      'app_role': appRole,
      'acreage': acreage,
      'crop_types': cropTypes,
      'practice_stage': practiceStage,
    };
  }

  UserProfile copyWith({
    String? id,
    String? username,
    String? fullName,
    String? bio,
    String? location,
    String? farmType,
    String? experienceLevel,
    String? avatarUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? followerCount,
    int? followingCount,
    bool? isFollowing,
    String? accessTier,
    String? registrationStatus,
    String? accountKind,
    String? appRole,
    double? acreage,
    String? cropTypes,
    String? practiceStage,
  }) {
    return UserProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      bio: bio ?? this.bio,
      location: location ?? this.location,
      farmType: farmType ?? this.farmType,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      followerCount: followerCount ?? this.followerCount,
      followingCount: followingCount ?? this.followingCount,
      isFollowing: isFollowing ?? this.isFollowing,
      accessTier: accessTier ?? this.accessTier,
      registrationStatus: registrationStatus ?? this.registrationStatus,
      accountKind: accountKind ?? this.accountKind,
      appRole: appRole ?? this.appRole,
      acreage: acreage ?? this.acreage,
      cropTypes: cropTypes ?? this.cropTypes,
      practiceStage: practiceStage ?? this.practiceStage,
    );
  }

  @override
  String toString() {
    return 'UserProfile(id: $id, username: $username, fullName: $fullName, bio: $bio, location: $location, farmType: $farmType, experienceLevel: $experienceLevel, avatarUrl: $avatarUrl, followerCount: $followerCount, followingCount: $followingCount, isFollowing: $isFollowing, accessTier: $accessTier, registrationStatus: $registrationStatus)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfile &&
        other.id == id &&
        other.username == username &&
        other.fullName == fullName &&
        other.bio == bio &&
        other.location == location &&
        other.farmType == farmType &&
        other.experienceLevel == experienceLevel &&
        other.avatarUrl == avatarUrl &&
        other.followerCount == followerCount &&
        other.followingCount == followingCount &&
        other.isFollowing == isFollowing &&
        other.accessTier == accessTier &&
        other.registrationStatus == registrationStatus;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      username,
      fullName,
      bio,
      location,
      farmType,
      experienceLevel,
      avatarUrl,
      followerCount,
      followingCount,
      isFollowing,
      accessTier,
      registrationStatus,
    );
  }
}
