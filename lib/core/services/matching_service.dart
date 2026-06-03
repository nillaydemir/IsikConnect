import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
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
      debugPrint('Warning: Could not fetch reviews (table may not exist or other error): $e');
    }

    // 3. Map reviews by mentor_id for easy lookup
    final Map<String, List<int>> reviewsByMentor = {};
    for (var rev in allReviews) {
      final mid = rev['mentor_id'].toString();
      final rating = (rev['rating'] as num).toInt();
      reviewsByMentor.putIfAbsent(mid, () => []).add(rating);
    }

    debugPrint('Matching Debug: Found ${response.length} approved mentors in database.');

    // 4. Fetch cancelled mentors for this student to exclude them
    final cancelledMatches = await _supabase
        .from('matches')
        .select('mentor_id')
        .eq('student_id', student.id)
        .eq('status', 'cancelled');
        
    final cancelledMentorIds = (cancelledMatches as List)
        .map((m) => m['mentor_id'].toString())
        .toSet();

    // 5. Fetch ALL cancelled matches for all mentors in the current period to check limits
    final periodStart = _getCurrentPeriodStart();
    final allCancelledMatches = await _supabase
        .from('matches')
        .select('mentor_id, cancelled_by, students(users(is_deleted))')
        .eq('status', 'cancelled')
        .gte('created_at', periodStart.toIso8601String());

    final Map<String, int> mentorCancellationCounts = {};
    for (var match in allCancelledMatches as List) {
      final mId = match['mentor_id'].toString();
      final cancelledBy = match['cancelled_by'] as String?;
      
      // If explicitly cancelled by student or admin, do not count against mentor!
      if (cancelledBy == 'student' || cancelledBy == 'admin') {
        continue;
      }
      
      // If student is deleted, do not count this cancellation against the mentor
      final studentsDataRaw = match['students'];
      if (studentsDataRaw != null) {
        Map<String, dynamic> studentsData;
        if (studentsDataRaw is List) {
          if (studentsDataRaw.isEmpty) continue;
          studentsData = studentsDataRaw.first;
        } else {
          studentsData = studentsDataRaw as Map<String, dynamic>;
        }
        
        final usersData = studentsData['users'];
        if (usersData != null && usersData['is_deleted'] == true) {
          debugPrint('Skipping cancelled match for mentor $mId in limit calculation because the student deleted their account.');
          continue;
        }
      }
      
      mentorCancellationCounts[mId] = (mentorCancellationCounts[mId] ?? 0) + 1;
    }

    List<Mentor> mentors = [];
    for (var row in response) {
      final mentorIdStr = row['id'].toString();
      
      if (row['is_deleted'] == true) {
        debugPrint('Skipping mentor $mentorIdStr because their user account is deleted.');
        continue;
      }
      
      if (cancelledMentorIds.contains(mentorIdStr)) {
        debugPrint('Skipping mentor $mentorIdStr because they were previously cancelled by this student.');
        continue;
      }
      
      final mentorDataRaw = row['mentors'];
      if (mentorDataRaw == null) continue;
      
      Map<String, dynamic> mentorData;
      if (mentorDataRaw is List) {
        if (mentorDataRaw.isEmpty) continue;
        mentorData = mentorDataRaw.first;
      } else {
        mentorData = mentorDataRaw as Map<String, dynamic>;
      }

      if (mentorData['status'] == 'deleted') {
        debugPrint('Skipping mentor $mentorIdStr because their mentor profile is marked as deleted.');
        continue;
      }

      int maxCapacity = mentorData['max_students'] ?? 1;
      
      // Check mentor cancellation limit (max_students * 2)
      final mentorCancelCount = mentorCancellationCounts[mentorIdStr] ?? 0;
      if (mentorCancelCount >= (maxCapacity * 2)) {
        debugPrint('Skipping mentor $mentorIdStr because they exceeded their cancellation limit ($mentorCancelCount / ${maxCapacity * 2}).');
        continue;
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
      if (currentCount >= maxCapacity) continue;

      mentors.add(Mentor(
        id: row['id'],
        name: '${row['first_name']} ${row['last_name']}',
        email: row['email'],
        profileImageUrl: row['profile_image_url'],
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

    debugPrint('Final list of mentors to pass to algorithm: ${mentors.length}');
    if (mentors.isEmpty) {
      debugPrint('REASON: No mentors passed the initial filters (is_approved, capacity, or missing data).');
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

  Future<void> cancelMatch(String studentId, String mentorId, String cancelledBy) async {
    // 1. UPDATE matches SET status = 'cancelled', cancelled_by = cancelledBy
    await _supabase.from('matches').update({
      'status': 'cancelled',
      'cancelled_by': cancelledBy,
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

  /// Returns the start date of the current academic year (September 1st)
  DateTime _getCurrentPeriodStart() {
    final now = DateTime.now();
    if (now.month >= DateTime.september) {
      return DateTime(now.year, DateTime.september, 1);
    } else {
      return DateTime(now.year - 1, DateTime.september, 1);
    }
  }

  /// Returns the number of cancelled matches for a student in the current academic year
  Future<int> getCancelledMatchCount(String studentId) async {
    final periodStart = _getCurrentPeriodStart();
    final response = await _supabase
        .from('matches')
        .select('id, cancelled_by, mentors(users(is_deleted))')
        .eq('student_id', studentId)
        .eq('status', 'cancelled')
        .gte('created_at', periodStart.toIso8601String());
        
    int count = 0;
    for (var match in response as List) {
      final cancelledBy = match['cancelled_by'] as String?;
      if (cancelledBy == 'mentor' || cancelledBy == 'admin') {
        continue;
      }

      final mentorsDataRaw = match['mentors'];
      if (mentorsDataRaw != null) {
        Map<String, dynamic> mentorsData;
        if (mentorsDataRaw is List) {
          if (mentorsDataRaw.isEmpty) continue;
          mentorsData = mentorsDataRaw.first;
        } else {
          mentorsData = mentorsDataRaw as Map<String, dynamic>;
        }
        
        final usersData = mentorsData['users'];
        if (usersData != null && usersData['is_deleted'] == true) {
          debugPrint('Ignoring cancelled match in student $studentId rights count because the mentor deleted their account.');
          continue;
        }
      }
      count++;
    }
    return count;
  }

  /// Returns the number of cancelled matches for a mentor in the current academic year
  Future<int> getMentorCancelledMatchCount(String mentorId) async {
    final periodStart = _getCurrentPeriodStart();
    final response = await _supabase
        .from('matches')
        .select('id, cancelled_by, students(users(is_deleted))')
        .eq('mentor_id', mentorId)
        .eq('status', 'cancelled')
        .gte('created_at', periodStart.toIso8601String());
        
    int count = 0;
    for (var match in response as List) {
      final cancelledBy = match['cancelled_by'] as String?;
      if (cancelledBy == 'student' || cancelledBy == 'admin') {
        continue;
      }

      final studentsDataRaw = match['students'];
      if (studentsDataRaw != null) {
        Map<String, dynamic> studentsData;
        if (studentsDataRaw is List) {
          if (studentsDataRaw.isEmpty) continue;
          studentsData = studentsDataRaw.first;
        } else {
          studentsData = studentsDataRaw as Map<String, dynamic>;
        }
        
        final usersData = studentsData['users'];
        if (usersData != null && usersData['is_deleted'] == true) {
          debugPrint('Ignoring cancelled match in mentor $mentorId rights count because the student deleted their account.');
          continue;
        }
      }
      count++;
    }
    return count;
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
