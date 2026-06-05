import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import '../models/job_posting_model.dart';
import '../models/job_application_model.dart';
import '../../../core/services/api_service.dart';

class JobService {
  // --- JOB POSTINGS (UC11, UC12) ---
  
  // Fetch all job postings
  Future<List<JobPosting>> fetchJobPostings() async {
    try {
      final List<Map<String, dynamic>> response = await ApiService().fetchJobPostings();
      return response.map((json) => JobPosting.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching job postings: $e');
      rethrow;
    }
  }

  // Fetch only job postings created by the current mentor/admin
  Future<List<JobPosting>> fetchMyJobPostings() async {
    try {
      final List<Map<String, dynamic>> response = await ApiService().fetchMyJobPostings();
      return response.map((json) => JobPosting.fromJson(json)).toList();
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
      await ApiService().createJobPosting(
        title: title,
        company: company,
        description: description,
        requirements: requirements,
      );
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
      await ApiService().updateJobPosting(
        id,
        title: title,
        company: company,
        description: description,
        requirements: requirements,
      );
    } catch (e) {
      debugPrint('Error updating job posting: $e');
      rethrow;
    }
  }

  // Delete a job posting (UC12)
  Future<void> deleteJobPosting(String id) async {
    try {
      await ApiService().deleteJobPosting(id);
    } catch (e) {
      debugPrint('Error deleting job posting: $e');
      rethrow;
    }
  }

  // --- JOB APPLICATIONS (UC13, UC14) ---

  // Upload custom CV document to Supabase Storage via backend API
  Future<String> uploadCV(PlatformFile file) async {
    try {
      return await ApiService().uploadCV(file);
    } catch (e) {
      debugPrint('Error uploading CV to storage: $e');
      rethrow;
    }
  }

  // Apply for a job posting (UC13)
  Future<void> applyForJob(String jobId, String? coverNote, {String? cvUrl}) async {
    try {
      await ApiService().applyForJob(jobId, coverNote, cvUrl);
    } catch (e) {
      debugPrint('Error applying for job: $e');
      rethrow;
    }
  }

  // Fetch all applications for a specific job posting (UC14)
  Future<List<JobApplication>> fetchApplicationsForJob(String jobId) async {
    try {
      final List<Map<String, dynamic>> response = await ApiService().fetchApplicationsForJob(jobId);
      return response.map((json) => JobApplication.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching job applications: $e');
      rethrow;
    }
  }

  // Fetch applications made by the current student (UC13)
  Future<List<Map<String, dynamic>>> fetchMyApplications() async {
    try {
      return await ApiService().fetchMyApplications();
    } catch (e) {
      debugPrint('Error fetching my applications: $e');
      rethrow;
    }
  }

  // Check if current student has already applied to a specific job
  Future<JobApplication?> checkMyApplicationStatus(String jobId) async {
    try {
      final response = await ApiService().checkMyApplicationStatus(jobId);
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
      await ApiService().updateJobApplicationStatus(applicationId, status, feedback);
    } catch (e) {
      debugPrint('Error updating application status: $e');
      rethrow;
    }
  }
}
