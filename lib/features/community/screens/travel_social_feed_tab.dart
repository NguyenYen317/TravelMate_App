import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/auth_service.dart';
import '../../auth/provider/auth_provider.dart';
import '../../social/models/social_models.dart';
import '../../social/providers/social_provider.dart';

class TravelSocialFeedTab extends StatefulWidget {
  const TravelSocialFeedTab({super.key});

  @override
  State<TravelSocialFeedTab> createState() => _TravelSocialFeedTabState();
}

class _TravelSocialFeedTabState extends State<TravelSocialFeedTab> {
  final TextEditingController _postCtrl = TextEditingController();
  bool _initialized = false;
  bool _showOnlyMine = false;

  @override
  void dispose() {
    _postCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, SocialProvider>(
      builder: (context, authProvider, socialProvider, _) {
        final user = authProvider.currentUser;

        if (!_initialized) {
          _initialized = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }
            context.read<SocialProvider>().loadInitial(userId: user?.id);
          });
        }

        final visiblePosts = _showOnlyMine && user != null
            ? socialProvider.posts
                  .where((item) => item.userId == user.id)
                  .toList()
            : socialProvider.posts;

        return RefreshIndicator(
          onRefresh: () => socialProvider.loadInitial(userId: user?.id),
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.pixels >=
                  notification.metrics.maxScrollExtent - 240) {
                socialProvider.loadMore(userId: user?.id);
              }
              return false;
            },
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
              itemCount:
                  1 +
                  visiblePosts.length +
                  (socialProvider.isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildComposer(context, socialProvider, user),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Tat ca bai dang'),
                            selected: !_showOnlyMine,
                            onSelected: (_) {
                              setState(() {
                                _showOnlyMine = false;
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Bai cua toi'),
                            selected: _showOnlyMine,
                            onSelected: user == null
                                ? null
                                : (_) {
                                    setState(() {
                                      _showOnlyMine = true;
                                    });
                                  },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  );
                }

                final adjustedIndex = index - 1;

                if (adjustedIndex >= visiblePosts.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final post = visiblePosts[adjustedIndex];
                return _SocialPostCard(
                  post: post,
                  isLikedByMe: socialProvider.isLikedByMe(post.id),
                  onLikeTap: user == null
                      ? null
                      : () => socialProvider.toggleLike(
                          postId: post.id,
                          user: user,
                        ),
                  onCommentTap: () {
                    if (user == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Hay dang nhap de binh luan.'),
                        ),
                      );
                      return;
                    }
                    _openCommentsSheet(post, user);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildComposer(
    BuildContext context,
    SocialProvider provider,
    AuthUser? user,
  ) {
    if (user == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text('Dang nhap de dang bai trong Nhat ky Cong dong.'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dang bai moi',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _postCtrl,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Viet cam nhan ve chuyen di...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Spacer(),
                FilledButton(
                  onPressed: provider.isCreatingPost
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await provider.createPost(
                              user: user,
                              content: _postCtrl.text,
                              imageFile: null,
                            );
                            if (!mounted) {
                              return;
                            }
                            _postCtrl.clear();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Dang bai thanh cong.'),
                              ),
                            );
                          } catch (error) {
                            if (!mounted) {
                              return;
                            }
                            messenger.showSnackBar(
                              SnackBar(content: Text(error.toString())),
                            );
                          }
                        },
                  child: provider.isCreatingPost
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Dang bai'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCommentsSheet(SocialPost post, AuthUser user) async {
    final controller = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return Consumer<SocialProvider>(
          builder: (context, provider, _) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 12,
              ),
              child: SizedBox(
                height: MediaQuery.of(sheetContext).size.height * 0.7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Binh luan cong dong',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: StreamBuilder<List<SocialComment>>(
                        stream: provider.watchComments(post.id),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final items =
                              snapshot.data ?? const <SocialComment>[];
                          if (items.isEmpty) {
                            return const Center(
                              child: Text('Chua co binh luan.'),
                            );
                          }

                          return ListView.separated(
                            itemCount: items.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 8),
                            itemBuilder: (context, index) {
                              final item = items[index];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(item.userName),
                                subtitle: Text(item.text),
                                trailing: Text(
                                  _fmtDate(item.createdAt),
                                  style: const TextStyle(fontSize: 11),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            decoration: const InputDecoration(
                              hintText: 'Viet binh luan...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () async {
                            final text = controller.text.trim();
                            if (text.isEmpty) {
                              return;
                            }
                            await provider.addComment(
                              postId: post.id,
                              user: user,
                              text: text,
                            );
                            controller.clear();
                          },
                          child: const Text('Gui'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    controller.dispose();
  }

  String _fmtDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }
}

class _SocialPostCard extends StatelessWidget {
  const _SocialPostCard({
    required this.post,
    required this.isLikedByMe,
    required this.onLikeTap,
    required this.onCommentTap,
  });

  final SocialPost post;
  final bool isLikedByMe;
  final VoidCallback? onLikeTap;
  final VoidCallback onCommentTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: post.userAvatar != null
                      ? NetworkImage(post.userAvatar!)
                      : null,
                  child: post.userAvatar == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    post.userName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  _fmtDate(post.createdAt),
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
            if (post.content.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(post.content),
            ],
            if (post.imageUrl != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  post.imageUrl!,
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    height: 120,
                    alignment: Alignment.center,
                    color: Colors.black12,
                    child: const Text('Khong tai duoc anh'),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: onLikeTap,
                  icon: Icon(
                    isLikedByMe ? Icons.favorite : Icons.favorite_border,
                    color: isLikedByMe ? Colors.red : null,
                  ),
                ),
                Text('${post.likeCount}'),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onCommentTap,
                  icon: const Icon(Icons.mode_comment_outlined),
                ),
                Text('${post.commentCount}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _fmtDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }
}
