class JobPosting {
  final String id;
  final String mentorId;
  final String title;
  final String company;
  final String description;
  final String requirements;
  final DateTime createdAt;
  final bool isDeleted;

  // Joined fields from 'users' and 'mentors'
  final String mentorName;
  final String? mentorCompany;
  final String? mentorJobTitle;
  final String? mentorProfileImageUrl;

  JobPosting({
    required this.id,
    required this.mentorId,
    required this.title,
    required this.company,
    required this.description,
    required this.requirements,
    required this.createdAt,
    this.isDeleted = false,
    required this.mentorName,
    this.mentorCompany,
    this.mentorJobTitle,
    this.mentorProfileImageUrl,
  });

  factory JobPosting.fromJson(Map<String, dynamic> json) {
    // Extract user relation data
    final users = json['users'] as Map<String, dynamic>?;
    final String firstName = users?['first_name'] ?? 'Unknown';
    final String lastName = users?['last_name'] ?? 'User';
    final String name = '$firstName $lastName'.trim();
    final String? profileImage = users?['profile_image_url'];

    // Extract mentor relation data
    final mentors = json['mentors'] as Map<String, dynamic>?;
    final String? mCompany = mentors?['company'] ?? json['company'];
    final String? mJobTitle = mentors?['job_title'];

    return JobPosting(
      id: json['id'] as String,
      mentorId: json['mentor_id'] as String,
      title: json['title'] as String,
      company: json['company'] as String,
      description: json['description'] as String,
      requirements: json['requirements'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      isDeleted: json['is_deleted'] as bool? ?? false,
      mentorName: name,
      mentorCompany: mCompany,
      mentorJobTitle: mJobTitle,
      mentorProfileImageUrl: profileImage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mentor_id': mentorId,
      'title': title,
      'company': company,
      'description': description,
      'requirements': requirements,
      'created_at': createdAt.toIso8601String(),
      'is_deleted': isDeleted,
    };
  }
}
