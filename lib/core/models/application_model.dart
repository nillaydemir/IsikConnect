class AppApplication {
  final String id;
  final String userId;
  final String role;
  final String documentUrl;
  final String status;
  final DateTime createdAt;

  AppApplication({
    required this.id,
    required this.userId,
    required this.role,
    required this.documentUrl,
    this.status = 'pending',
    required this.createdAt,
  });

  factory AppApplication.fromJson(Map<String, dynamic> json) {
    return AppApplication(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      role: json['role'] as String,
      documentUrl: json['document_url'] as String,
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'role': role,
      'document_url': documentUrl,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
