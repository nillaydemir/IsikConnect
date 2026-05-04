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
  final List<String> availableDays;
  Mentor? assignedMentor;

  Student({
    required super.id,
    required super.name,
    required super.email,
    required this.department,
    required this.classLevel,
    required this.requestedTopics,
    this.availableDays = const [],
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
  final List<String> availableDays;
  final double avgRating;
  final int reviewCount;

  Mentor({
    required super.id,
    required super.name,
    required super.email,
    required this.department,
    required this.graduationYear,
    this.company,
    this.jobTitle,
    required this.skills,
    this.availableDays = const [],
    this.maxCapacity = 3,
    this.currentStudentsCount = 0,
    this.avgRating = 0.0,
    this.reviewCount = 0,
  });

  bool get isAvailable => currentStudentsCount < maxCapacity;
}
