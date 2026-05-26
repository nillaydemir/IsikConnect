import 'dart:io';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'current_session.dart';

class MeetingService {
  final _supabase = Supabase.instance.client;

  static final Set<String> _joinedMeetingIds = {};
  static bool _isLoaded = false;

  static Future<Set<String>> getJoinedMeetings() async {
    if (_isLoaded) return _joinedMeetingIds;
    try {
      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}/joined_meetings.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> list = jsonDecode(content);
        _joinedMeetingIds.addAll(list.map((e) => e.toString()));
      }
    } catch (e) {
      debugPrint('Error loading joined meetings: $e');
    }
    _isLoaded = true;
    return _joinedMeetingIds;
  }

  static Future<void> markMeetingAsJoined(String meetingId) async {
    _joinedMeetingIds.add(meetingId);
    try {
      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}/joined_meetings.json');
      await file.writeAsString(jsonEncode(_joinedMeetingIds.toList()));
    } catch (e) {
      debugPrint('Error saving joined meetings: $e');
    }
  }

  static bool hasJoinedMeeting(String meetingId) {
    return _joinedMeetingIds.contains(meetingId);
  }

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

    final registrations = await _supabase
        .from('workshop_participants')
        .select('meeting_id')
        .eq('student_id', user.id);

    final Set<String> registeredMeetingIds = registrations.map((r) => r['meeting_id'].toString()).toSet();

    final List<dynamic> data = response;
    return data.map((meeting) {
      final Map<String, dynamic> meetingMap = Map<String, dynamic>.from(meeting);
      meetingMap['is_registered'] = registeredMeetingIds.contains(meeting['id'].toString());
      return meetingMap;
    }).toList();
  }

  Future<void> registerForWorkshop(String meetingId) async {
    final user = CurrentSession().user;
    if (user == null) throw Exception('User not logged in');

    // 1. Fetch meeting capacity
    final meetingResponse = await _supabase
        .from('meetings')
        .select('capacity')
        .eq('id', meetingId)
        .single();
    
    final int? capacity = meetingResponse['capacity'];

    // 2. Fetch current participant count and check duplicate
    final existingResponse = await _supabase
        .from('workshop_participants')
        .select('meeting_id')
        .eq('meeting_id', meetingId)
        .eq('student_id', user.id);
        
    if (existingResponse.isNotEmpty) {
      throw Exception('You are already registered for this workshop.');
    }

    if (capacity != null && capacity > 0) {
      final countResponse = await _supabase
          .from('workshop_participants')
          .select('meeting_id')
          .eq('meeting_id', meetingId);
      
      final currentCount = (countResponse as List).length;
      if (currentCount >= capacity) {
        throw Exception('This workshop has reached its maximum capacity.');
      }
    }

    // 3. Register
    await _supabase.from('workshop_participants').insert({
      'meeting_id': meetingId,
      'student_id': user.id,
    });
  }

  Future<void> unregisterFromWorkshop(String meetingId) async {
    final user = CurrentSession().user;
    if (user == null) throw Exception('User not logged in');

    await _supabase
        .from('workshop_participants')
        .delete()
        .match({'meeting_id': meetingId, 'student_id': user.id});
  }

  Future<void> deleteMeeting(String meetingId) async {
    final user = CurrentSession().user;
    if (user == null) throw Exception('User not logged in');

    // Manually delete participants first to avoid foreign key constraints
    await _supabase
        .from('workshop_participants')
        .delete()
        .eq('meeting_id', meetingId);

    await _supabase
        .from('meetings')
        .delete()
        .match({'id': meetingId, 'mentor_id': user.id});
  }

  Future<void> updateMeeting(String meetingId, DateTime date, TimeOfDay time) async {
    final user = CurrentSession().user;
    if (user == null) throw Exception('User not logged in');

    final meetingDate = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    if (meetingDate.isBefore(DateTime.now())) {
      throw Exception('Cannot schedule a meeting in the past.');
    }

    await _supabase
        .from('meetings')
        .update({'meeting_date': meetingDate.toUtc().toIso8601String()})
        .match({'id': meetingId, 'mentor_id': user.id});
  }

  Future<Map<String, dynamic>?> getMeetingDetails(String meetingId) async {
    final user = CurrentSession().user;
    if (user == null) return null;

    try {
      final response = await _supabase
          .from('meetings')
          .select('*, mentor:mentor_id(first_name, last_name)')
          .eq('id', meetingId)
          .single();

      final registrations = await _supabase
          .from('workshop_participants')
          .select('meeting_id')
          .eq('meeting_id', meetingId)
          .eq('student_id', user.id);

      final Map<String, dynamic> meetingMap = Map<String, dynamic>.from(response);
      meetingMap['is_registered'] = registrations.isNotEmpty;
      return meetingMap;
    } catch (e) {
      debugPrint('Error getting meeting details: $e');
      return null;
    }
  }
}
