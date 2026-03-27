import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/models/place.dart';

class ApiService {
  static const String nominatimUrl = 'https://nominatim.openstreetmap.org/search';
  static const String overpassUrl = 'https://overpass-api.de/api/interpreter';

  Future<List<Place>> searchPlaces(String query) async {
    if (query.isEmpty) return [];
    
    try {
      // Thêm tham số accept-language=vi để ưu tiên tiếng Việt
      final response = await http.get(
        Uri.parse('$nominatimUrl?q=$query&format=json&limit=15&addressdetails=1&countrycodes=vn&accept-language=vi'),
        headers: {'User-Agent': 'TravelMateApp/1.0'}, 
      );

      if (response.statusCode == 200) {
        final List data = json.decode(utf8.decode(response.bodyBytes));
        return data.map((item) => Place.fromNominatim(item)).toList();
      }
    } catch (e) {
      print("Search API error: $e");
    }
    return [];
  }

  Future<List<Place>> getNearbyPlaces(double lat, double lng) async {
    // Truy vấn thông minh hơn: 
    // 1. Lấy cả Node (điểm), Way (đường/vùng), Relation (nhóm)
    // 2. Chỉ lấy những thứ có tên (name)
    // 3. Lấy tọa độ trung tâm (center) cho các vùng lớn
    final query = '''
      [out:json][timeout:25];
      (
        nwr["amenity"~"restaurant|cafe|fast_food|bar"](around:3000, $lat, $lng);
        nwr["tourism"~"hotel|hostel|motel|guest_house|museum|viewpoint|attraction"](around:3000, $lat, $lng);
        nwr["historic"~"monument|memorial"](around:3000, $lat, $lng);
      );
      out center;
    ''';

    try {
      final response = await http.post(
        Uri.parse(overpassUrl),
        body: query,
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final List elements = data['elements'] ?? [];
        
        // Lọc bỏ những địa điểm không có tên và chuyển đổi
        return elements
          .where((e) => e['tags'] != null && e['tags']['name'] != null)
          .map((item) => Place.fromOverpass(item))
          .toList();
      }
    } catch (e) {
      print("Overpass API error: $e");
    }
    return [];
  }
}
