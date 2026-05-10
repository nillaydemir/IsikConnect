import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/forum_post_model.dart';
import '../models/forum_comment_model.dart';
import '../../../core/services/current_session.dart';

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
        print('Error refreshing posts: $e');
      }
    }

    // Initial fetch
    refresh();

    // Listen to changes in posts, likes, and comments to keep the feed perfectly synced
    final postsSub = _supabase.from('forum_posts').stream(primaryKey: ['id']).listen((_) => refresh());
    final likesSub = _supabase.from('forum_likes').stream(primaryKey: ['post_id', 'user_id']).listen((_) => refresh());
    final commentsSub = _supabase.from('forum_comments').stream(primaryKey: ['id']).listen((_) => refresh());

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
    await _supabase.from('forum_read_posts').upsert({
      'post_id': postId,
      'user_id': _currentUserId,
    });
  }

  // --- Get Unread Count Stream ---
  Stream<int> getUnreadCountStream() {
    final StreamController<int> controller = StreamController<int>.broadcast();
    
    Future<void> updateCount() async {
      try {
        final allPosts = await fetchPosts(null);
        final readResponse = await _supabase
            .from('forum_read_posts')
            .select('post_id')
            .eq('user_id', _currentUserId);
        
        final readPostIds = (readResponse as List).map((e) => e['post_id'] as String).toSet();
        final unreadCount = allPosts.where((post) => !readPostIds.contains(post.id)).length;
        if (!controller.isClosed) {
          controller.add(unreadCount);
        }
      } catch (e) {
        print('Error updating unread count: $e');
      }
    }

    // Initial update
    updateCount();

    // Listen for new posts
    final postsSubscription = _supabase
        .from('forum_posts')
        .stream(primaryKey: ['id'])
        .listen((_) => updateCount());

    // Listen for read status changes
    final readSubscription = _supabase
        .from('forum_read_posts')
        .stream(primaryKey: ['user_id', 'post_id'])
        .eq('user_id', _currentUserId)
        .listen((_) => updateCount());

    controller.onCancel = () {
      postsSubscription.cancel();
      readSubscription.cancel();
      controller.close();
    };

    return controller.stream;
  }

  // Fallback Future method since Stream with deep joins in Supabase Flutter can sometimes be limited
  Future<List<ForumPost>> fetchPosts(String? category) async {
    var query = _supabase
        .from('forum_posts')
        .select('''
          *,
          users!author_id(first_name, last_name, role, profile_image_url),
          forum_likes(user_id),
          forum_comments(id),
          forum_bookmarks(user_id),
          forum_workshop_participants(user_id)
        ''');

    if (category != null) {
      query = query.eq('category', category);
    }

    final response = await query.order('created_at', ascending: false);

    return (response as List).map((json) => ForumPost.fromJson(json, _currentUserId)).toList();
  }

  // --- Fetch Comments ---
  Future<List<ForumComment>> fetchComments(String postId) async {
    final response = await _supabase
        .from('forum_comments')
        .select('*, users!author_id(first_name, last_name, role, profile_image_url)')
        .eq('post_id', postId)
        .order('created_at', ascending: true);

    return (response as List).map((json) => ForumComment.fromJson(json)).toList();
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
    await _supabase.from('forum_posts').insert({
      'author_id': _currentUserId,
      'category': category,
      'title': title,
      'content': content,
      'image_url': imageUrl,
      'tags': tags,
      'event_date': eventDate?.toIso8601String(),
      'meeting_link': meetingLink,
      'participant_limit': participantLimit,
    });
  }

  // --- Create Comment ---
  Future<void> addComment(String postId, String content) async {
    await _supabase.from('forum_comments').insert({
      'post_id': postId,
      'author_id': _currentUserId,
      'content': content,
    });
  }

  // --- Like / Unlike ---
  Future<void> toggleLike(String postId, bool isCurrentlyLiked) async {
    try {
      if (isCurrentlyLiked) {
        await _supabase
            .from('forum_likes')
            .delete()
            .match({'post_id': postId, 'user_id': _currentUserId});
      } else {
        await _supabase
            .from('forum_likes')
            .upsert({'post_id': postId, 'user_id': _currentUserId});
      }
    } catch (e) {
      print('Toggle like error: $e');
    }
  }

  // --- Bookmark / Unbookmark ---
  Future<void> toggleBookmark(String postId, bool isCurrentlyBookmarked) async {
    if (isCurrentlyBookmarked) {
      await _supabase
          .from('forum_bookmarks')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', _currentUserId);
    } else {
      await _supabase
          .from('forum_bookmarks')
          .insert({'post_id': postId, 'user_id': _currentUserId});
    }
  }

  // --- Workshop Join / Leave ---
  Future<void> toggleWorkshopParticipation(String postId, bool isCurrentlyParticipating) async {
    if (isCurrentlyParticipating) {
      await _supabase
          .from('forum_workshop_participants')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', _currentUserId);
    } else {
      await _supabase
          .from('forum_workshop_participants')
          .insert({'post_id': postId, 'user_id': _currentUserId});
    }
  }

  // --- Accept Answer (Q&A) ---
  Future<void> acceptAnswer(String postId, String commentId) async {
    // 1. Mark the post as solved
    await _supabase
        .from('forum_posts')
        .update({'is_solved': true, 'accepted_answer_id': commentId})
        .eq('id', postId)
        .eq('author_id', _currentUserId); // security: only author can mark

    // 2. Mark the comment as accepted
    await _supabase
        .from('forum_comments')
        .update({'is_accepted': true})
        .eq('id', commentId);
  }
}
