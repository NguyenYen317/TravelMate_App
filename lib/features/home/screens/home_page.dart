import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../search/provider/search_provider.dart';
import '../widgets/home_header.dart';
import '../widgets/search_bar.dart';
import '../widgets/ai_hero_card.dart';
import '../widgets/location_list.dart';
import '../widgets/trip_summary.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            // No-op refresh for static "Điểm đến phổ biến" section
            return;
          },
          child: const CustomScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            slivers: [
              HomeHeader(),
              HomeSearchBar(),
              AIHeroCard(),
              LocationList(title: 'Điểm đến phổ biến'),
              // CategoryList đã được xóa theo yêu cầu
              TripSummary(),
              SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
          ),
        ),
      ),
    );
  }
}
