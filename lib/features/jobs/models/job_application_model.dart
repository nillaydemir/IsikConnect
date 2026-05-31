class JobApplication {
  final String id;
  final String jobId;
  final String studentId;
  final String? coverNote;
  final String status; // 'applied', 'accepted', 'rejected'
  final String? feedback;
  final DateTime createdAt;

  // Joined fields from 'users' and 'students'
  final String studentName;
  final String studentEmail;
  final String? studentDepartment;
  final String? studentClassLevel;
  final String? studentDocumentUrl;

  JobApplication({
    required this.id,
    required this.jobId,
    required this.studentId,
    this.coverNote,
    required this.status,
    this.feedback,
    required this.createdAt,
    required this.studentName,
    required this.studentEmail,
    this.studentDepartment,
    this.studentClassLevel,
    this.studentDocumentUrl,
  });

  factory JobApplication.fromJson(Map<String, dynamic> json) {
    // Extract student relation data
    final students = json['students'] as Map<String, dynamic>?;
    final String? classLevel = students?['class_level'];
    
    // Fallback: use custom cv_url if exists, otherwise use registration document
    final String? docUrl = json['cv_url'] as String? ?? students?['student_document_url'] as String?;

    // Extract user relation data (nested inside students)
    final users = students?['users'] as Map<String, dynamic>?;
    final String firstName = users?['first_name'] ?? 'Unknown';
    final String lastName = users?['last_name'] ?? 'Student';
    final String name = '$firstName $lastName'.trim();
    final String email = users?['email'] ?? '';
    final String? dept = users?['department'];

    return JobApplication(
      id: json['id'] as String,
      jobId: json['job_id'] as String,
      studentId: json['student_id'] as String,
      coverNote: json['cover_note'] as String?,
      status: json['status'] as String? ?? 'applied',
      feedback: json['feedback'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      studentName: name,
      studentEmail: email,
      studentDepartment: dept,
      studentClassLevel: classLevel,
      studentDocumentUrl: docUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'job_id': jobId,
      'student_id': studentId,
      'cover_note': coverNote,
      'status': status,
      'feedback': feedback,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
