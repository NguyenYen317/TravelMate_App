import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart'; // Để mở Google Maps
import '../../../data/models/place.dart';
import '../../search/search_service.dart';
import '../map_service.dart';

class MapScreen extends StatefulWidget {
  final Place place;
  const MapScreen({super.key, required this.place});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng? _currentLocation;
  List<LatLng> _routePoints = [];
  final MapController _mapController = MapController();
  final MapService _mapService = MapService();
  final SearchService _searchService = SearchService();
  bool _isLoadingRoute = false;
  bool _followUser = true;

  StreamSubscription<Position>? _positionStreamSubscription;

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });

        if (_followUser) {
          _mapController.move(_currentLocation!, _mapController.camera.zoom);
        }
        
        if (_routePoints.isEmpty) {
          _getDirection();
        }
      }
    });
  }

  Future<void> _getDirection() async {
    if (_currentLocation == null) return;
    setState(() => _isLoadingRoute = true);
    final destination = LatLng(widget.place.lat, widget.place.lng);
    final points = await _mapService.getRoute(_currentLocation!, destination);
    if (mounted) {
      setState(() {
        _routePoints = points;
        _isLoadingRoute = false;
      });
    }
  }

  // HÀM MỞ GOOGLE MAPS ĐỂ DẪN ĐƯỜNG THỰC TẾ
  Future<void> _launchGoogleNavigation() async {
    final String url = "google.navigation:q=${widget.place.lat},${widget.place.lng}&mode=d";
    final Uri uri = Uri.parse(url);
    final Uri webUri = Uri.parse("https://www.google.com/maps/dir/?api=1&destination=${widget.place.lat},${widget.place.lng}&travelmode=driving");

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể mở ứng dụng bản đồ')),
        );
      }
    } catch (e) {
      debugPrint("Error launching maps: $e");
    }
  }

  Future<void> _showCurrentLocationDetail() async {
    if (_currentLocation == null) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return FutureBuilder<Place>(
          future: _searchService.reverseGeocode(_currentLocation!.latitude, _currentLocation!.longitude),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
            }
            final myPlace = snapshot.data ?? Place(
              id: '', 
              name: 'Vị trí của bạn', 
              address: 'Đang tải...',
              lat: _currentLocation!.latitude,
              lng: _currentLocation!.longitude,
            );
            
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Vị trí của bạn", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(),
                  Text(myPlace.address, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final String myLocLink = "https://www.google.com/maps/search/?api=1&query=${_currentLocation!.latitude},${_currentLocation!.longitude}";
                        Share.share("Vị trí của mình: $myLocLink");
                      },
                      icon: const Icon(Icons.share),
                      label: const Text("Chia sẻ vị trí hiện tại"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final destination = LatLng(widget.place.lat, widget.place.lng);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.place.name),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: destination,
              initialZoom: 15.0,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
              onPositionChanged: (position, hasGesture) {
                if (hasGesture && _followUser) setState(() => _followUser = false);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.travelmate_app',
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(points: _routePoints, color: Colors.blueAccent, strokeWidth: 6.0),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: destination,
                    width: 50,
                    height: 50,
                    child: const Icon(Icons.location_on, color: Colors.red, size: 45),
                  ),
                  if (_currentLocation != null)
                    Marker(
                      point: _currentLocation!,
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: _showCurrentLocationDetail,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.3),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 30),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          
          // NÚT "BẮT ĐẦU ĐI" - CHUYỂN HƯỚNG SANG GOOGLE MAPS
          Positioned(
            bottom: 30,
            left: 20,
            right: 80, // Chừa chỗ cho Floating Action Buttons
            child: SizedBox(
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _launchGoogleNavigation,
                icon: const Icon(Icons.navigation, size: 28),
                label: const Text('BẮT ĐẦU ĐI', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ),
          ),

          if (_isLoadingRoute)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'follow',
            onPressed: () {
              setState(() => _followUser = !_followUser);
              if (_followUser && _currentLocation != null) {
                _mapController.move(_currentLocation!, 15.0);
              }
            },
            backgroundColor: _followUser ? Colors.blue : Colors.grey,
            child: Icon(_followUser ? Icons.gps_fixed : Icons.gps_not_fixed, color: Colors.white),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'my_loc',
            onPressed: () {
              if (_currentLocation != null) {
                _mapController.move(_currentLocation!, 15.0);
                setState(() => _followUser = true);
              }
            },
            child: const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }
}
