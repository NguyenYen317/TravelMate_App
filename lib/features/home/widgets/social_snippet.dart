import 'package:flutter/material.dart';

class SocialSnippet extends StatelessWidget {
  const SocialSnippet({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          return _buildSocialCard(context);
        }, childCount: 3),
      ),
    );
  }

  Widget _buildSocialCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Container(
              height: 180,
              width: double.infinity,
              color: colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.image_outlined,
                color: colorScheme.onSurfaceVariant,
                size: 50,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kinh nghiệm du lịch Đà Lạt tự túc 4 ngày 3 đêm...',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    CircleAvatar(radius: 10, backgroundColor: Colors.blue[100]),
                    const SizedBox(width: 8),
                    const Text(
                      'Hoàng Nam',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.favorite_border,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const Text(' 12', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
