import 'package:flutter/material.dart';

import '../widgets/ai_hero_card.dart';
import '../widgets/home_header.dart';
import '../widgets/location_list.dart';
import '../widgets/search_bar.dart';
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
            return;
          },
          child: const CustomScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            slivers: [
              HomeHeader(),
              HomeSearchBar(),
              AIHeroCard(),
              LocationList(title: 'Điểm đến phổ biến'),
              TripSummary(),
              SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
          ),
        ),
      ),
    );
  }
}
