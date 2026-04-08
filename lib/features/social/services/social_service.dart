import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../auth/auth_service.dart';
import '../models/social_models.dart';

class SocialService {
  SocialService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String _cloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
  );
  static const String _uploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
  );
  static const String _defaultUploadPreset = 'travelmate_app';
  static const String _postImageFolder = 'travelmate/images';

  static const Duration _uploadTimeout = Duration(seconds: 20);
  static const Duration _writeTimeout = Duration(seconds: 15);

  CollectionReference<Map<String, dynamic>> get _postsRef =>
      _firestore.collection('social_posts');

  Future<SocialPostPage> fetchPosts({
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 10,
  }) async {
    Query<Map<String, dynamic>> query = _postsRef
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    final posts = snapshot.docs.map(SocialPost.fromDoc).toList();

    return SocialPostPage(
      posts: posts,
      lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : startAfter,
      hasMore: snapshot.docs.length == limit,
    );
  }

  Future<SocialPost> createPost({
    required AuthUser user,
    required String content,
    XFile? imageFile,
  }) async {
    final normalizedContent = content.trim();
    if (normalizedContent.isEmpty && imageFile == null) {
      throw Exception('Nội dung bài viết đang trống.');
    }

    String? imageUrl;
    if (imageFile != null) {
      try {
        imageUrl = await _uploadPostImage(imageFile, user.id);
      } catch (_) {
        // Fallback: still allow posting text when image upload fails.
        if (normalizedContent.isEmpty) {
          throw Exception('Không thể tải ảnh lên. Vui lòng thử lại.');
        }
        imageUrl = null;
      }
    }

    final docRef = _postsRef.doc();
    await docRef
        .set({
          'userId': user.id,
          'userName': user.name,
          'userAvatar': user.avatarUrl,
          'content': normalizedContent,
          'imageUrl': imageUrl,
          'likeCount': 0,
          'commentCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
        })
        .timeout(_writeTimeout);

    return SocialPost(
      id: docRef.id,
      userId: user.id,
      userName: user.name,
      userAvatar: user.avatarUrl,
      content: normalizedContent,
      imageUrl: imageUrl,
      likeCount: 0,
      commentCount: 0,
      createdAt: DateTime.now(),
    );
  }

  Future<bool> toggleLike({
    required String postId,
    required AuthUser user,
  }) async {
    final postRef = _postsRef.doc(postId);
    final likeRef = postRef.collection('likes').doc(user.id);

    return _firestore.runTransaction<bool>((transaction) async {
      final likeSnapshot = await transaction.get(likeRef);
      if (likeSnapshot.exists) {
        transaction.delete(likeRef);
        transaction.update(postRef, {'likeCount': FieldValue.increment(-1)});
        return false;
      }

      transaction.set(likeRef, {
        'userId': user.id,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.update(postRef, {'likeCount': FieldValue.increment(1)});
      return true;
    });
  }

  Future<bool> hasUserLiked({
    required String postId,
    required String userId,
  }) async {
    final doc = await _postsRef
        .doc(postId)
        .collection('likes')
        .doc(userId)
        .get();
    return doc.exists;
  }

  Future<SocialPost> updatePost({
    required String postId,
    required AuthUser user,
    required String content,
    XFile? imageFile,
    bool removeImage = false,
  }) async {
    final normalizedContent = content.trim();
    if (normalizedContent.isEmpty && imageFile == null && removeImage) {
      throw Exception('Bài viết phải có nội dung hoặc ảnh.');
    }

    final docRef = _postsRef.doc(postId);
    final snapshot = await docRef.get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      throw Exception('Không tìm thấy bài viết.');
    }
    if ((data['userId'] ?? '').toString() != user.id) {
      throw Exception('Bạn không có quyền sửa bài viết này.');
    }

    String? imageUrl = (data['imageUrl'] ?? '').toString().trim();
    if (imageUrl.isEmpty) {
      imageUrl = null;
    }

    if (removeImage) {
      imageUrl = null;
    }
    if (imageFile != null) {
      imageUrl = await _uploadPostImage(imageFile, user.id);
    }

    if (normalizedContent.isEmpty && imageUrl == null) {
      throw Exception('Bài viết phải có nội dung hoặc ảnh.');
    }

    await docRef
        .update({
          'content': normalizedContent,
          'imageUrl': imageUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        })
        .timeout(_writeTimeout);

    return SocialPost(
      id: postId,
      userId: user.id,
      userName: (data['userName'] ?? user.name).toString(),
      userAvatar: (data['userAvatar'] ?? user.avatarUrl)?.toString(),
      content: normalizedContent,
      imageUrl: imageUrl,
      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Future<void> deletePost({
    required String postId,
    required AuthUser user,
  }) async {
    final postRef = _postsRef.doc(postId);
    final postSnapshot = await postRef.get();
    final postData = postSnapshot.data();
    if (!postSnapshot.exists || postData == null) {
      return;
    }
    if ((postData['userId'] ?? '').toString() != user.id) {
      throw Exception('Bạn không có quyền xóa bài viết này.');
    }

    await _deleteSubcollection(postRef, 'likes');
    await _deleteSubcollection(postRef, 'comments');
    await postRef.delete().timeout(_writeTimeout);
  }

  Stream<List<SocialComment>> watchComments(String postId) {
    return _postsRef
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SocialComment.fromDoc(postId, doc))
              .toList(),
        );
  }

  Future<void> addComment({
    required String postId,
    required AuthUser user,
    required String text,
  }) async {
    final normalized = text.trim();
    if (normalized.isEmpty) {
      throw Exception('Nội dung bình luận đang trống.');
    }

    final postRef = _postsRef.doc(postId);
    final commentRef = postRef.collection('comments').doc();

    await _firestore.runTransaction<void>((transaction) async {
      transaction.set(commentRef, {
        'userId': user.id,
        'userName': user.name,
        'text': normalized,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.update(postRef, {'commentCount': FieldValue.increment(1)});
    });
  }

  Future<String> _uploadPostImage(XFile file, String userId) async {
    final activeUploadPreset = _uploadPreset.isEmpty
        ? _defaultUploadPreset
        : _uploadPreset;
    if (_cloudName.isEmpty) {
      throw Exception('Thiếu cấu hình Cloudinary.');
    }

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
    );

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = activeUploadPreset
      ..fields['folder'] = _postImageFolder
      ..fields['public_id'] = '${userId}_${DateTime.now().millisecondsSinceEpoch}'
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final response = await request.send().timeout(_uploadTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Cloudinary upload failed: ${response.statusCode}');
    }

    final body = await response.stream.bytesToString();
    final secureUrlMatch = RegExp(
      r'"secure_url"\s*:\s*"([^"]+)"',
    ).firstMatch(body);
    final imageUrl = secureUrlMatch?.group(1);
    if (imageUrl == null || imageUrl.trim().isEmpty) {
      throw Exception('Cloudinary URL is empty');
    }
    return imageUrl;
  }

  Future<void> _deleteSubcollection(
    DocumentReference<Map<String, dynamic>> postRef,
    String name,
  ) async {
    final snapshots = await postRef.collection(name).get();
    if (snapshots.docs.isEmpty) {
      return;
    }
    final batch = _firestore.batch();
    for (final doc in snapshots.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
