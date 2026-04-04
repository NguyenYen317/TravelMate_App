import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_provider.dart';
import '../../search/provider/search_provider.dart';

class CategoryList extends StatelessWidget {
  const CategoryList({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Text(
              'Danh mục',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildCategoryChip(
                  context,
                  'Nhà hàng',
                  Icons.restaurant,
                  'restaurant',
                ),
                _buildCategoryChip(context, 'Khách sạn', Icons.hotel, 'hotel'),
                _buildCategoryChip(
                  context,
                  'Tham quan',
                  Icons.camera_alt,
                  'tourism',
                ),
                _buildCategoryChip(context, 'Cà phê', Icons.coffee, 'cafe'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(
    BuildContext context,
    String label,
    IconData icon,
    String searchKey,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final searchProvider = Provider.of<SearchProvider>(context, listen: false);

    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            // 1. Chuyển sang Tab Khám phá (Index 1)
            appProvider.setTab(1);

            // 2. Gọi hàm lọc theo danh mục
            // Hàm này sẽ tự động fetch địa điểm gần đây và lọc theo category
            searchProvider.filterByCategory(searchKey);
          },
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(icon, color: colorScheme.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
