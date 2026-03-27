import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class MapService {
  // Sử dụng OSRM API miễn phí để lấy đường đi
  Future<List<LatLng>> getRoute(LatLng start, LatLng end) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson'
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List coordinates = data['routes'][0]['geometry']['coordinates'];
        
        // Chuyển đổi list [lon, lat] từ API thành list LatLng(lat, lon)
        return coordinates.map((coord) => LatLng(coord[1].toDouble(), coord[0].toDouble())).toList();
      }
    } catch (e) {
      print("Lỗi lấy chỉ đường: $e");
    }
    return [];
  }
}
