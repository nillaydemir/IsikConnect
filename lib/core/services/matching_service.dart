import '../models/user_models.dart';

class MatchingService {
  static const int departmentMatchScore = 10;
  static const int skillMatchScore = 5;

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
        bestMentor.currentStudentsCount++;
      } else {
        assignments[student] = null;
      }
    }

    return assignments;
  }

  int _calculateMatchScore(Student student, Mentor mentor) {
    int score = 0;

    if (student.department == mentor.department) {
      score += departmentMatchScore;
    }

    for (var requirement in student.requestedTopics) {
      if (mentor.skills.contains(requirement)) {
        score += skillMatchScore;
      }
    }

    return score;
  }
}
