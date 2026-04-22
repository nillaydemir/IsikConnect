class User {
  final String id;
  final String name;
  final String email;

  User({
    required this.id,
    required this.name,
    required this.email,
  });
}

class Student extends User {
  final String department;
  final String classLevel;
  final List<String> requestedTopics;
  Mentor? assignedMentor;

  Student({
    required super.id,
    required super.name,
    required super.email,
    required this.department,
    required this.classLevel,
    required this.requestedTopics,
    this.assignedMentor,
  });
}

class Mentor extends User {
  final String department;
  final String graduationYear;
  final String? company;
  final String? jobTitle;
  final int maxCapacity;
  int currentStudentsCount;
  final List<String> skills;

  Mentor({
    required super.id,
    required super.name,
    required super.email,
    required this.department,
    required this.graduationYear,
    this.company,
    this.jobTitle,
    required this.skills,
    this.maxCapacity = 3,
    this.currentStudentsCount = 0,
  });

  bool get isAvailable => currentStudentsCount < maxCapacity;
}
