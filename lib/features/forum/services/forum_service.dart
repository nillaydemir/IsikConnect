import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/forum_post_model.dart';
import '../models/forum_comment_model.dart';
import '../../../core/services/current_session.dart';
import '../../../core/services/api_service.dart';

class ForumService {
  final _supabase = Supabase.instance.client;

  String get _currentUserId {
    final id = CurrentSession().user?.id;
    if (id == null) throw Exception('User not logged in');
    return id;
  }

  // --- Fetch Posts ---
  Stream<List<ForumPost>> getPostsStream(String? category) {
    final StreamController<List<ForumPost>> controller = StreamController<List<ForumPost>>.broadcast();

    Future<void> refresh() async {
      try {
        final posts = await fetchPosts(category);
        if (!controller.isClosed) {
          controller.add(posts);
        }
      } catch (e) {
        debugPrint('Error refreshing posts: $e');
      }
    }

    // Initial fetch
    refresh();

    // Listen to changes in posts, likes, and comments to keep the feed perfectly synced
    final postsSub = _supabase.from('forum_posts').stream(primaryKey: ['id']).listen(
      (_) => refresh(),
      onError: (e) => debugPrint('Realtime sub error (forum_posts): $e'),
    );
    final likesSub = _supabase.from('forum_likes').stream(primaryKey: ['post_id', 'user_id']).listen(
      (_) => refresh(),
      onError: (e) => debugPrint('Realtime sub error (forum_likes): $e'),
    );
    final commentsSub = _supabase.from('forum_comments').stream(primaryKey: ['id']).listen(
      (_) => refresh(),
      onError: (e) => debugPrint('Realtime sub error (forum_comments): $e'),
    );

    controller.onCancel = () {
      postsSub.cancel();
      likesSub.cancel();
      commentsSub.cancel();
      controller.close();
    };

    return controller.stream.cast<List<ForumPost>>();
  }

  Stream<List<ForumPost>> getAllPostsStream() => getPostsStream(null);

  // --- Mark as Read ---
  Future<void> markAsRead(String postId) async {
    try {
      await ApiService().markPostAsRead(postId);
    } catch (e) {
      debugPrint('Error marking post as read: $e');
    }
  }

  // --- Get Unread Posts Stream ---
  Stream<List<ForumPost>> getUnreadPostsStream() {
    final StreamController<List<ForumPost>> controller = StreamController<List<ForumPost>>.broadcast();

    Future<void> updatePosts() async {
      try {
        final allPosts = await fetchPosts(null);
        final readPostIds = (await ApiService().fetchReadPostIds()).toSet();
        final userCreatedAt = CurrentSession().user?.createdAt;
        final unreadPosts = allPosts.where((post) {
          final isRead = readPostIds.contains(post.id);
          final isAfterRegistration = userCreatedAt == null || post.createdAt.isAfter(userCreatedAt);
          return !isRead && isAfterRegistration;
        }).toList();
        if (!controller.isClosed) {
          controller.add(unreadPosts);
        }
      } catch (e) {
        debugPrint('Error updating unread posts: $e');
      }
    }

    // Initial update
    updatePosts();

    // Listen for new posts
    final postsSubscription = _supabase
        .from('forum_posts')
        .stream(primaryKey: ['id'])
        .listen(
          (_) => updatePosts(),
          onError: (e) => debugPrint('Realtime sub error (forum_posts): $e'),
        );

    // Listen for read status changes
    final readSubscription = _supabase
        .from('forum_read_posts')
        .stream(primaryKey: ['user_id', 'post_id'])
        .eq('user_id', _currentUserId)
        .listen(
          (_) => updatePosts(),
          onError: (e) => debugPrint('Realtime sub error (forum_read_posts): $e'),
        );

    controller.onCancel = () {
      postsSubscription.cancel();
      readSubscription.cancel();
      controller.close();
    };

    return controller.stream;
  }

  // --- Get Unread Count Stream ---
  Stream<int> getUnreadCountStream() {
    final StreamController<int> controller = StreamController<int>.broadcast();
    
    Future<void> updateCount() async {
      try {
        final allPosts = await fetchPosts(null);
        final readPostIds = (await ApiService().fetchReadPostIds()).toSet();
        final userCreatedAt = CurrentSession().user?.createdAt;
        final unreadCount = allPosts.where((post) {
          final isRead = readPostIds.contains(post.id);
          final isAfterRegistration = userCreatedAt == null || post.createdAt.isAfter(userCreatedAt);
          return !isRead && isAfterRegistration;
        }).length;
        if (!controller.isClosed) {
          controller.add(unreadCount);
        }
      } catch (e) {
        debugPrint('Error updating unread count: $e');
      }
    }

    // Initial update
    updateCount();

    // Listen for new posts
    final postsSubscription = _supabase
        .from('forum_posts')
        .stream(primaryKey: ['id'])
        .listen(
          (_) => updateCount(),
          onError: (e) => debugPrint('Realtime sub error (forum_posts): $e'),
        );

    // Listen for read status changes
    final readSubscription = _supabase
        .from('forum_read_posts')
        .stream(primaryKey: ['user_id', 'post_id'])
        .eq('user_id', _currentUserId)
        .listen(
          (_) => updateCount(),
          onError: (e) => debugPrint('Realtime sub error (forum_read_posts): $e'),
        );

    controller.onCancel = () {
      postsSubscription.cancel();
      readSubscription.cancel();
      controller.close();
    };

    return controller.stream;
  }

  // Fallback Future method since Stream with deep joins in Supabase Flutter can sometimes be limited
  Future<List<ForumPost>> fetchPosts(String? category) async {
    try {
      final List<Map<String, dynamic>> response = await ApiService().fetchPosts(category);
      return response.map((json) => ForumPost.fromJson(json, _currentUserId)).toList();
    } catch (e) {
      debugPrint('Error fetching posts: $e');
      rethrow;
    }
  }

  // --- Fetch Comments ---
  Future<List<ForumComment>> fetchComments(String postId) async {
    try {
      final List<Map<String, dynamic>> response = await ApiService().fetchComments(postId);
      return response.map((json) => ForumComment.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching comments: $e');
      rethrow;
    }
  }

  // --- Create Post ---
  Future<void> createPost({
    required String category,
    required String title,
    required String content,
    String? imageUrl,
    List<String> tags = const [],
    DateTime? eventDate,
    String? meetingLink,
    int? participantLimit,
  }) async {
    try {
      await ApiService().createPost(
        category: category,
        title: title,
        content: content,
        imageUrl: imageUrl,
        tags: tags,
        eventDate: eventDate?.toIso8601String(),
        meetingLink: meetingLink,
        participantLimit: participantLimit,
      );
    } catch (e) {
      debugPrint('Error creating post: $e');
      rethrow;
    }
  }

  // --- Create Comment ---
  Future<void> addComment(String postId, String content) async {
    try {
      await ApiService().addComment(postId, content);
    } catch (e) {
      debugPrint('Error adding comment: $e');
      rethrow;
    }
  }

  // --- Like / Unlike ---
  Future<void> toggleLike(String postId, bool isCurrentlyLiked) async {
    try {
      await ApiService().toggleLike(postId, isCurrentlyLiked);
    } catch (e) {
      debugPrint('Toggle like error: $e');
      rethrow;
    }
  }

  // --- Accept Answer (Q&A) ---
  Future<void> acceptAnswer(String postId, String commentId) async {
    try {
      await ApiService().acceptAnswer(postId, commentId);
    } catch (e) {
      debugPrint('Accept answer error: $e');
      rethrow;
    }
  }

  // --- Delete Post ---
  Future<void> deletePost(String postId, {bool isAdmin = false}) async {
    try {
      await ApiService().deletePost(postId);
    } catch (e) {
      debugPrint('Error deleting post: $e');
      rethrow;
    }
  }

  // --- Delete Comment ---
  Future<void> deleteComment(String commentId, {bool isAdmin = false}) async {
    try {
      await ApiService().deleteComment(commentId);
    } catch (e) {
      debugPrint('Error deleting comment: $e');
      rethrow;
    }
  }

  // --- Update Post ---
  Future<void> updatePost({
    required String postId,
    required String category,
    required String title,
    required String content,
    String? imageUrl,
    String? meetingLink,
    DateTime? eventDate,
  }) async {
    try {
      await ApiService().updatePost(
        postId: postId,
        category: category,
        title: title,
        content: content,
        imageUrl: imageUrl,
        meetingLink: meetingLink,
        eventDate: eventDate?.toIso8601String(),
      );
    } catch (e) {
      debugPrint('Error updating post: $e');
      rethrow;
    }
  }
}
