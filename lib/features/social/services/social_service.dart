import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/auth_service.dart';
import '../models/social_models.dart';

class SocialService {
  SocialService({FirebaseFirestore? firestore, FirebaseStorage? storage})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

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
      imageUrl = await _uploadPostImage(imageFile, user.id);
    }

    final docRef = _postsRef.doc();
    await docRef.set({
      'userId': user.id,
      'userName': user.name,
      'userAvatar': user.avatarUrl,
      'content': normalizedContent,
      'imageUrl': imageUrl,
      'likeCount': 0,
      'commentCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });

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
    final bytes = await file.readAsBytes();
    final path =
        'social_posts/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage.ref().child(path);
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }
}
