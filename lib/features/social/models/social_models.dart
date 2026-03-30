import 'package:cloud_firestore/cloud_firestore.dart';

class SocialPost {
  SocialPost({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.content,
    this.imageUrl,
    required this.likeCount,
    required this.commentCount,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String content;
  final String? imageUrl;
  final int likeCount;
  final int commentCount;
  final DateTime createdAt;

  factory SocialPost.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return SocialPost(
      id: doc.id,
      userId: (data['userId'] ?? '').toString(),
      userName: (data['userName'] ?? 'Ẩn danh').toString(),
      userAvatar: _asNullableString(data['userAvatar']),
      content: (data['content'] ?? '').toString(),
      imageUrl: _asNullableString(data['imageUrl']),
      likeCount: _asInt(data['likeCount']),
      commentCount: _asInt(data['commentCount']),
      createdAt: _asDateTime(data['createdAt']),
    );
  }

  SocialPost copyWith({int? likeCount, int? commentCount}) {
    return SocialPost(
      id: id,
      userId: userId,
      userName: userName,
      userAvatar: userAvatar,
      content: content,
      imageUrl: imageUrl,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      createdAt: createdAt,
    );
  }
}

class SocialComment {
  SocialComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String postId;
  final String userId;
  final String userName;
  final String text;
  final DateTime createdAt;

  factory SocialComment.fromDoc(
    String postId,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return SocialComment(
      id: doc.id,
      postId: postId,
      userId: (data['userId'] ?? '').toString(),
      userName: (data['userName'] ?? 'Ẩn danh').toString(),
      text: (data['text'] ?? '').toString(),
      createdAt: _asDateTime(data['createdAt']),
    );
  }
}

class SocialPostPage {
  SocialPostPage({
    required this.posts,
    required this.lastDoc,
    required this.hasMore,
  });

  final List<SocialPost> posts;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  final bool hasMore;
}

int _asInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse((value ?? '0').toString()) ?? 0;
}

String? _asNullableString(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    return null;
  }
  return text;
}

DateTime _asDateTime(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  return DateTime.now();
}
