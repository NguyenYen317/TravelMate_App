import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_provider.dart';

class HomeSearchBar extends StatelessWidget {
  const HomeSearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final appProvider = Provider.of<AppProvider>(context, listen: false);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          elevation: 0,
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: () {
              // THAY ĐỔI CHÍNH: Thay vì push trang mới, chúng ta chuyển Tab ngay tại MainScreen
              appProvider.setTab(1); // Chuyển sang Tab "Khám phá" (Index 1)
            },
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: colorScheme.primary),
                  const SizedBox(width: 10),
                  Text(
                    'Tìm kiếm điểm đến...',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.tune,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
