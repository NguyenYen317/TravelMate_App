import 'package:flutter/material.dart';

import 'travel_social_feed_tab.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nhật ký cộng đồng')),
      body: const TravelSocialFeedTab(),
    );
  }
}
