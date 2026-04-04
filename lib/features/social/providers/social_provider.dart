import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/auth_service.dart';
import '../models/social_models.dart';
import '../services/social_service.dart';

class SocialProvider extends ChangeNotifier {
  SocialProvider({SocialService? socialService})
    : _socialService = socialService ?? SocialService();

  final SocialService _socialService;

  final List<SocialPost> _posts = [];
  final Map<String, bool> _likedByMe = {};

  bool _isInitialLoading = false;
  bool _isCreatingPost = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;

  List<SocialPost> get posts => List.unmodifiable(_posts);
  bool get isInitialLoading => _isInitialLoading;
  bool get isCreatingPost => _isCreatingPost;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;

  bool isLikedByMe(String postId) => _likedByMe[postId] ?? false;

  Stream<List<SocialComment>> watchComments(String postId) {
    return _socialService.watchComments(postId);
  }

  Future<void> loadInitial({String? userId}) async {
    _isInitialLoading = true;
    _error = null;
    notifyListeners();

    try {
      final page = await _socialService.fetchPosts(limit: 10);
      _posts
        ..clear()
        ..addAll(page.posts);
      _lastDoc = page.lastDoc;
      _hasMore = page.hasMore;

      _likedByMe.clear();
      if (userId != null && userId.isNotEmpty) {
        await _hydrateLikedStatus(userId);
      }
    } catch (error) {
      _error = error.toString();
    } finally {
      _isInitialLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore({String? userId}) async {
    if (_isLoadingMore || !_hasMore) {
      return;
    }

    _isLoadingMore = true;
    notifyListeners();

    try {
      final page = await _socialService.fetchPosts(
        startAfter: _lastDoc,
        limit: 10,
      );
      _posts.addAll(page.posts);
      _lastDoc = page.lastDoc;
      _hasMore = page.hasMore;

      if (userId != null && userId.isNotEmpty) {
        await _hydrateLikedStatus(userId);
      }
    } catch (error) {
      _error = error.toString();
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> createPost({
    required AuthUser user,
    required String content,
    XFile? imageFile,
  }) async {
    _isCreatingPost = true;
    _error = null;
    notifyListeners();

    try {
      final post = await _socialService.createPost(
        user: user,
        content: content,
        imageFile: imageFile,
      );
      _posts.insert(0, post);
      _likedByMe[post.id] = false;
    } catch (error) {
      _error = error.toString();
      rethrow;
    } finally {
      _isCreatingPost = false;
      notifyListeners();
    }
  }

  Future<void> toggleLike({
    required String postId,
    required AuthUser user,
  }) async {
    final index = _posts.indexWhere((post) => post.id == postId);
    if (index < 0) {
      return;
    }

    final currentLiked = _likedByMe[postId] ?? false;
    final current = _posts[index];

    _likedByMe[postId] = !currentLiked;
    _posts[index] = current.copyWith(
      likeCount: current.likeCount + (currentLiked ? -1 : 1),
    );
    notifyListeners();

    try {
      final actualLiked = await _socialService.toggleLike(
        postId: postId,
        user: user,
      );
      _likedByMe[postId] = actualLiked;
    } catch (_) {
      _likedByMe[postId] = currentLiked;
      _posts[index] = current;
    }

    notifyListeners();
  }

  Future<void> addComment({
    required String postId,
    required AuthUser user,
    required String text,
  }) async {
    await _socialService.addComment(postId: postId, user: user, text: text);

    final index = _posts.indexWhere((post) => post.id == postId);
    if (index < 0) {
      return;
    }

    final current = _posts[index];
    _posts[index] = current.copyWith(commentCount: current.commentCount + 1);
    notifyListeners();
  }

  Future<void> _hydrateLikedStatus(String userId) async {
    final futures = _posts.map((post) async {
      final liked = await _socialService.hasUserLiked(
        postId: post.id,
        userId: userId,
      );
      _likedByMe[post.id] = liked;
    }).toList();

    await Future.wait(futures);
  }
}
