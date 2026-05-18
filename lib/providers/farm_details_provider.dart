import 'package:flutter/material.dart';
import 'package:cap/shared/models/farm_details.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FarmDetailsProvider extends ChangeNotifier {
  FarmDetails? _currentFarmDetails;
  bool _isLoading = false;
  String? _error;
  String? _currentUserId;

  FarmDetails? get currentFarmDetails => _currentFarmDetails;
  bool get isLoading => _isLoading;
  String? get error => _error;

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> loadFarmDetails(String userId) async {
    _setLoading(true);
    _clearError();

    try {
      if (_currentUserId != null && _currentUserId != userId) {
        _currentFarmDetails = null;
        notifyListeners();
      }

      final response = await _supabase
          .from('farm_details')
          .select('*')
          .eq('user_id', userId)
          .single();

      _currentFarmDetails = FarmDetails.fromJson(response);
      _currentUserId = userId;
      notifyListeners();
    } catch (e) {
      if (e.toString().contains('No rows found') ||
          e.toString().contains('PGRST116')) {
        _currentFarmDetails = null;
        _currentUserId = userId;
        notifyListeners();
      } else {
        _setError('Failed to load farm details: ${e.toString()}');
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> saveFarmDetails({
    required String userId,
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
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final farmData = <String, dynamic>{
        'user_id': userId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      farmData['farm_overview'] = farmOverview;
      farmData['farm_name'] = farmName;
      farmData['farm_size'] = farmSize;
      farmData['farm_size_unit'] = farmSizeUnit;
      farmData['crops'] = crops;
      farmData['livestock'] = livestock;
      farmData['soil_type'] = soilType;
      farmData['irrigation_method'] = irrigationMethod;
      farmData['farming_method'] = farmingMethod;
      farmData['certification'] = certification;
      farmData['established_date'] = establishedDate?.toUtc().toIso8601String();
      farmData['farm_type'] = farmType;
      farmData['farm_scale'] = farmScale;
      farmData['activities'] = activities;
      farmData['specializations'] = specializations;
      farmData['farm_goals'] = farmGoals;
      farmData['value_added_products'] = valueAddedProducts;
      farmData['is_open_farm'] = isOpenFarm;
      farmData['agritourism_offerings'] = agritourismOfferings;
      farmData['farm_accessibility'] = farmAccessibility;
      farmData['visitor_guidelines'] = visitorGuidelines;
      farmData['highway_exit'] = highwayExit;
      farmData['highway_directions'] = highwayDirections;
      farmData['signage_info'] = signageInfo;

      final existing = await _supabase
          .from('farm_details')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        await _supabase
            .from('farm_details')
            .update(farmData)
            .eq('user_id', userId);
      } else {
        await _supabase.from('farm_details').insert(farmData);
      }

      await loadFarmDetails(userId);
      return true;
    } catch (e) {
      _setError('Failed to save farm details: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteFarmDetails(String userId) async {
    _setLoading(true);
    _clearError();

    try {
      await _supabase.from('farm_details').delete().eq('user_id', userId);

      _currentFarmDetails = null;
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to delete farm details: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<List<FarmDetails>> searchFarms({
    String? location,
    String? farmingMethod,
    String? certification,
    List<String>? crops,
    List<String>? farmType,
    String? farmScale,
    List<String>? activities,
    List<String>? specializations,
    List<String>? farmGoals,
    int limit = 20,
  }) async {
    try {
      var query = _supabase.from('farm_details').select('*');

      if (farmingMethod != null && farmingMethod.isNotEmpty) {
        query = query.eq('farming_method', farmingMethod);
      }

      if (certification != null && certification.isNotEmpty) {
        query = query.eq('certification', certification);
      }

      if (crops != null && crops.isNotEmpty) {
        query = query.overlaps('crops', crops);
      }

      if (farmType != null && farmType.isNotEmpty) {
        query = query.overlaps('farm_type', farmType);
      }

      if (farmScale != null && farmScale.isNotEmpty) {
        query = query.eq('farm_scale', farmScale);
      }

      if (activities != null && activities.isNotEmpty) {
        query = query.overlaps('activities', activities);
      }

      if (specializations != null && specializations.isNotEmpty) {
        query = query.overlaps('specializations', specializations);
      }

      if (farmGoals != null && farmGoals.isNotEmpty) {
        query = query.overlaps('farm_goals', farmGoals);
      }

      final response = await query.limit(limit);

      return (response as List)
          .map((json) => FarmDetails.fromJson(json))
          .toList();
    } catch (e) {
      _setError('Failed to search farms: ${e.toString()}');
      return [];
    }
  }

  Future<List<FarmDetails>> getFarmsByLocation(String location) async {
    try {
      final profileResponse = await _supabase
          .from('user_profiles')
          .select('id')
          .ilike('location', '%$location%');

      if (profileResponse.isEmpty) return [];

      final userIds =
          profileResponse.map((profile) => profile['id'] as String).toList();

      final farmResponse = await _supabase
          .from('farm_details')
          .select('*')
          .inFilter('user_id', userIds);

      return (farmResponse as List)
          .map((json) => FarmDetails.fromJson(json))
          .toList();
    } catch (e) {
      _setError('Failed to get farms by location: ${e.toString()}');
      return [];
    }
  }

  void clearFarmDetails() {
    _currentFarmDetails = null;
    _currentUserId = null;
    _clearError();
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }
}
