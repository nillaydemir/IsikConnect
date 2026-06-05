import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'current_session.dart';
import 'api_service.dart';

class MeetingService {
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

    try {
      await ApiService().joinMeeting(meetingId);
      debugPrint('Successfully marked meeting $meetingId as attended in database.');
    } catch (e) {
      debugPrint('Error marking meeting as attended in database: $e');
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

    await ApiService().createMeeting(
      title: title,
      type: type,
      meetingDate: meetingDate.toIso8601String(),
      studentId: studentId,
      capacity: capacity,
    );
  }

  Future<List<Map<String, dynamic>>> getMentees() async {
    final user = CurrentSession().user;
    if (user == null) return [];

    return await ApiService().getMentees();
  }

  Future<List<Map<String, dynamic>>> getMeetings() async {
    final user = CurrentSession().user;
    if (user == null) return [];

    return await ApiService().getMeetings();
  }

  Future<void> registerForWorkshop(String meetingId) async {
    final user = CurrentSession().user;
    if (user == null) throw Exception('User not logged in');

    await ApiService().registerForWorkshop(meetingId);
  }

  Future<void> unregisterFromWorkshop(String meetingId) async {
    final user = CurrentSession().user;
    if (user == null) throw Exception('User not logged in');

    await ApiService().unregisterFromWorkshop(meetingId);
  }

  Future<void> deleteMeeting(String meetingId) async {
    final user = CurrentSession().user;
    if (user == null) throw Exception('User not logged in');

    await ApiService().deleteMeeting(meetingId);
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

    await ApiService().updateMeeting(meetingId, meetingDate.toUtc().toIso8601String());
  }

  Future<Map<String, dynamic>?> getMeetingDetails(String meetingId) async {
    final user = CurrentSession().user;
    if (user == null) return null;

    try {
      return await ApiService().getMeetingDetails(meetingId);
    } catch (e) {
      debugPrint('Error getting meeting details: $e');
      return null;
    }
  }
}
