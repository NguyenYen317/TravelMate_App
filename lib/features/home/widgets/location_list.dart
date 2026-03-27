import 'package:flutter/material.dart';
import '../../search/screens/place_detail_screen.dart';
import '../../../data/models/place.dart';

class LocationList extends StatelessWidget {
  final String title;
  const LocationList({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    // Danh sách địa điểm đã cập nhật với các ảnh mới trong assets
    final List<Map<String, dynamic>> trendingData = [
      {
        'id': 'vn_halong',
        'name': 'Vịnh Hạ Long',
        'address': 'Quảng Ninh, Việt Nam',
        'imageUrl': 'assets/images/halong.jpg',
        'lat': 20.9101,
        'lng': 107.1839,
        'category': 'Di sản thế giới',
      },
      {
        'id': 'vn_danang',
        'name': 'Đà Nẵng',
        'address': 'Thành phố Đà Nẵng',
        'imageUrl': 'assets/images/danang.jpg',
        'lat': 16.0544,
        'lng': 108.2022,
        'category': 'Thành phố biển',
      },
      {
        'id': 'vn_phuquoc',
        'name': 'Phú Quốc',
        'address': 'Kiên Giang, Việt Nam',
        'imageUrl': 'assets/images/phuquoc.jpg',
        'lat': 10.2289,
        'lng': 103.9572,
        'category': 'Điểm du lịch',
      },
      {
        'id': 'vn_sapa',
        'name': 'Sa Pa',
        'address': 'Lào Cai, Việt Nam',
        'imageUrl': 'assets/images/sapa.jpg',
        'lat': 22.3364,
        'lng': 103.8438,
        'category': 'Vùng núi cao',
      },
      {
        'id': 'vn_mocchau',
        'name': 'Mộc Châu',
        'address': 'Sơn La, Việt Nam',
        'imageUrl': 'assets/images/mocchau.jpg',
        'lat': 20.8466,
        'lng': 104.6483,
        'category': 'Cao nguyên',
      },
      {
        'id': 'vn_samson',
        'name': 'Sầm Sơn',
        'address': 'Thanh Hóa, Việt Nam',
        'imageUrl': 'assets/images/samson.jpg',
        'lat': 19.7424,
        'lng': 105.8973,
        'category': 'Điểm du lịch',
      },
      {
        'id': 'vn_baidinh',
        'name': 'Chùa Bái Đính',
        'address': 'Ninh Bình, Việt Nam',
        'imageUrl': 'assets/images/baidinh.jpg',
        'lat': 20.2743,
        'lng': 105.8672,
        'category': 'Chùa',
      },
      {
        'id': 'vn_hoangthanh',
        'name': 'Hoàng Thành Thăng Long',
        'address': 'Hà Nội, Việt Nam',
        'imageUrl': 'assets/images/hoangthanhthanglong.jpg',
        'lat': 21.0344,
        'lng': 105.8392,
        'category': 'Di tích lịch sử',
      },
    ];

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            height: 220,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: trendingData.length,
              itemBuilder: (context, index) {
                final data = trendingData[index];
                final place = Place(
                  id: data['id'],
                  name: data['name'],
                  address: data['address'],
                  lat: data['lat'],
                  lng: data['lng'],
                  imageUrl: data['imageUrl'],
                  category: data['category'],
                  rating: 4.9,
                );

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PlaceDetailScreen(place: place),
                      ),
                    );
                  },
                  child: Hero(
                    tag: 'place-${place.id}',
                    child: Container(
                      width: 160,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _buildImage(place.imageUrl),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.7),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Material(
                                    color: Colors.transparent,
                                    child: Text(
                                      place.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on, color: Colors.white70, size: 10),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Material(
                                          color: Colors.transparent,
                                          child: Text(
                                            place.address,
                                            style: const TextStyle(color: Colors.white70, fontSize: 10),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        color: Colors.grey[200],
        child: const Icon(Icons.image_not_supported, color: Colors.grey),
      );
    }
    if (imageUrl.startsWith('assets/')) {
      return Image.asset(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey[200],
          child: const Icon(Icons.image_not_supported, color: Colors.grey),
        ),
      );
    }
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        color: Colors.grey[200],
        child: const Icon(Icons.image_not_supported, color: Colors.grey),
      ),
    );
  }
}
