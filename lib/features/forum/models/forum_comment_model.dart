class ForumComment {
  final String id;
  final String postId;
  final String authorId;
  final String content;
  final bool isAccepted;
  final DateTime createdAt;
  
  // Joined fields
  final String authorName;
  final String authorRole;
  final String? authorProfileImageUrl;

  ForumComment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.content,
    this.isAccepted = false,
    required this.createdAt,
    required this.authorName,
    required this.authorRole,
    this.authorProfileImageUrl,
  });

  factory ForumComment.fromJson(Map<String, dynamic> json) {
    final users = json['users'] as Map<String, dynamic>?;
    final String fName = users?['first_name'] ?? 'Unknown';
    final String lName = users?['last_name'] ?? 'User';
    final String name = '$fName $lName'.trim();
    final String role = users?['role'] ?? 'student';
    final String? profileImage = users?['profile_image_url'];

    return ForumComment(
      id: json['id'],
      postId: json['post_id'],
      authorId: json['author_id'],
      content: json['content'],
      isAccepted: json['is_accepted'] ?? false,
      createdAt: DateTime.parse(json['created_at']).toLocal(),
      authorName: name,
      authorRole: role,
      authorProfileImageUrl: profileImage,
    );
  }
}
