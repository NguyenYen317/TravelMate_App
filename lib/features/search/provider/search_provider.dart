import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import '../../../data/models/place.dart';
import '../../../services/api_service.dart';

class SearchProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<Place> _searchResults = [];
  List<Place> get searchResults => _searchResults;

  List<Place> _nearbyPlaces = [];
  List<Place> get nearbyPlaces => _nearbyPlaces;

  List<Place> _favoritePlaces = [];
  List<Place> get favoritePlaces => _favoritePlaces;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  SearchProvider() {
    _loadFavorites();
    fetchNearbyPlaces();
  }

  // Chuẩn hoá chuỗi: chuyển về lowercase và loại bỏ dấu tiếng Việt
  String _normalize(String input) {
    if (input.isEmpty) return '';
    final s = input.toLowerCase();
    const from =
        'áàảãạăắằẳẵặâấầẩẫậéèẻẽẹêếềểễệíìỉĩịóòỏõọôốồổỗộơớờởỡợúùủũụưứừửữựýỳỷỹỵđ'
        'ÁÀẢÃẠĂẮẰẲẴẶÂẤẦẨẪẬÉÈẺẼẸÊẾỀỂỄỆÍÌỈĨỊÓÒỎÕỌÔỐỒỔỖỘƠỚỜỞỠỢÚÙỦŨỤƯỨỪỬỮỰÝỲỶỸỴĐ';
    const to =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeiiiiioooooooooooooooooouuuuuuuuuuuyyyyyd'
        'AAAAAAAAAAAAAAAAAEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';

    var output = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final ch = s[i];
      final idx = from.indexOf(ch);
      if (idx != -1) {
        output.write(to[idx]);
      } else {
        output.write(ch);
      }
    }
    return output.toString();
  }

  // Tải địa điểm gần đây
  Future<void> fetchNearbyPlaces() async {
    _isLoading = true;
    _nearbyPlaces = []; // Xóa dữ liệu cũ để hiện hiệu ứng loading
    notifyListeners();

    try {
      Position position = await _determinePosition();
      _nearbyPlaces = await _apiService.getNearbyPlaces(
        position.latitude,
        position.longitude,
      );
    } catch (e) {
      debugPrint("Nearby Places Error: $e");
      // Fallback Hà Nội
      _nearbyPlaces = await _apiService.getNearbyPlaces(21.0285, 105.8542);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Tìm kiếm địa điểm
  Future<void> search(String query) async {
    if (query.isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // Call API then filter locally using normalized (no-diacritic) comparison
      final results = await _apiService.searchPlaces(query);
      final q = _normalize(query.trim());
      _searchResults = results.where((p) {
        final name = _normalize(p.name);
        final category = _normalize(p.category);
        return name.contains(q) || category.contains(q);
      }).toList();
    } catch (e) {
      debugPrint("Search API Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Hàm hỗ trợ lọc từ Trang chủ
  Future<void> filterByCategory(String category) async {
    _isLoading = true;
    _searchResults = [];
    notifyListeners();

    try {
      Position position = await _determinePosition();
      // Chuyển thể loại sang query hoặc gọi Overpass
      final results = await _apiService.getNearbyPlaces(
        position.latitude,
        position.longitude,
      );
      if (category.isNotEmpty) {
        final c = _normalize(category.trim());
        _searchResults = results.where((p) {
          return _normalize(p.category).contains(c) ||
              _normalize(p.name).contains(c);
        }).toList();
      } else {
        _searchResults = results;
      }
    } catch (e) {
      // Fallback to API search if nearby call fails
      _searchResults = await _apiService.searchPlaces(category);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return Future.error('GPS chưa bật');

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied)
        return Future.error('Quyền vị trí bị từ chối');
    }
    return await Geolocator.getCurrentPosition();
  }

  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> favList =
          prefs.getStringList('favorite_places_data') ?? [];
      _favoritePlaces = favList
          .map((item) => Place.fromMap(json.decode(item)))
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint("Load favorites error: $e");
    }
  }

  bool isFavorite(String placeId) {
    return _favoritePlaces.any((p) => p.id == placeId);
  }

  Future<void> toggleFavorite(Place place) async {
    final index = _favoritePlaces.indexWhere((p) => p.id == place.id);
    if (index >= 0) {
      _favoritePlaces.removeAt(index);
    } else {
      _favoritePlaces.add(place);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> favData = _favoritePlaces
          .map((e) => json.encode(e.toMap()))
          .toList();
      await prefs.setStringList('favorite_places_data', favData);
      notifyListeners();
    } catch (e) {
      debugPrint("Save favorite error: $e");
    }
  }
}
