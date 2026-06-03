import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import '../models/job_posting_model.dart';
import '../models/job_application_model.dart';
import '../../../core/services/current_session.dart';

class JobService {
  final _supabase = Supabase.instance.client;

  String get _currentUserId {
    final id = CurrentSession().user?.id;
    if (id == null) throw Exception('User not logged in');
    return id;
  }

  // --- JOB POSTINGS (UC11, UC12) ---
  
  // Fetch all job postings
  Future<List<JobPosting>> fetchJobPostings() async {
    try {
      final response = await _supabase
          .from('job_postings')
          .select('*, users:mentor_id(first_name, last_name, profile_image_url, is_approved, is_deleted)')
          .eq('is_deleted', false)
          .order('created_at', ascending: false);

      final List<dynamic> data = response;
      return data.map((json) => JobPosting.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching job postings: $e');
      rethrow;
    }
  }

  // Fetch only job postings created by the current mentor/admin
  Future<List<JobPosting>> fetchMyJobPostings() async {
    try {
      final response = await _supabase
          .from('job_postings')
          .select('*, users:mentor_id(first_name, last_name, profile_image_url, is_approved, is_deleted)')
          .eq('mentor_id', _currentUserId)
          .eq('is_deleted', false)
          .order('created_at', ascending: false);

      final List<dynamic> data = response;
      return data.map((json) => JobPosting.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching my job postings: $e');
      rethrow;
    }
  }

  // Create a new job posting (UC11)
  Future<void> createJobPosting({
    required String title,
    required String company,
    required String description,
    required String requirements,
  }) async {
    try {
      await _supabase.from('job_postings').insert({
        'mentor_id': _currentUserId,
        'title': title,
        'company': company,
        'description': description,
        'requirements': requirements,
      });
    } catch (e) {
      debugPrint('Error creating job posting: $e');
      rethrow;
    }
  }

  // Update an existing job posting (UC12)
  Future<void> updateJobPosting(
    String id, {
    required String title,
    required String company,
    required String description,
    required String requirements,
  }) async {
    try {
      await _supabase.from('job_postings').update({
        'title': title,
        'company': company,
        'description': description,
        'requirements': requirements,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id).eq('mentor_id', _currentUserId); // Security: must be owner
    } catch (e) {
      debugPrint('Error updating job posting: $e');
      rethrow;
    }
  }

  // Delete a job posting (UC12)
  Future<void> deleteJobPosting(String id) async {
    try {
      await _supabase
          .from('job_postings')
          .update({'is_deleted': true})
          .eq('id', id)
          .eq('mentor_id', _currentUserId); // Security: must be owner
    } catch (e) {
      debugPrint('Error deleting job posting: $e');
      rethrow;
    }
  }

  // --- JOB APPLICATIONS (UC13, UC14) ---

  // Upload custom CV document to Supabase Storage (documents bucket)
  Future<String> uploadCV(PlatformFile file) async {
    try {
      final bytes = file.bytes;
      final path = file.path;
      final fileName = 'cv_${_currentUserId}_${DateTime.now().millisecondsSinceEpoch}_${file.name.replaceAll(' ', '_')}';
      
      if (bytes != null) {
        await _supabase.storage.from('documents').uploadBinary(fileName, bytes);
      } else if (path != null) {
        await _supabase.storage.from('documents').upload(fileName, File(path));
      } else {
        throw Exception('File bytes and path are both null.');
      }
      
      return _supabase.storage.from('documents').getPublicUrl(fileName);
    } catch (e) {
      debugPrint('Error uploading CV to storage: $e');
      rethrow;
    }
  }

  // Apply for a job posting (UC13)
  Future<void> applyForJob(String jobId, String? coverNote, {String? cvUrl}) async {
    try {
      await _supabase.from('job_applications').insert({
        'job_id': jobId,
        'student_id': _currentUserId,
        'cover_note': coverNote,
        'cv_url': cvUrl,
        'status': 'applied',
      });
    } catch (e) {
      debugPrint('Error applying for job: $e');
      rethrow;
    }
  }

  // Fetch all applications for a specific job posting (UC14)
  Future<List<JobApplication>> fetchApplicationsForJob(String jobId) async {
    try {
      final response = await _supabase
          .from('job_applications')
          .select('*, students:student_id(class_level, student_document_url, users:users!students_id_fkey(first_name, last_name, email, department))')
          .eq('job_id', jobId)
          .order('created_at', ascending: false);

      final List<dynamic> data = response;
      return data.map((json) => JobApplication.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching job applications: $e');
      rethrow;
    }
  }

  // Fetch applications made by the current student (UC13)
  Future<List<Map<String, dynamic>>> fetchMyApplications() async {
    try {
      final response = await _supabase
          .from('job_applications')
          .select('*, job_postings(*, users:mentor_id(first_name, last_name))')
          .eq('student_id', _currentUserId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching my applications: $e');
      rethrow;
    }
  }

  // Check if current student has already applied to a specific job
  Future<JobApplication?> checkMyApplicationStatus(String jobId) async {
    try {
      final response = await _supabase
          .from('job_applications')
          .select('*, students:student_id(class_level, student_document_url, users:users!students_id_fkey(first_name, last_name, email, department))')
          .eq('job_id', jobId)
          .eq('student_id', _currentUserId)
          .maybeSingle();

      if (response == null) return null;
      return JobApplication.fromJson(response);
    } catch (e) {
      debugPrint('Error checking application status: $e');
      return null;
    }
  }

  // Update application status (Accept / Reject) with optional feedback (UC14)
  Future<void> updateApplicationStatus(
    String applicationId,
    String status, // 'accepted' or 'rejected'
    String? feedback,
  ) async {
    try {
      await _supabase.from('job_applications').update({
        'status': status,
        'feedback': feedback,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', applicationId);
    } catch (e) {
      debugPrint('Error updating application status: $e');
      rethrow;
    }
  }
}
