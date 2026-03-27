import 'dart:math';

class Place {
  final String id;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final String category;
  final String? imageUrl;
  final double rating;
  final String? description;
  final List<String> types;
  
  // Extra fields for rich details
  final String? phone;
  final String? website;
  final String? openingHours;
  final Map<String, dynamic> extraTags;

  Place({
    required this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    this.category = 'Point of Interest',
    this.imageUrl,
    this.rating = 4.0,
    this.description,
    this.types = const [],
    this.phone,
    this.website,
    this.openingHours,
    this.extraTags = const {},
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
      'description': description,
      'phone': phone,
      'website': website,
      'openingHours': openingHours,
      'extraTags': extraTags,
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
      description: map['description'],
      phone: map['phone'],
      website: map['website'],
      openingHours: map['openingHours'],
      extraTags: map['extraTags'] != null ? Map<String, dynamic>.from(map['extraTags']) : const {},
    );
  }

  factory Place.fromNominatim(Map<String, dynamic> json) {
    final addr = json['address'] != null ? Map<String, dynamic>.from(json['address']) : <String, dynamic>{};
    final tags = json['extratags'] != null ? Map<String, dynamic>.from(json['extratags']) : <String, dynamic>{};
    final displayName = json['display_name'] ?? '';
    
    String name = addr['amenity'] ?? addr['tourism'] ?? addr['historic'] ?? addr['shop'] ?? addr['office'] ?? '';
    if (name.isEmpty) {
      name = displayName.split(',').first;
    }

    List<String> addressParts = [];
    if (addr['house_number'] != null) addressParts.add(addr['house_number'].toString());
    if (addr['road'] != null) addressParts.add(addr['road'].toString());
    if (addr['suburb'] != null) addressParts.add(addr['suburb'].toString());
    if (addr['city_district'] != null) addressParts.add(addr['city_district'].toString());
    if (addr['city'] != null || addr['state'] != null) {
      addressParts.add((addr['city'] ?? addr['state']).toString());
    }

    String finalAddress = addressParts.join(', ');
    if (finalAddress.isEmpty) finalAddress = displayName;

    final id = json['place_id']?.toString() ?? '';
    final category = json['class']?.toString() ?? '';
    final type = json['type']?.toString() ?? '';

    return Place(
      id: id,
      name: name,
      address: finalAddress,
      lat: double.tryParse(json['lat']?.toString() ?? '0') ?? 0,
      lng: double.tryParse(json['lon']?.toString() ?? '0') ?? 0,
      category: category.toUpperCase(),
      rating: 4.0 + (Random(id.hashCode).nextInt(10) / 10.0),
      description: 'Khám phá $name. Một địa điểm tuyệt vời tại $finalAddress.',
      imageUrl: _getSmartImage(id, name, finalAddress, category, type),
      phone: (tags['phone'] ?? tags['contact:phone'])?.toString(),
      website: (tags['website'] ?? tags['contact:website'])?.toString(),
      openingHours: tags['opening_hours']?.toString(),
      extraTags: tags,
    );
  }

  factory Place.fromOverpass(Map<String, dynamic> json) {
    final tags = json['tags'] != null ? Map<String, dynamic>.from(json['tags']) : <String, dynamic>{};
    final name = tags['name'] ?? tags['brand'] ?? 'Địa điểm du lịch';
    final id = json['id']?.toString() ?? '';
    
    List<String> addrParts = [];
    if (tags['addr:housenumber'] != null) addrParts.add(tags['addr:housenumber'].toString());
    if (tags['addr:street'] != null) addrParts.add(tags['addr:street'].toString());
    if (tags['addr:suburb'] != null) addrParts.add(tags['addr:suburb'].toString());
    if (tags['addr:district'] != null) addrParts.add(tags['addr:district'].toString());
    if (tags['addr:city'] != null) addrParts.add(tags['addr:city'].toString());
    
    String address = addrParts.isNotEmpty ? addrParts.join(', ') : 'Khu vực lân cận';

    final amenity = tags['amenity']?.toString() ?? '';
    final tourism = tags['tourism']?.toString() ?? '';
    final category = amenity.isNotEmpty ? amenity : (tourism.isNotEmpty ? tourism : 'Địa điểm');
    
    double lat = (json['lat'] as num?)?.toDouble() ?? (json['center']?['lat'] as num?)?.toDouble() ?? 0;
    double lon = (json['lon'] as num?)?.toDouble() ?? (json['center']?['lon'] as num?)?.toDouble() ?? 0;

    return Place(
      id: id,
      name: name,
      address: address,
      lat: lat,
      lng: lon,
      category: category.toUpperCase(),
      rating: 4.2 + (Random(id.hashCode).nextInt(8) / 10.0),
      imageUrl: _getSmartImage(id, name, address, amenity, tourism),
      phone: (tags['phone'] ?? tags['contact:phone'])?.toString(),
      website: (tags['website'] ?? tags['contact:website'])?.toString(),
      openingHours: tags['opening_hours']?.toString(),
      extraTags: tags,
    );
  }

  static String _getSmartImage(String id, String name, String addr, String cat, String type) {
    final search = '$name $cat $type'.toLowerCase();
    String keyword = 'travel';
    if (search.contains('restaurant') || search.contains('food') || search.contains('ăn')) keyword = 'restaurant';
    else if (search.contains('hotel') || search.contains('resort') || search.contains('nghỉ')) keyword = 'hotel';
    else if (search.contains('cafe') || search.contains('coffee')) keyword = 'coffee';
    else if (search.contains('park') || search.contains('nature') || search.contains('công viên')) keyword = 'park';
    else if (search.contains('museum') || search.contains('history')) keyword = 'museum';
    else if (search.contains('beach') || search.contains('sea') || search.contains('biển')) keyword = 'beach';
    
    return 'https://loremflickr.com/800/600/$keyword?lock=${id.hashCode % 1000}';
  }
}
