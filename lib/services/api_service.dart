import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/models/place.dart';

class ApiService {
  static const String nominatimBase = 'nominatim.openstreetmap.org';
  static const String overpassUrl = 'https://overpass-api.de/api/interpreter';

  Future<List<Place>> searchPlaces(String query) async {
    if (query.isEmpty) return [];
    
    try {
      final url = Uri.https(nominatimBase, '/search', {
        'q': query,
        'format': 'json',
        'limit': '10',
        'addressdetails': '1',
        'countrycodes': 'vn',
        'accept-language': 'vi'
      });

      final response = await http.get(
        url,
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

  Future<List<Place>> getNearbyPlacesWithCategory(double lat, double lng, String category) async {
    String filter = '';
    if (category == 'restaurant') {
      filter = 'nwr["amenity"~"restaurant|fast_food|food_court|cafe"]';
    } else if (category == 'hotel') {
      filter = 'nwr["tourism"~"hotel|hostel|resort|motel|guest_house|apartment"]';
    } else if (category == 'tourism') {
      filter = 'nwr["tourism"~"viewpoint|attraction|museum|zoo|gallery|theme_park|historic|beach"]';
    } else if (category == 'cafe') {
      filter = 'nwr["amenity"~"cafe|bar|pub"]';
    } else {
      filter = 'nwr["amenity"]';
    }

    // Tăng bán kính lên 30km (30000m) để phủ rộng hơn, đặc biệt hữu ích cho các đảo như Phú Quốc
    // hoặc khi người dùng tìm kiếm theo trung tâm tỉnh/thành phố.
    final query = '''
      [out:json][timeout:30];
      (
        $filter(around:30000, $lat, $lng);
      );
      out center 50;
    ''';

    try {
      final response = await http.post(Uri.parse(overpassUrl), body: query);
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final List elements = data['elements'] ?? [];
        
        return elements
          .where((e) {
            final tags = e['tags'] ?? {};
            return tags['name'] != null && tags['name'].toString().length > 1;
          })
          .map((item) => Place.fromOverpass(item))
          .toList();
      }
    } catch (e) {
      print("Overpass Category error: $e");
    }
    return [];
  }

  Future<List<Place>> getNearbyPlaces(double lat, double lng) async {
    final query = '''
      [out:json][timeout:25];
      (
        nwr["amenity"~"restaurant|cafe"](around:5000, $lat, $lng);
        nwr["tourism"~"hotel|viewpoint|attraction"](around:5000, $lat, $lng);
      );
      out center 30;
    ''';

    try {
      final response = await http.post(Uri.parse(overpassUrl), body: query);
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final List elements = data['elements'] ?? [];
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
