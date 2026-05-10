import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'current_session.dart';

class MeetingService {
  final _supabase = Supabase.instance.client;

  Future<void> createMeeting({
    required String title,
    required String type,
    required DateTime date,
    required TimeOfDay time,
    String? studentId,
    int? capacity,
  }) async {
    final user = CurrentSession().user;
    if (user == null) throw Exception('User not logged in');

    final meetingDate = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    ).toUtc();

    await _supabase.from('meetings').insert({
      'title': title,
      'meeting_type': type,
      'meeting_date': meetingDate.toIso8601String(),
      'mentor_id': user.id,
      'student_id': studentId,
      'capacity': capacity,
    });
  }

  Future<List<Map<String, dynamic>>> getMentees() async {
    final user = CurrentSession().user;
    if (user == null) return [];

    final response = await _supabase
        .from('students')
        .select('*, users(*)')
        .eq('matched_mentor_id', user.id);

    if (response.isEmpty) return [];

    final List<dynamic> data = response;
    return data.map((mentee) {
      final userData = mentee['users'] as Map<String, dynamic>? ?? {};
      return <String, dynamic>{
        'id': mentee['id'].toString(),
        'first_name': userData['first_name']?.toString() ?? 'Mentee',
        'last_name': userData['last_name']?.toString() ?? '',
        'email': userData['email']?.toString() ?? '',
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getMeetings() async {
    final user = CurrentSession().user;
    if (user == null) return [];

    final response = await _supabase
        .from('meetings')
        .select('*, mentor:mentor_id(first_name, last_name), student:student_id(first_name, last_name)')
        .order('meeting_date', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }
}
