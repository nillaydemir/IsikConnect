class MentorApplicationModel {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final String university;
  final String department;
  final List<String> expertiseAreas;
  final String bio;
  final String motivation;
  final DateTime applicationDate;
  final String status; // 'pending', 'approved', 'rejected'

  MentorApplicationModel({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    required this.university,
    required this.department,
    required this.expertiseAreas,
    required this.bio,
    required this.motivation,
    required this.applicationDate,
    this.status = 'pending',
  });

  MentorApplicationModel copyWith({
    String? status,
  }) {
    return MentorApplicationModel(
      id: id,
      name: name,
      email: email,
      avatarUrl: avatarUrl,
      university: university,
      department: department,
      expertiseAreas: expertiseAreas,
      bio: bio,
      motivation: motivation,
      applicationDate: applicationDate,
      status: status ?? this.status,
    );
  }
}
