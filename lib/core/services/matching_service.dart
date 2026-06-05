import 'package:flutter/foundation.dart';
import '../models/user_models.dart';
import 'api_service.dart';

class MatchingService {
  static const int departmentMatchScore = 10;
  static const int skillMatchScore = 5;

  /// Wraps the existing algorithm and handles persistence via Backend API
  Future<Mentor?> findAndSaveMatch(Student student) async {
    try {
      final apiService = ApiService();
      final mentorJson = await apiService.runMatchingAlgorithm();
      if (mentorJson == null) return null;

      return Mentor(
        id: mentorJson['id'],
        name: '${mentorJson['first_name']} ${mentorJson['last_name']}',
        email: mentorJson['email'],
        profileImageUrl: mentorJson['profile_image_url'],
        department: mentorJson['department'] ?? '',
        graduationYear: mentorJson['graduation_year']?.toString() ?? '',
        skills: List<String>.from(mentorJson['skills'] ?? []),
        company: mentorJson['company'],
        jobTitle: mentorJson['job_title'],
        maxCapacity: mentorJson['maxCapacity'] ?? 1,
        currentStudentsCount: mentorJson['currentStudentsCount'] ?? 0,
        availableDays: List<String>.from(mentorJson['availableDays'] ?? []),
        avgRating: (mentorJson['avgRating'] as num?)?.toDouble() ?? 0.0,
        reviewCount: mentorJson['reviewCount'] ?? 0,
        badge: mentorJson['badge']?.toString() ?? '🌱 New Mentor',
      );
    } catch (e) {
      debugPrint('Error finding match from backend: $e');
      rethrow;
    }
  }

  Future<void> saveMatch(String studentId, String mentorId) async {
    // Deprecated for direct client calls, logic moved to backend POST /matching/run
    debugPrint('saveMatch is handled atomically by backend');
  }

  Future<void> cancelMatch(String studentId, String mentorId, String cancelledBy) async {
    try {
      final apiService = ApiService();
      await apiService.cancelMentorship(studentId, mentorId);
    } catch (e) {
      debugPrint('Error cancelling match via backend: $e');
      rethrow;
    }
  }

  /// Returns the number of cancelled matches for a student in the current academic year
  Future<int> getCancelledMatchCount(String studentId) async {
    try {
      final apiService = ApiService();
      return await apiService.getStudentCancelledCount(studentId);
    } catch (e) {
      debugPrint('Error getting student cancelled match count via backend: $e');
      return 0;
    }
  }

  /// Returns the number of cancelled matches for a mentor in the current academic year
  Future<int> getMentorCancelledMatchCount(String mentorId) async {
    try {
      final apiService = ApiService();
      return await apiService.getMentorCancelledCount(mentorId);
    } catch (e) {
      debugPrint('Error getting mentor cancelled match count via backend: $e');
      return 0;
    }
  }

  /// THE BLACK BOX ALGORITHM (DO NOT MODIFY LOGIC)
  Map<Student, Mentor?> assignMentors(List<Student> students, List<Mentor> mentors) {
    Map<Student, Mentor?> assignments = {};

    for (var student in students) {
      Mentor? bestMentor;
      int highestScore = 0;

      for (var mentor in mentors) {
        if (!mentor.isAvailable) continue;

        int currentScore = _calculateMatchScore(student, mentor);

        if (currentScore > highestScore) {
          highestScore = currentScore;
          bestMentor = mentor;
        }
      }

      if (bestMentor != null) {
        assignments[student] = bestMentor;
        student.assignedMentor = bestMentor;
        // Logic kept for internal model consistency
        bestMentor.currentStudentsCount++;
      } else {
        assignments[student] = null;
      }
    }

    return assignments;
  }

  int _calculateMatchScore(Student student, Mentor mentor) {
    int score = 0;
    debugPrint('--- Debug Matching: ${student.name} vs ${mentor.name} ---');
    debugPrint('Student Days: ${student.availableDays}, Mentor Days: ${mentor.availableDays}');

    // 1. HARD CONSTRAINT: Must have at least one common available day
    final commonDays = student.availableDays.where((day) => 
      mentor.availableDays.any((mDay) => mDay.trim().toLowerCase() == day.trim().toLowerCase())
    ).toList();

    if (commonDays.isEmpty) {
      debugPrint('REJECTED: No common available days.');
      return 0; 
    }

    // 2. SKILL MATCH CALCULATION
    int skillMatches = 0;
    for (var requirement in student.requestedTopics) {
      bool hasMatch = mentor.skills.any((skill) => 
          skill.trim().toLowerCase() == requirement.trim().toLowerCase());
          
      if (hasMatch) {
        skillMatches++;
      }
    }

    // 3. CORE REQUIREMENT: Must have EITHER same department OR at least one matching skill
    bool isDepartmentMatch = student.department.trim().toLowerCase() == mentor.department.trim().toLowerCase();
    
    if (!isDepartmentMatch && skillMatches == 0) {
      debugPrint('REJECTED: Neither department nor skills match ("${student.department}" vs "${mentor.department}")');
      return 0;
    }

    // 4. SCORING
    if (isDepartmentMatch) {
      score += departmentMatchScore;
      debugPrint('Department Match! (+$departmentMatchScore)');
    }

    score += commonDays.length * 5;
    debugPrint('Common Days Score: ${commonDays.length * 5}');

    if (skillMatches > 0) {
      score += skillMatches * skillMatchScore;
      debugPrint('Skill Matches: $skillMatches (+${skillMatches * skillMatchScore})');
    }

    debugPrint('Final Total Score: $score');
    return score;
  }
}
