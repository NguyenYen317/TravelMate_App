import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../services/api_service.dart';
import '../../data/models/place.dart';

class SearchService {
  final ApiService _apiService = ApiService();
  
  // Cache lưu trữ kết quả theo query + filter + tọa độ
  final Map<String, List<Place>> _searchCache = {};
  
  // Lưu trữ tọa độ trung tâm của các địa danh đã tìm kiếm để tránh geocoding lại
  final Map<String, Map<String, double>> _locationCenterCache = {};

  static const double defaultFilterRadius = 25.0;

  /// Giải mã ngược tọa độ thành địa chỉ (Sửa lỗi missing method)
  Future<Place> reverseGeocode(double lat, double lon) async {
    final url = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'lat': lat.toString(),
      'lon': lon.toString(),
      'format': 'json',
      'addressdetails': '1',
      'accept-language': 'vi',
    });

    try {
      final response = await http.get(url, headers: {'User-Agent': 'TravelMateApp/1.0'});
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return Place.fromNominatim(data);
      }
    } catch (e) {
      debugPrint("ReverseGeocode Error: $e");
    }
    // Trả về một Place mặc định nếu lỗi
    return Place(id: 'unknown', name: 'Vị trí hiện tại', address: 'Đang xác định...', lat: lat, lng: lon);
  }

  /// Hàm tìm kiếm chính tích hợp Caching và lọc theo Category
  Future<List<Place>> searchPlaces(String query, {String? category, double? lat, double? lon, double radius = defaultFilterRadius}) async {
    final normalizedQuery = _normalizeQuery(query);
    if (normalizedQuery.isEmpty && category == null && lat == null) return [];

    // 1. Tạo Cache Key duy nhất
    final cacheKey = "${normalizedQuery}_${category ?? 'all'}_${lat ?? 0}_${lon ?? 0}_$radius";
    
    if (_searchCache.containsKey(cacheKey)) {
      debugPrint("SearchService: [CACHE HIT] returning results for $cacheKey");
      return _searchCache[cacheKey]!;
    }

    try {
      double targetLat = lat ?? 0;
      double targetLon = lon ?? 0;
      String viewbox = "";

      // 2. Xác định tọa độ trung tâm (Geocoding) nếu cần
      if (normalizedQuery.isNotEmpty && (lat == null || lon == null)) {
        if (_locationCenterCache.containsKey(normalizedQuery)) {
          targetLat = _locationCenterCache[normalizedQuery]!['lat']!;
          targetLon = _locationCenterCache[normalizedQuery]!['lon']!;
        } else {
          final geocodeResults = await _getGeocodingData(normalizedQuery);
          if (geocodeResults.isNotEmpty) {
            final topMatch = geocodeResults.first;
            targetLat = double.parse(topMatch['lat']);
            targetLon = double.parse(topMatch['lon']);
            _locationCenterCache[normalizedQuery] = {'lat': targetLat, 'lon': targetLon};
          }
        }
      }

      // 3. Thực hiện gọi API
      final List<Place> finalResults = await _fetchFromNominatim(
        normalizedQuery, 
        category: category,
        lat: targetLat != 0 ? targetLat : null, 
        lon: targetLon != 0 ? targetLon : null,
        radius: radius,
      );

      // 4. Hậu xử lý: Lọc và Sắp xếp
      List<Place> processedResults = finalResults;
      if (targetLat != 0 && targetLon != 0) {
        processedResults = finalResults.where((p) {
          final dist = _calculateDistance(targetLat, targetLon, p.lat, p.lng);
          return dist <= radius;
        }).toList();

        processedResults.sort((a, b) {
          final distA = _calculateDistance(targetLat, targetLon, a.lat, a.lng);
          final distB = _calculateDistance(targetLat, targetLon, b.lat, b.lng);
          return distA.compareTo(distB);
        });
      }

      _searchCache[cacheKey] = processedResults;
      return processedResults;

    } catch (e) {
      debugPrint("SearchService Error: $e");
      return [];
    }
  }

  String _normalizeQuery(String query) {
    return query.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<List<dynamic>> _getGeocodingData(String query) async {
    final url = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'json',
      'limit': '1',
      'countrycodes': 'vn',
    });
    final response = await http.get(url, headers: {'User-Agent': 'TravelMateApp/1.0'});
    return response.statusCode == 200 ? json.decode(utf8.decode(response.bodyBytes)) : [];
  }

  Future<List<Place>> _fetchFromNominatim(String query, {String? category, double? lat, double? lon, double radius = 25.0}) async {
    String effectiveQuery = query;
    if (category != null) {
      String catName = _mapCategoryToKeyword(category);
      effectiveQuery = query.isEmpty ? catName : "$catName $query";
    }

    final params = {
      'q': effectiveQuery,
      'format': 'json',
      'limit': '30',
      'addressdetails': '1',
      'extratags': '1', // Lấy thêm các tag chi tiết như phone, website
      'countrycodes': 'vn',
      'accept-language': 'vi',
    };

    if (lat != null && lon != null) {
      // Tính toán viewbox xấp xỉ theo bán kính (1 độ ~ 111km)
      final offset = radius / 111.0;
      params['viewbox'] = "${lon - offset},${lat + offset},${lon + offset},${lat - offset}";
      params['bounded'] = '1';
    }

    final url = Uri.https('nominatim.openstreetmap.org', '/search', params);
    final response = await http.get(url, headers: {'User-Agent': 'TravelMateApp/1.0'});
    
    if (response.statusCode == 200) {
      final List data = json.decode(utf8.decode(response.bodyBytes));
      return data.map((item) => Place.fromNominatim(item)).toList();
    }
    return [];
  }

  String _mapCategoryToKeyword(String category) {
    switch (category) {
      case 'hotel': return 'khách sạn';
      case 'restaurant': return 'nhà hàng';
      case 'cafe': return 'cà phê';
      case 'tourism': return 'điểm du lịch';
      default: return category;
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    const c = cos;
    final a = 0.5 - c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  void clearCache() {
    _searchCache.clear();
    _locationCenterCache.clear();
  }
}
