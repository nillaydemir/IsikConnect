import 'forum_comment_model.dart';

class ForumPost {
  final String id;
  final String authorId;
  final String category; // 'Announcements', 'Q&A', 'Workshops'
  final String title;
  final String content;
  final String? imageUrl;
  final List<String> tags;
  final bool isSolved;
  final String? acceptedAnswerId;
  final DateTime createdAt;
  
  // Workshop specific
  final DateTime? eventDate;
  final String? meetingLink;
  final int? participantLimit;

  // Joined fields (from Supabase relations)
  final String authorName;
  final String authorRole;
  final String? authorProfileImageUrl;
  final int likeCount;
  final int commentCount;
  final int participantCount;
  final bool isLikedByMe;
  final bool isBookmarkedByMe;
  final bool isParticipating;

  ForumPost({
    required this.id,
    required this.authorId,
    required this.category,
    required this.title,
    required this.content,
    this.imageUrl,
    this.tags = const [],
    this.isSolved = false,
    this.acceptedAnswerId,
    required this.createdAt,
    this.eventDate,
    this.meetingLink,
    this.participantLimit,
    required this.authorName,
    required this.authorRole,
    this.authorProfileImageUrl,
    this.likeCount = 0,
    this.commentCount = 0,
    this.participantCount = 0,
    this.isLikedByMe = false,
    this.isBookmarkedByMe = false,
    this.isParticipating = false,
  });

  factory ForumPost.fromJson(Map<String, dynamic> json, String currentUserId) {
    // Safely extract joined author data
    final users = json['users'] as Map<String, dynamic>?;
    final String fName = users?['first_name'] ?? 'Unknown';
    final String lName = users?['last_name'] ?? 'User';
    final String name = '$fName $lName'.trim();
    final String role = users?['role'] ?? 'student';
    final String? profileImage = users?['profile_image_url'];

    // Handle counts and relations
    final likesList = (json['forum_likes'] as List?) ?? [];
    final commentsList = (json['forum_comments'] as List?) ?? [];
    final bookmarksList = (json['forum_bookmarks'] as List?) ?? [];
    final participantsList = (json['forum_workshop_participants'] as List?) ?? [];

    bool likedByMe = likesList.any((like) => like['user_id'] == currentUserId);
    bool bookmarkedByMe = bookmarksList.any((bm) => bm['user_id'] == currentUserId);
    bool participating = participantsList.any((p) => p['user_id'] == currentUserId);

    return ForumPost(
      id: json['id'],
      authorId: json['author_id'],
      category: json['category'],
      title: json['title'],
      content: json['content'],
      imageUrl: json['image_url'],
      tags: List<String>.from(json['tags'] ?? []),
      isSolved: json['is_solved'] ?? false,
      acceptedAnswerId: json['accepted_answer_id'],
      createdAt: DateTime.parse(json['created_at']).toLocal(),
      eventDate: json['event_date'] != null ? DateTime.parse(json['event_date']).toLocal() : null,
      meetingLink: json['meeting_link'],
      participantLimit: json['participant_limit'],
      authorName: name,
      authorRole: role,
      authorProfileImageUrl: profileImage,
      likeCount: json['forum_likes'] != null ? (json['forum_likes'] as List).length : 0,
      commentCount: json['forum_comments'] != null ? (json['forum_comments'] as List).length : 0,
      participantCount: json['forum_workshop_participants'] != null ? (json['forum_workshop_participants'] as List).length : 0,
      isLikedByMe: likedByMe,
      isBookmarkedByMe: bookmarkedByMe,
      isParticipating: participating,
    );
  }
}
