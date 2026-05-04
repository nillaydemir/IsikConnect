import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_models.dart';

class MatchingService {
  final _supabase = Supabase.instance.client;
  static const int departmentMatchScore = 10;
  static const int skillMatchScore = 5;

  /// Wraps the existing algorithm and handles persistence
  Future<Mentor?> findAndSaveMatch(Student student) async {
    // 1. Fetch mentors and user details
    final response = await _supabase
        .from('users')
        .select('*, mentors(*)')
        .eq('role', 'mentor')
        .eq('is_approved', true);

    if (response.isEmpty) return null;

    // 2. Fetch all reviews for these mentors in a separate call to bypass missing FK relationships
    final mentorIds = response.map((r) => r['id'].toString()).toList();
    List<dynamic> allReviews = [];
    try {
      allReviews = await _supabase
          .from('reviews')
          .select('mentor_id, rating')
          .inFilter('mentor_id', mentorIds);
    } catch (e) {
      print('Warning: Could not fetch reviews (table may not exist or other error): $e');
    }

    // 3. Map reviews by mentor_id for easy lookup
    final Map<String, List<int>> reviewsByMentor = {};
    for (var rev in allReviews) {
      final mid = rev['mentor_id'].toString();
      final rating = (rev['rating'] as num).toInt();
      reviewsByMentor.putIfAbsent(mid, () => []).add(rating);
    }

    print('Matching Debug: Found ${response.length} approved mentors in database.');

    List<Mentor> mentors = [];
    for (var row in response) {
      final mentorDataRaw = row['mentors'];
      if (mentorDataRaw == null) continue;
      
      Map<String, dynamic> mentorData;
      if (mentorDataRaw is List) {
        if (mentorDataRaw.isEmpty) continue;
        mentorData = mentorDataRaw.first;
      } else {
        mentorData = mentorDataRaw as Map<String, dynamic>;
      }

      // Get ratings from our separate fetch
      final mentorReviews = reviewsByMentor[row['id'].toString()] ?? [];
      double avgRating = 0.0;
      if (mentorReviews.isNotEmpty) {
        avgRating = mentorReviews.reduce((a, b) => a + b) / mentorReviews.length;
      }
      int reviewCount = mentorReviews.length;

      // Skip if already full
      int currentCount = mentorData['current_student_count'] ?? 0;
      int maxCapacity = mentorData['max_students'] ?? 1;
      if (currentCount >= maxCapacity) continue;

      mentors.add(Mentor(
        id: row['id'],
        name: '${row['first_name']} ${row['last_name']}',
        email: row['email'],
        department: row['department'] ?? '',
        graduationYear: mentorData['graduation_year']?.toString() ?? '',
        skills: List<String>.from(mentorData['interests'] ?? []),
        company: mentorData['company'],
        jobTitle: mentorData['job_title'],
        maxCapacity: maxCapacity,
        currentStudentsCount: currentCount,
        availableDays: List<String>.from(mentorData['available_days'] ?? []),
        avgRating: avgRating,
        reviewCount: reviewCount,
      ));
    }

    // Sort mentors by rating (highest first), then by count, then nulls last (0 is lowest)
    mentors.sort((a, b) {
      // 1. Sort by Average Rating (Descending)
      if (b.avgRating != a.avgRating) {
        return b.avgRating.compareTo(a.avgRating);
      }
      // 2. Sort by Review Count (Descending)
      return b.reviewCount.compareTo(a.reviewCount);
    });

    print('Final list of mentors to pass to algorithm: ${mentors.length}');
    if (mentors.isEmpty) {
      print('REASON: No mentors passed the initial filters (is_approved, capacity, or missing data).');
      return null;
    }

    // 2. CALL EXISTING ALGORITHM (Black Box)
    final results = assignMentors([student], mentors);
    final bestMentor = results[student];

    if (bestMentor != null) {
      // 3. AFTER algorithm: Persistence
      await saveMatch(student.id, bestMentor.id);
      return bestMentor;
    }

    return null;
  }

  Future<void> saveMatch(String studentId, String mentorId) async {
    // Atomic updates via separate calls (or could be an RPC)
    // 1. INSERT into matches
    await _supabase.from('matches').insert({
      'mentor_id': mentorId,
      'student_id': studentId,
      'status': 'active',
    });

    // 2. UPDATE mentors.current_student_count += 1
    // Note: In a real production app, use RPC for increment to avoid race conditions
    final mentorRes = await _supabase.from('mentors').select('current_student_count').eq('id', mentorId).single();
    int currentCount = mentorRes['current_student_count'] ?? 0;
    await _supabase.from('mentors').update({
      'current_student_count': currentCount + 1,
    }).eq('id', mentorId);

    // 3. UPDATE students.matched_mentor_id
    await _supabase.from('students').update({
      'matched_mentor_id': mentorId,
    }).eq('id', studentId);
  }

  Future<void> cancelMatch(String studentId, String mentorId) async {
    // 1. UPDATE matches SET status = 'cancelled'
    await _supabase.from('matches').update({
      'status': 'cancelled',
    }).eq('student_id', studentId).eq('mentor_id', mentorId).eq('status', 'active');

    // 2. UPDATE mentors SET current_student_count = current_student_count - 1
    final mentorRes = await _supabase.from('mentors').select('current_student_count').eq('id', mentorId).single();
    int currentCount = mentorRes['current_student_count'] ?? 0;
    await _supabase.from('mentors').update({
      'current_student_count': currentCount > 0 ? currentCount - 1 : 0,
    }).eq('id', mentorId);

    // 3. UPDATE students SET matched_mentor_id = NULL
    await _supabase.from('students').update({
      'matched_mentor_id': null,
    }).eq('id', studentId);
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
    print('--- Debug Matching: ${student.name} vs ${mentor.name} ---');
    print('Student Days: ${student.availableDays}, Mentor Days: ${mentor.availableDays}');

    // 1. HARD CONSTRAINT: Must have at least one common available day
    final commonDays = student.availableDays.where((day) => 
      mentor.availableDays.any((mDay) => mDay.trim().toLowerCase() == day.trim().toLowerCase())
    ).toList();

    if (commonDays.isEmpty) {
      print('REJECTED: No common available days.');
      return 0; 
    }

    // 2. HARD CONSTRAINT: Department must match
    if (student.department.trim().toLowerCase() != mentor.department.trim().toLowerCase()) {
      print('REJECTED: Department mismatch ("${student.department}" vs "${mentor.department}")');
      return 0;
    }

    // 3. Department Match Bonus (Now implicit since it's required, but we give a base score)
    score += departmentMatchScore;
    print('Department Match! (+$departmentMatchScore)');

    // 4. Add points for common days
    score += commonDays.length * 5;
    print('Common Days Score: ${commonDays.length * 5}');

    // 5. Skills Match
    int skillMatches = 0;
    for (var requirement in student.requestedTopics) {
      bool hasMatch = mentor.skills.any((skill) => 
          skill.trim().toLowerCase() == requirement.trim().toLowerCase());
          
      if (hasMatch) {
        score += skillMatchScore;
        skillMatches++;
      }
    }
    if (skillMatches > 0) print('Skill Matches: $skillMatches (+${skillMatches * skillMatchScore})');

    print('Final Total Score: $score');
    return score;
  }
}
