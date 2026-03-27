import '.././../services/api_service.dart';
import '../../data/models/place.dart';

// Wrapper để giữ tính tương thích với code cũ
class SearchService {
  final ApiService _apiService = ApiService();

  Future<Place> reverseGeocode(double lat, double lon) async {
    // Sử dụng Nominatim cho reverse geocoding
    final results = await _apiService.searchPlaces("$lat,$lon");
    if (results.isNotEmpty) return results.first;
    throw Exception("Không tìm thấy địa chỉ");
  }

  Future<List<Place>> searchPlaces(String query, {double? lat, double? lon, String? categories}) async {
    if (lat != null && lon != null) {
      return await _apiService.getNearbyPlaces(lat, lon);
    }
    return await _apiService.searchPlaces(query);
  }
}
