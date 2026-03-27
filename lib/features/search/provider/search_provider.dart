import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import '../../../data/models/place.dart';
import '../search_service.dart';

class SearchProvider extends ChangeNotifier {
  final SearchService _searchService = SearchService();

  List<Place> _searchResults = [];
  List<Place> get searchResults => _searchResults;

  List<Place> _nearbyPlaces = [];
  List<Place> get nearbyPlaces => _nearbyPlaces;

  List<Place> _favoritePlaces = [];
  List<Place> get favoritePlaces => _favoritePlaces;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _hasSearched = false;
  bool get hasSearched => _hasSearched;

  String _currentQuery = '';
  String get currentQuery => _currentQuery;

  String? _activeCategory;
  String? get activeCategory => _activeCategory;

  SearchProvider() {
    _loadFavorites();
  }

  bool isFavorite(String placeId) {
    return _favoritePlaces.any((p) => p.id == placeId);
  }

  /// Tìm kiếm theo địa danh (query chính)
  Future<void> search(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery == _currentQuery && _activeCategory == null) return;

    _currentQuery = trimmedQuery;
    _activeCategory = null;

    if (_currentQuery.isEmpty) {
      _searchResults = [];
      _hasSearched = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _hasSearched = true;
    notifyListeners();

    try {
      _searchResults = await _searchService.searchPlaces(_currentQuery);
    } catch (e) {
      debugPrint("SearchProvider Search Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Lọc theo danh mục (Sử dụng Cache từ SearchService)
  Future<void> filterByCategory(String category) async {
    // Nếu chọn lại category cũ thì bỏ chọn (toggle off)
    final String? newCategory = (category == _activeCategory || category.isEmpty) ? null : category;
    
    if (newCategory == _activeCategory) return;
    
    _activeCategory = newCategory;
    _isLoading = true;
    _hasSearched = true;
    notifyListeners();

    try {
      // Gọi service: Service đã có sẵn logic Caching theo Query + Category
      _searchResults = await _searchService.searchPlaces(
        _currentQuery, 
        category: _activeCategory,
      );
    } catch (e) {
      debugPrint("SearchProvider Category Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Các hàm phụ trợ giữ nguyên ---

  Future<void> fetchNearbyPlaces() async {
    _isLoading = true;
    notifyListeners();
    try {
      Position position = await _determinePosition();
      // Tận dụng service search với tọa độ
      _nearbyPlaces = await _searchService.searchPlaces("", lat: position.latitude, lon: position.longitude);
    } catch (e) {
      debugPrint("Nearby Error: $e");
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
      if (permission == LocationPermission.denied) return Future.error('Quyền vị trí bị từ chối');
    }
    return await Geolocator.getCurrentPosition();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> favList = prefs.getStringList('favorite_places_data') ?? [];
    _favoritePlaces = favList.map((item) => Place.fromMap(json.decode(item))).toList();
    notifyListeners();
  }

  void toggleFavorite(Place place) async {
    final index = _favoritePlaces.indexWhere((p) => p.id == place.id);
    if (index >= 0) _favoritePlaces.removeAt(index);
    else _favoritePlaces.add(place);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorite_places_data', _favoritePlaces.map((e) => json.encode(e.toMap())).toList());
    notifyListeners();
  }

  void clearResults() {
    _searchResults = [];
    _currentQuery = '';
    _activeCategory = null;
    _hasSearched = false;
    notifyListeners();
  }
}
