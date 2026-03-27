class Place {
  final String id;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final String category;
  final String? imageUrl;
  final double rating;
  final String? openingHours;
  final List<String> types;

  Place({
    required this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    this.category = 'Point of Interest',
    this.imageUrl,
    this.rating = 4.0,
    this.openingHours,
    this.types = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'lat': lat,
      'lng': lng,
      'category': category,
      'imageUrl': imageUrl,
      'rating': rating,
    };
  }

  factory Place.fromMap(Map<String, dynamic> map) {
    return Place(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      category: map['category'] ?? '',
      imageUrl: map['imageUrl'],
      rating: (map['rating'] as num?)?.toDouble() ?? 4.0,
    );
  }

  // CẢI TIẾN: Bóc tách địa chỉ từ Nominatim cực chuẩn
  factory Place.fromNominatim(Map<String, dynamic> json) {
    final addr = json['address'] ?? {};
    final displayName = json['display_name'] ?? '';
    
    // Ưu tiên lấy tên địa danh cụ thể
    String name = addr['amenity'] ?? addr['tourism'] ?? addr['historic'] ?? addr['shop'] ?? addr['office'] ?? '';
    if (name.isEmpty) {
      name = displayName.split(',').first;
    }

    // Xây dựng địa chỉ ngắn gọn: [Số nhà, Đường], [Quận/Huyện], [Tỉnh/Thành]
    List<String> addressParts = [];
    if (addr['house_number'] != null) addressParts.add(addr['house_number']);
    if (addr['road'] != null) addressParts.add(addr['road']);
    if (addr['suburb'] != null) addressParts.add(addr['suburb']);
    if (addr['city_district'] != null) addressParts.add(addr['city_district']);
    if (addr['city'] != null || addr['state'] != null) {
      addressParts.add(addr['city'] ?? addr['state']);
    }

    String finalAddress = addressParts.join(', ');
    if (finalAddress.isEmpty) finalAddress = displayName;

    final category = json['class']?.toString() ?? '';
    final type = json['type']?.toString() ?? '';

    return Place(
      id: json['place_id']?.toString() ?? '',
      name: name,
      address: finalAddress,
      lat: double.tryParse(json['lat']?.toString() ?? '0') ?? 0,
      lng: double.tryParse(json['lon']?.toString() ?? '0') ?? 0,
      category: category,
      imageUrl: _getCategoryImage(category, type, name),
    );
  }

  // CẢI TIẾN: Lấy địa chỉ từ Overpass tags
  factory Place.fromOverpass(Map<String, dynamic> json) {
    final tags = json['tags'] ?? {};
    final name = tags['name'] ?? 'Địa điểm không tên';
    
    // Xây dựng địa chỉ từ tags của Overpass
    List<String> addrParts = [];
    if (tags['addr:housenumber'] != null) addrParts.add(tags['addr:housenumber']);
    if (tags['addr:street'] != null) addrParts.add(tags['addr:street']);
    if (tags['addr:suburb'] != null) addrParts.add(tags['addr:suburb']);
    if (tags['addr:city'] != null) addrParts.add(tags['addr:city']);
    
    String address = addrParts.join(', ');
    if (address.isEmpty) address = 'Khu vực lân cận';

    final amenity = tags['amenity']?.toString() ?? '';
    final tourism = tags['tourism']?.toString() ?? '';
    
    // Lấy tọa độ (Overpass nwr center trả về center: {lat, lon})
    double lat = 0;
    double lon = 0;
    if (json['lat'] != null) {
      lat = json['lat'].toDouble();
      lon = json['lon'].toDouble();
    } else if (json['center'] != null) {
      lat = json['center']['lat'].toDouble();
      lon = json['center']['lon'].toDouble();
    }

    return Place(
      id: json['id']?.toString() ?? '',
      name: name,
      address: address,
      lat: lat,
      lng: lon,
      category: amenity.isNotEmpty ? amenity : tourism,
      imageUrl: _getCategoryImage(amenity, tourism, name),
    );
  }

  static String _getCategoryImage(String cat, String type, String name) {
    final fullText = '$cat $type $name'.toLowerCase();
    if (fullText.contains('restaurant') || fullText.contains('cafe') || fullText.contains('food') || fullText.contains('quán ăn')) {
      return 'https://images.pexels.com/photos/262978/pexels-photo-262978.jpeg?auto=compress&cs=tinysrgb&w=800';
    }
    if (fullText.contains('hotel') || fullText.contains('hostel') || fullText.contains('khách sạn')) {
      return 'https://images.pexels.com/photos/164595/pexels-photo-164595.jpeg?auto=compress&cs=tinysrgb&w=800';
    }
    if (fullText.contains('park') || fullText.contains('forest') || fullText.contains('mountain') || fullText.contains('lake') || fullText.contains('viewpoint')) {
      return 'https://images.pexels.com/photos/417074/pexels-photo-417074.jpeg?auto=compress&cs=tinysrgb&w=800';
    }
    if (fullText.contains('museum') || fullText.contains('historic') || fullText.contains('bảo tàng')) {
      return 'https://images.pexels.com/photos/69903/pexels-photo-69903.jpeg?auto=compress&cs=tinysrgb&w=800';
    }
    return 'https://images.pexels.com/photos/3278215/pexels-photo-3278215.jpeg?auto=compress&cs=tinysrgb&w=800';
  }
}

class PlacePrediction {
  final String placeId;
  final String description;
  final String structuredTitle;
  final double? lat;
  final double? lon;

  PlacePrediction({
    required this.placeId, 
    required this.description,
    required this.structuredTitle,
    this.lat,
    this.lon,
  });

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    final displayName = json['display_name']?.toString() ?? '';
    return PlacePrediction(
      placeId: json['place_id']?.toString() ?? '',
      description: displayName,
      structuredTitle: displayName.split(',').first,
      lat: double.tryParse(json['lat']?.toString() ?? ''),
      lon: double.tryParse(json['lon']?.toString() ?? ''),
    );
  }
}
