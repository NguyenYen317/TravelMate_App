import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../search/provider/search_provider.dart';
import '../widgets/home_header.dart';
import '../widgets/search_bar.dart';
import '../widgets/ai_hero_card.dart';
import '../widgets/location_list.dart';
import '../widgets/category_list.dart';
import '../widgets/trip_summary.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final searchProvider = Provider.of<SearchProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            // Cập nhật lại vị trí GPS và địa điểm gần đây
            await searchProvider.fetchNearbyPlaces();
          },
          child: CustomScrollView(
            physics:
                const AlwaysScrollableScrollPhysics(), // Đảm bảo luôn có thể kéo để refresh
            slivers: [
              const HomeHeader(),
              const HomeSearchBar(),
              const AIHeroCard(),
              const LocationList(title: 'Địa điểm gần bạn'),
              const CategoryList(),
              const TripSummary(),
              // 'Cộng đồng du lịch' section removed per request
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
          ),
        ),
      ),
    );
  }
}
