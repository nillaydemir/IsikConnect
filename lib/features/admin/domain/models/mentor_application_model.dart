class MentorApplicationModel {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? avatarUrl;
  
  // Dynamic specificity handled genericly
  final String subTitle; 
  final String documentUrl;
  
  final DateTime applicationDate;
  final String status;

  MentorApplicationModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.avatarUrl,
    required this.subTitle,
    required this.documentUrl,
    required this.applicationDate,
    this.status = 'pending',
  });

  factory MentorApplicationModel.fromJson(Map<String, dynamic> json) {
    // Backend drops: users: {first_name, last_name, email}, specific: {department, company...}
    final users = json['users'] ?? {};
    final specific = json['specific'] ?? {};
    
    final name = '${users['first_name'] ?? 'Unknown'} ${users['last_name'] ?? ''}'.trim();
    final email = users['email'] ?? 'No email';
    final role = json['role'] ?? 'student';
    
    String subTitle;
    if (role == 'student') {
      subTitle = '${specific['department'] ?? 'Department Unknown'} - ${specific['class_level'] ?? 'Class Unknown'}';
    } else {
      subTitle = '${specific['job_title'] ?? 'Job Title Unknown'} at ${specific['company'] ?? 'Company Unknown'}';
    }

    return MentorApplicationModel(
      id: json['id'] ?? '',
      name: name,
      email: email,
      role: role.toString().toUpperCase(),
      avatarUrl: null,
      subTitle: subTitle,
      documentUrl: json['document_url'] ?? '',
      applicationDate: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      status: json['status'] ?? 'pending',
    );
  }
}
