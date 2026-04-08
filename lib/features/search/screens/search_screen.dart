import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'ai_suggestion_tab.dart';
import '../provider/search_provider.dart';
import 'place_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<bool> _showClearButton = ValueNotifier<bool>(false);
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      _showClearButton.value = _searchController.text.isNotEmpty;
    });
  }

  void _onSearchChanged(String query) {
    final provider = Provider.of<SearchProvider>(context, listen: false);
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
    }
    _debounce = Timer(const Duration(milliseconds: 800), () {
      provider.search(query);
    });
  }

  String _getCategoryDisplayName(String? key) {
    switch (key) {
      case 'restaurant':
        return 'Nhà hàng';
      case 'hotel':
        return 'Khách sạn';
      case 'cafe':
        return 'Cà phê';
      case 'tourism':
        return 'Tham quan';
      default:
        return '';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _showClearButton.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            'Tìm kiếm địa điểm',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Khám phá'),
              Tab(text: 'AI gợi ý'),
            ],
          ),
        ),
        body: TabBarView(
          children: [_buildExploreTab(), const AiSuggestionTab()],
        ),
      ),
    );
  }

  Widget _buildExploreTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Bạn muốn đi đâu? (Đà Nẵng, Phú Quốc...)',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Colors.blueAccent,
                ),
                suffixIcon: ValueListenableBuilder<bool>(
                  valueListenable: _showClearButton,
                  builder: (context, show, child) {
                    return show
                        ? IconButton(
                            icon: const Icon(
                              Icons.cancel_rounded,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              Provider.of<SearchProvider>(
                                context,
                                listen: false,
                              ).search('');
                            },
                          )
                        : const SizedBox.shrink();
                  },
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
        ),
        Consumer<SearchProvider>(
          builder: (context, provider, child) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildFilterChip(
                      'Nhà hàng',
                      'restaurant',
                      Icons.restaurant_rounded,
                      provider,
                    ),
                    const SizedBox(width: 10),
                    _buildFilterChip(
                      'Khách sạn',
                      'hotel',
                      Icons.hotel_rounded,
                      provider,
                    ),
                    const SizedBox(width: 10),
                    _buildFilterChip(
                      'Cà phê',
                      'cafe',
                      Icons.local_cafe_rounded,
                      provider,
                    ),
                    const SizedBox(width: 10),
                    _buildFilterChip(
                      'Tham quan',
                      'tourism',
                      Icons.explore_rounded,
                      provider,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Consumer<SearchProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) {
                return const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              }

              if (provider.searchResults.isNotEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (provider.activeCategory != null &&
                        provider.currentQuery.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: Text(
                          '${_getCategoryDisplayName(provider.activeCategory)} ở ${provider.currentQuery}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        physics: const BouncingScrollPhysics(),
                        itemCount: provider.searchResults.length,
                        itemBuilder: (context, index) {
                          final place = provider.searchResults[index];
                          return _buildPlaceCard(context, place, provider);
                        },
                      ),
                    ),
                  ],
                );
              }

              if (provider.hasSearched) {
                return _buildEmptyState();
              }
              return _buildExplorePlaceholder();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceCard(
    BuildContext context,
    dynamic place,
    SearchProvider provider,
  ) {
    String tagText = '';
    if (provider.activeCategory != null) {
      tagText = _getCategoryDisplayName(provider.activeCategory);
    } else {
      final rawCat = place.category.toString().toUpperCase();
      if (rawCat == 'BOUNDARY' || rawCat == 'PLACE') {
        tagText = 'ĐỊA DANH';
      } else {
        tagText = place.category.toString().split('_').first;
      }
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlaceDetailScreen(place: place),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Hero(
              tag: 'place-${place.id}',
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  bottomLeft: Radius.circular(24),
                ),
                child: _buildImage(place.imageUrl),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            tagText.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: Colors.amber,
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              place.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      place.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          color: Colors.grey,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            place.address,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        width: 120,
        height: 120,
        color: Colors.grey[100],
        child: const Icon(
          Icons.image_not_supported_outlined,
          color: Colors.grey,
        ),
      );
    }
    if (imageUrl.startsWith('assets/')) {
      return Image.asset(
        imageUrl,
        width: 120,
        height: 120,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 120,
          height: 120,
          color: Colors.grey[100],
          child: const Icon(
            Icons.image_not_supported_outlined,
            color: Colors.grey,
          ),
        ),
      );
    }
    return Image.network(
      imageUrl,
      width: 120,
      height: 120,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        width: 120,
        height: 120,
        color: Colors.grey[100],
        child: const Icon(
          Icons.image_not_supported_outlined,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String key,
    IconData icon,
    SearchProvider provider,
  ) {
    final isSelected = provider.activeCategory == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        provider.filterByCategory(selected ? key : '');
      },
      avatar: Icon(
        icon,
        size: 18,
        color: isSelected ? Colors.white : Colors.blueAccent,
      ),
      selectedColor: Colors.blueAccent,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: isSelected ? Colors.blueAccent : Colors.grey.shade200,
        ),
      ),
      elevation: isSelected ? 4 : 0,
      pressElevation: 0,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.network(
            'https://cdn-icons-png.flaticon.com/512/6134/6134065.png',
            width: 120,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 24),
          const Text(
            'Rất tiếc, không tìm thấy nơi nào\nphù hợp với yêu cầu của bạn.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 16, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildExplorePlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.map_outlined,
            size: 80,
            color: Colors.blue.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          const Text(
            'Bắt đầu hành trình bằng cách\nnhập địa điểm bạn muốn tới',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 16, height: 1.5),
          ),
        ],
      ),
    );
  }
}


