import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
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
  final ImagePicker _imagePicker = ImagePicker();
  bool _initialized = false;
  bool _showOnlyMine = false;
  XFile? _selectedImage;

  @override
  void dispose() {
    _postCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPostImage(ImageSource source) async {
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (!mounted || image == null) {
        return;
      }
      setState(() {
        _selectedImage = image;
      });
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể chọn ảnh: ${error.message ?? error.code}')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể chọn ảnh. Vui lòng thử lại.')),
      );
    }
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
                            label: const Text('Tất cả bài đăng'),
                            selected: !_showOnlyMine,
                            onSelected: (_) {
                              setState(() {
                                _showOnlyMine = false;
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Bài của tôi'),
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
                final canManage = user != null && post.userId == user.id;
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
                          content: Text('Hãy đăng nhập để bình luận.'),
                        ),
                      );
                      return;
                    }
                    _openCommentsSheet(post, user, socialProvider);
                  },
                  onEditTap: canManage
                      ? () => _showEditPostSheet(post, user!, socialProvider)
                      : null,
                  onDeleteTap: canManage
                      ? () => _confirmDeletePost(post, user!, socialProvider)
                      : null,
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
          child: Text('Đăng nhập để đăng bài trong Nhật ký cộng đồng.'),
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
              'Đăng bài mới',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _postCtrl,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Viết cảm nhận về chuyến đi...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            if (_selectedImage != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Image(
                      image: ResizeImage(
                        FileImage(File(_selectedImage!.path)),
                        width: 1080,
                      ),
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) {
                        return const SizedBox(
                          height: 180,
                          child: Center(child: Text('Không tải được ảnh xem trước')),
                        );
                      },
                    ),
                    IconButton.filled(
                      onPressed: () {
                        setState(() {
                          _selectedImage = null;
                        });
                      },
                      icon: const Icon(Icons.close),
                      tooltip: 'Bỏ ảnh',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                IconButton(
                  onPressed: provider.isCreatingPost
                      ? null
                      : () => _pickPostImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  tooltip: 'Chọn ảnh từ thư viện',
                ),
                IconButton(
                  onPressed: provider.isCreatingPost
                      ? null
                      : () => _pickPostImage(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  tooltip: 'Chụp ảnh',
                ),
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
                              imageFile: _selectedImage,
                            );
                            if (!mounted) {
                              return;
                            }
                            _postCtrl.clear();
                            setState(() {
                              _selectedImage = null;
                            });
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Đăng bài thành công.'),
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
                      : const Text('Đăng bài'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openCommentsSheet(SocialPost post, AuthUser user, SocialProvider provider) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _CommentSheet(
        post: post,
        user: user,
        provider: provider,
      ),
    );
  }

  void _showEditPostSheet(SocialPost post, AuthUser user, SocialProvider provider) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _EditPostSheet(
        post: post,
        user: user,
        provider: provider,
      ),
    );
  }

  Future<void> _confirmDeletePost(
    SocialPost post,
    AuthUser user,
    SocialProvider provider,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Xóa bài viết'),
          content: const Text('Bạn chắc chắn muốn xóa bài viết này?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await provider.deletePost(postId: post.id, user: user);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa bài viết.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  static String _fmtDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }
}

class _CommentSheet extends StatefulWidget {
  final SocialPost post;
  final AuthUser user;
  final SocialProvider provider;

  const _CommentSheet({
    required this.post,
    required this.user,
    required this.provider,
  });

  @override
  State<_CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<_CommentSheet> {
  late final TextEditingController _controller;
  late final Stream<List<SocialComment>> _stream;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _stream = widget.provider.watchComments(widget.post.id);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bình luận cộng đồng',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: StreamBuilder<List<SocialComment>>(
                  stream: _stream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final items = snapshot.data ?? const [];
                    if (items.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: Text('Chưa có bình luận.')),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(height: 8),
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
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Viết bình luận...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () async {
                      final text = _controller.text.trim();
                      if (text.isEmpty) return;
                      FocusScope.of(context).unfocus();
                      try {
                        await widget.provider.addComment(
                          postId: widget.post.id,
                          user: widget.user,
                          text: text,
                        );
                        if (mounted) _controller.clear();
                      } catch (error) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error.toString())),
                          );
                        }
                      }
                    },
                    child: const Text('Gửi'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }
}

class _EditPostSheet extends StatefulWidget {
  final SocialPost post;
  final AuthUser user;
  final SocialProvider provider;

  const _EditPostSheet({
    required this.post,
    required this.user,
    required this.provider,
  });

  @override
  State<_EditPostSheet> createState() => _EditPostSheetState();
}

class _EditPostSheetState extends State<_EditPostSheet> {
  late final TextEditingController _contentCtrl;
  final ImagePicker _imagePicker = ImagePicker();
  bool _removeImage = false;
  XFile? _replacementImage;

  @override
  void initState() {
    super.initState();
    _contentCtrl = TextEditingController(text: widget.post.content);
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chỉnh sửa bài viết',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _contentCtrl,
                minLines: 2,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: 'Nhập nội dung...',
                  border: OutlineInputBorder(),
                ),
              ),
              if (widget.post.imageUrl != null && widget.post.imageUrl!.isNotEmpty) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Xóa ảnh hiện tại'),
                  value: _removeImage,
                  onChanged: (value) {
                    setState(() {
                      _removeImage = value;
                      if (value) _replacementImage = null;
                    });
                  },
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await _imagePicker.pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 75,
                        maxWidth: 1280,
                        maxHeight: 1280,
                      );
                      if (picked == null) return;
                      setState(() {
                        _replacementImage = picked;
                        _removeImage = false;
                      });
                    },
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(
                      widget.post.imageUrl == null || widget.post.imageUrl!.isEmpty
                          ? 'Thêm ảnh'
                          : 'Đổi ảnh',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await _imagePicker.pickImage(
                        source: ImageSource.camera,
                        imageQuality: 75,
                        maxWidth: 1280,
                        maxHeight: 1280,
                      );
                      if (picked == null) return;
                      setState(() {
                        _replacementImage = picked;
                        _removeImage = false;
                      });
                    },
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Chụp mới'),
                  ),
                  if (_replacementImage != null)
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _replacementImage = null),
                      icon: const Icon(Icons.close),
                      label: const Text('Bỏ ảnh mới'),
                    ),
                ],
              ),
              if (_removeImage && widget.post.imageUrl != null && widget.post.imageUrl!.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  'Ảnh hiện tại sẽ bị xóa khi lưu thay đổi.',
                  style: TextStyle(fontSize: 12, color: Colors.red),
                ),
              ],
              if (_replacementImage == null && !_removeImage && widget.post.imageUrl != null && widget.post.imageUrl!.isNotEmpty) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    widget.post.imageUrl!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
              if (_replacementImage != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image(
                    image: ResizeImage(
                      FileImage(File(_replacementImage!.path)),
                      width: 1080,
                    ),
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    FocusScope.of(context).unfocus();
                    try {
                      await widget.provider.updatePost(
                        postId: widget.post.id,
                        user: widget.user,
                        content: _contentCtrl.text,
                        imageFile: _replacementImage,
                        removeImage: _removeImage,
                      );
                      if (mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã cập nhật bài viết.')),
                        );
                      }
                    } catch (error) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error.toString())),
                        );
                      }
                    }
                  },
                  child: const Text('Lưu thay đổi'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialPostCard extends StatelessWidget {
  const _SocialPostCard({
    required this.post,
    required this.isLikedByMe,
    required this.onLikeTap,
    required this.onCommentTap,
    this.onEditTap,
    this.onDeleteTap,
  });

  final SocialPost post;
  final bool isLikedByMe;
  final VoidCallback? onLikeTap;
  final VoidCallback onCommentTap;
  final VoidCallback? onEditTap;
  final VoidCallback? onDeleteTap;

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
                if (onEditTap != null || onDeleteTap != null)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        onEditTap?.call();
                      } else if (value == 'delete') {
                        onDeleteTap?.call();
                      }
                    },
                    itemBuilder: (context) => [
                      if (onEditTap != null)
                        const PopupMenuItem<String>(
                          value: 'edit',
                          child: Text('Sửa bài viết'),
                        ),
                      if (onDeleteTap != null)
                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: Text('Xóa bài viết'),
                        ),
                    ],
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
                    child: const Text('Không tải được ảnh'),
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
