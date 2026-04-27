class AppUser {
  final String id;
  final String email;
  final String role;
  final bool isApproved;
  final DateTime createdAt;
  final String? name;
  final String? phone;
  final List<String>? availableDays;
  final String? department;
  final String? classLevel;
  final List<String>? interests;
  final String? graduationYear;
  final String? company;
  final String? jobTitle;
  final int? maxStudents;

  AppUser({
    required this.id,
    required this.email,
    required this.role,
    this.isApproved = false,
    required this.createdAt,
    this.name,
    this.phone,
    this.availableDays,
    this.department,
    this.classLevel,
    this.interests,
    this.graduationYear,
    this.company,
    this.jobTitle,
    this.maxStudents,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      isApproved: json['is_approved'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      name: (json['name'] ?? json['full_name']) as String?,
      phone: json['phone'] as String?,
      availableDays: (json['available_days'] as List?)?.map((e) => e as String).toList(),
      department: json['department'] as String?,
      classLevel: json['class_level'] as String?,
      interests: (json['interests'] as List?)?.map((e) => e as String).toList(),
      graduationYear: json['graduation_year'] as String?,
      company: json['company'] as String?,
      jobTitle: json['job_title'] as String?,
      maxStudents: json['max_students'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'role': role,
      'is_approved': isApproved,
      'created_at': createdAt.toIso8601String(),
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (availableDays != null) 'available_days': availableDays,
      if (department != null) 'department': department,
      if (classLevel != null) 'class_level': classLevel,
      if (interests != null) 'interests': interests,
      if (graduationYear != null) 'graduation_year': graduationYear,
      if (company != null) 'company': company,
      if (jobTitle != null) 'job_title': jobTitle,
      if (maxStudents != null) 'max_students': maxStudents,
    };
  }
}
