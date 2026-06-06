import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'current_session.dart';

class ApiService {
  final String baseUrl;

  ApiService({String? baseUrl}) : baseUrl = baseUrl ?? (kIsWeb ? 'http://localhost:3000' : (Platform.isAndroid ? 'http://10.0.2.2:3000' : 'http://localhost:3000'));

  Map<String, String> get _authHeaders {
    final headers = {'Content-Type': 'application/json'};
    if (CurrentSession().token != null) {
      headers['Authorization'] = 'Bearer ${CurrentSession().token}';
    }
    return headers;
  }

  Future<Map<String, dynamic>> registerMentor(Map<String, dynamic> data, dynamic file) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/mentor/register'));
    
    // Add file
    if (!kIsWeb && file is File) {
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
    } else {
      // Handle PlatformFile from file_picker
      final platformFile = file;
      debugPrint('--- Upload Debug ---');
      debugPrint('Name: ${platformFile.name}');
      debugPrint('Path: ${platformFile.path}');
      debugPrint('Bytes: ${platformFile.bytes?.length}');

      if (!kIsWeb && platformFile.path != null) {
        // Mobile / Local path available
        request.files.add(await http.MultipartFile.fromPath('file', platformFile.path!));
      } else if (platformFile.bytes != null) {
        // Web / Desktop without direct path access
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          platformFile.bytes!,
          filename: platformFile.name,
        ));
      } else {
        throw 'No file data available for upload';
      }
    }
    
    // Add other fields
    data.forEach((key, value) {
      if (key == 'available_days' || key == 'interests') {
        request.fields[key] = jsonEncode(value);
      } else {
        request.fields[key] = value?.toString() ?? '';
      }
    });

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    try {
      return jsonDecode(responseBody);
    } catch (_) {
      throw 'Server returned HTML or unknown format (Status ${response.statusCode}). Please check Node.js backend. Response: $responseBody';
    }
  }

  Future<Map<String, dynamic>> registerStudent(Map<String, dynamic> data, dynamic file) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/student/register'));
    
    // Add file
    if (!kIsWeb && file is File) {
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
    } else {
      final platformFile = file;
      if (!kIsWeb && platformFile.path != null) {
        request.files.add(await http.MultipartFile.fromPath('file', platformFile.path!));
      } else if (platformFile.bytes != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          platformFile.bytes!,
          filename: platformFile.name,
        ));
      } else {
        throw 'No file data available for upload';
      }
    }
    
    // Add fields
    data.forEach((key, value) {
      if (key == 'available_days' || key == 'interests') {
        request.fields[key] = jsonEncode(value);
      } else {
        request.fields[key] = value?.toString() ?? '';
      }
    });

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    try {
      return jsonDecode(responseBody);
    } catch (_) {
      throw 'Server returned HTML or unknown format (Status ${response.statusCode}). Please check Node.js backend. Response: $responseBody';
    }
  }

  Future<Map<String, dynamic>> loginMentor(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/mentor/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> loginStudent(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/student/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> loginAdmin(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> loginUnified(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login-unified'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return jsonDecode(response.body);
  }

  Future<List<dynamic>> getPendingApplications() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/applications/pending'),
        headers: _authHeaders,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
    } catch (_) {}
    return [];
  }

  Future<void> updateApplicationStatus(String applicationId, String status) async {
    await http.post(
      Uri.parse('$baseUrl/admin/applications/update'),
      headers: _authHeaders,
      body: jsonEncode({'applicationId': applicationId, 'status': status}),
    );
  }

  Future<Map<String, dynamic>> updateProfile(String userId, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/profile/$userId'),
      headers: _authHeaders,
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) {
      throw 'Error updating profile: ${response.statusCode} - ${response.body}';
    }
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> uploadProfileImage(String userId, dynamic file) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/profile/$userId/image'));
    
    if (file is File) {
      request.files.add(await http.MultipartFile.fromPath('image', file.path));
    } else {
      final platformFile = file;
      if (platformFile.path != null) {
        request.files.add(await http.MultipartFile.fromPath('image', platformFile.path!));
      } else if (platformFile.bytes != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'image',
          platformFile.bytes!,
          filename: platformFile.name,
        ));
      }
    }

    if (CurrentSession().token != null) {
      request.headers['Authorization'] = 'Bearer ${CurrentSession().token}';
    }

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    if (response.statusCode != 200) {
      throw 'Error uploading image: ${response.statusCode} - $responseBody';
    }
    return jsonDecode(responseBody);
  }

  Future<void> deleteAccount(String userId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/account/$userId'),
      headers: _authHeaders,
    );
    if (response.statusCode != 200) {
      throw 'Error deleting account: ${response.statusCode} - ${response.body}';
    }
  }

  Future<void> sendSupportRequest(String subject, String message) async {
    final response = await http.post(
      Uri.parse('$baseUrl/account/support'),
      headers: _authHeaders,
      body: jsonEncode({'subject': subject, 'message': message}),
    );
    if (response.statusCode != 200) {
      throw 'Error sending support request: ${response.statusCode} - ${response.body}';
    }
  }

  Future<void> updatePassword(String currentPassword, String newPassword) async {
    final hashedCurrent = sha256.convert(utf8.encode(currentPassword)).toString();
    final hashedNew = sha256.convert(utf8.encode(newPassword)).toString();
    final response = await http.post(
      Uri.parse('$baseUrl/account/change-password'),
      headers: _authHeaders,
      body: jsonEncode({
        'currentPassword': hashedCurrent,
        'newPassword': hashedNew,
      }),
    );
    if (response.statusCode != 200) {
      Map<String, dynamic> errorBody = {};
      try {
        errorBody = jsonDecode(response.body);
      } catch (_) {}
      throw errorBody['error'] ?? 'Failed to update password.';
    }
  }

  Future<Map<String, dynamic>> rateMentor(String mentorId, int rating, String comment) async {
    final response = await http.post(
      Uri.parse('$baseUrl/student/rate-mentor'),
      headers: _authHeaders,
      body: jsonEncode({
        'mentor_id': mentorId,
        'rating': rating,
        'comment': comment,
      }),
    );
    if (response.statusCode != 200) {
      throw 'Error rating mentor: ${response.statusCode} - ${response.body}';
    }
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>?> runMatchingAlgorithm() async {
    final response = await http.post(
      Uri.parse('$baseUrl/matching/run'),
      headers: _authHeaders,
    );
    if (response.statusCode != 200) {
      Map<String, dynamic> errorBody = {};
      try {
        errorBody = jsonDecode(response.body);
      } catch (_) {}
      throw errorBody['message'] ?? 'Error running matching: ${response.statusCode} - ${response.body}';
    }
    final data = jsonDecode(response.body);
    return data['mentor'] != null ? Map<String, dynamic>.from(data['mentor']) : null;
  }

  Future<void> cancelMentorship(String studentId, String mentorId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/matching/cancel'),
      headers: _authHeaders,
      body: jsonEncode({
        'studentId': studentId,
        'mentorId': mentorId,
      }),
    );
    if (response.statusCode != 200) {
      Map<String, dynamic> errorBody = {};
      try {
        errorBody = jsonDecode(response.body);
      } catch (_) {}
      throw errorBody['message'] ?? 'Error cancelling match: ${response.statusCode} - ${response.body}';
    }
  }

  Future<int> getStudentCancelledCount(String studentId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/matching/cancelled-count/student/$studentId'),
      headers: _authHeaders,
    );
    if (response.statusCode != 200) {
      throw 'Error getting student cancellations count: ${response.statusCode} - ${response.body}';
    }
    final data = jsonDecode(response.body);
    return data['count'] as int;
  }

  Future<int> getMentorCancelledCount(String mentorId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/matching/cancelled-count/mentor/$mentorId'),
      headers: _authHeaders,
    );
    if (response.statusCode != 200) {
      throw 'Error getting mentor cancellations count: ${response.statusCode} - ${response.body}';
    }
    final data = jsonDecode(response.body);
    return data['count'] as int;
  }

  Future<void> createMeeting({
    required String title,
    required String type,
    required String meetingDate,
    String? studentId,
    int? capacity,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/meetings'),
      headers: _authHeaders,
      body: jsonEncode({
        'title': title,
        'meeting_type': type,
        'meeting_date': meetingDate,
        'student_id': studentId,
        'capacity': capacity,
      }),
    );
    if (response.statusCode != 201) {
      Map<String, dynamic> errorBody = {};
      try {
        errorBody = jsonDecode(response.body);
      } catch (_) {}
      throw errorBody['message'] ?? 'Failed to create meeting: ${response.statusCode} - ${response.body}';
    }
  }

  Future<List<Map<String, dynamic>>> getMeetings() async {
    final response = await http.get(
      Uri.parse('$baseUrl/meetings'),
      headers: _authHeaders,
    );
    if (response.statusCode != 200) {
      throw 'Failed to retrieve meetings: ${response.statusCode} - ${response.body}';
    }
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<List<Map<String, dynamic>>> getMentees() async {
    final response = await http.get(
      Uri.parse('$baseUrl/meetings/mentees'),
      headers: _authHeaders,
    );
    if (response.statusCode != 200) {
      throw 'Failed to retrieve mentees: ${response.statusCode} - ${response.body}';
    }
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> registerForWorkshop(String meetingId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/meetings/$meetingId/register'),
      headers: _authHeaders,
    );
    if (response.statusCode != 200) {
      Map<String, dynamic> errorBody = {};
      try {
        errorBody = jsonDecode(response.body);
      } catch (_) {}
      throw errorBody['message'] ?? 'Failed to register for workshop: ${response.statusCode} - ${response.body}';
    }
  }

  Future<void> unregisterFromWorkshop(String meetingId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/meetings/$meetingId/unregister'),
      headers: _authHeaders,
    );
    if (response.statusCode != 200) {
      Map<String, dynamic> errorBody = {};
      try {
        errorBody = jsonDecode(response.body);
      } catch (_) {}
      throw errorBody['message'] ?? 'Failed to unregister from workshop: ${response.statusCode} - ${response.body}';
    }
  }

  Future<void> deleteMeeting(String meetingId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/meetings/$meetingId'),
      headers: _authHeaders,
    );
    if (response.statusCode != 200) {
      throw 'Failed to delete meeting: ${response.statusCode} - ${response.body}';
    }
  }

  Future<void> updateMeeting(String meetingId, String meetingDate) async {
    final response = await http.put(
      Uri.parse('$baseUrl/meetings/$meetingId'),
      headers: _authHeaders,
      body: jsonEncode({
        'meeting_date': meetingDate,
      }),
    );
    if (response.statusCode != 200) {
      Map<String, dynamic> errorBody = {};
      try {
        errorBody = jsonDecode(response.body);
      } catch (_) {}
      throw errorBody['message'] ?? 'Failed to update meeting: ${response.statusCode} - ${response.body}';
    }
  }

  Future<Map<String, dynamic>?> getMeetingDetails(String meetingId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/meetings/$meetingId'),
      headers: _authHeaders,
    );
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw 'Failed to retrieve meeting details: ${response.statusCode} - ${response.body}';
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> joinMeeting(String meetingId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/meetings/$meetingId/join'),
      headers: _authHeaders,
    );
    if (response.statusCode != 200) {
      throw 'Failed to mark meeting joined: ${response.statusCode} - ${response.body}';
    }
  }

  Future<List<Map<String, dynamic>>> fetchJobPostings() async {
    final response = await http.get(
      Uri.parse('$baseUrl/jobs'),
      headers: _authHeaders,
    );
    if (response.statusCode != 200) {
      throw 'Failed to fetch job postings: ${response.statusCode} - ${response.body}';
    }
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchMyJobPostings() async {
    final response = await http.get(
      Uri.parse('$baseUrl/jobs/my-postings'),
      headers: _authHeaders,
    );
    if (response.statusCode != 200) {
      throw 'Failed to fetch my job postings: ${response.statusCode} - ${response.body}';
    }
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> createJobPosting({
    required String title,
    required String company,
    required String description,
    required String requirements,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/jobs'),
      headers: _authHeaders,
      body: jsonEncode({
        'title': title,
        'company': company,
        'description': description,
        'requirements': requirements,
      }),
    );
    if (response.statusCode != 201) {
      Map<String, dynamic> errorBody = {};
      try {
        errorBody = jsonDecode(response.body);
      } catch (_) {}
      throw errorBody['message'] ?? 'Failed to create job posting: ${response.statusCode} - ${response.body}';
    }
  }

  Future<void> updateJobPosting(
    String id, {
    required String title,
    required String company,
    required String description,
    required String requirements,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/jobs/$id'),
      headers: _authHeaders,
      body: jsonEncode({
        'title': title,
        'company': company,
        'description': description,
        'requirements': requirements,
      }),
    );
    if (response.statusCode != 200) {
      Map<String, dynamic> errorBody = {};
      try {
        errorBody = jsonDecode(response.body);
      } catch (_) {}
      throw errorBody['message'] ?? 'Failed to update job posting: ${response.statusCode} - ${response.body}';
    }
  }

  Future<void> deleteJobPosting(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/jobs/$id'),
      headers: _authHeaders,
    );
    if (response.statusCode != 200) {
      throw 'Failed to delete job posting: ${response.statusCode} - ${response.body}';
    }
  }

  Future<String> uploadCV(dynamic file) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/jobs/upload-cv'));
    
    if (file is File) {
      request.files.add(await http.MultipartFile.fromPath('cv', file.path));
    } else {
      final platformFile = file;
      if (platformFile.path != null) {
        request.files.add(await http.MultipartFile.fromPath('cv', platformFile.path!));
      } else if (platformFile.bytes != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'cv',
          platformFile.bytes!,
          filename: platformFile.name,
        ));
      } else {
        throw 'No file data available for upload';
      }
    }

    if (CurrentSession().token != null) {
      request.headers['Authorization'] = 'Bearer ${CurrentSession().token}';
    }

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    if (response.statusCode != 200) {
      throw 'Error uploading CV: ${response.statusCode} - $responseBody';
    }
    final data = jsonDecode(responseBody);
    return data['cvUrl'] as String;
  }

  Future<void> applyForJob(String jobId, String? coverNote, String? cvUrl) async {
    final response = await http.post(
      Uri.parse('$baseUrl/jobs/$jobId/apply'),
      headers: _authHeaders,
      body: jsonEncode({
        'cover_note': coverNote,
        'cv_url': cvUrl,
      }),
    );
    if (response.statusCode != 201) {
      Map<String, dynamic> errorBody = {};
      try {
        errorBody = jsonDecode(response.body);
      } catch (_) {}
      throw errorBody['message'] ?? 'Failed to apply for job: ${response.statusCode} - ${response.body}';
    }
  }

  Future<List<Map<String, dynamic>>> fetchApplicationsForJob(String jobId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/jobs/$jobId/applications'),
      headers: _authHeaders,
    );
    if (response.statusCode != 200) {
      throw 'Failed to fetch job applications: ${response.statusCode} - ${response.body}';
    }
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchMyApplications() async {
    final response = await http.get(
      Uri.parse('$baseUrl/jobs/my-applications'),
      headers: _authHeaders,
    );
    if (response.statusCode != 200) {
      throw 'Failed to fetch my applications: ${response.statusCode} - ${response.body}';
    }
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<Map<String, dynamic>?> checkMyApplicationStatus(String jobId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/jobs/$jobId/application-status'),
      headers: _authHeaders,
    );
    if (response.statusCode != 200) {
      throw 'Failed to check application status: ${response.statusCode} - ${response.body}';
    }
    final data = jsonDecode(response.body);
    return data != null ? Map<String, dynamic>.from(data) : null;
  }

  Future<void> updateJobApplicationStatus(
    String applicationId,
    String status,
    String? feedback,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/jobs/applications/$applicationId/status'),
      headers: _authHeaders,
      body: jsonEncode({
        'status': status,
        'feedback': feedback,
      }),
    );
    if (response.statusCode != 200) {
      Map<String, dynamic> errorBody = {};
      try {
        errorBody = jsonDecode(response.body);
      } catch (_) {}
      throw errorBody['message'] ?? 'Failed to update application status: ${response.statusCode} - ${response.body}';
    }
  }

  Future<List<Map<String, dynamic>>> fetchPosts(String? category) async {
    final uri = Uri.parse('$baseUrl/forum/posts').replace(
      queryParameters: category != null ? {'category': category} : null,
    );
    final response = await http.get(uri, headers: _authHeaders);
    if (response.statusCode != 200) {
      throw 'Failed to fetch forum posts: ${response.statusCode} - ${response.body}';
    }
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<Map<String, dynamic>> fetchPostDetails(String postId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/forum/posts/$postId'),
      headers: _authHeaders,
    );
    if (response.statusCode != 200) {
      throw 'Failed to fetch post details: ${response.statusCode} - ${response.body}';
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> fetchComments(String postId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/forum/posts/$postId/comments'),
      headers: _authHeaders,
    );
    if (response.statusCode != 200) {
      throw 'Failed to fetch comments: ${response.statusCode} - ${response.body}';
    }
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> createPost({
    required String category,
    required String title,
    required String content,
    String? imageUrl,
    List<String> tags = const [],
    String? eventDate,
    String? meetingLink,
    int? participantLimit,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/forum/posts'),
      headers: _authHeaders,
      body: jsonEncode({
        'category': category,
        'title': title,
        'content': content,
        'image_url': imageUrl,
        'tags': tags,
        'event_date': eventDate,
        'meeting_link': meetingLink,
        'participant_limit': participantLimit,
      }),
    );
    if (response.statusCode != 201) {
      Map<String, dynamic> errorBody = {};
      try {
        errorBody = jsonDecode(response.body);
      } catch (_) {}
      throw errorBody['message'] ?? 'Failed to create post: ${response.statusCode} - ${response.body}';
    }
  }

  Future<void> addComment(String postId, String content) async {
    final response = await http.post(
      Uri.parse('$baseUrl/forum/posts/$postId/comments'),
      headers: _authHeaders,
      body: jsonEncode({'content': content}),
    );
    if (response.statusCode != 201) {
      Map<String, dynamic> errorBody = {};
      try {
        errorBody = jsonDecode(response.body);
      } catch (_) {}
      throw errorBody['message'] ?? 'Failed to add comment: ${response.statusCode} - ${response.body}';
    }
  }

  Future<void> toggleLike(String postId, bool isCurrentlyLiked) async {
    final response = await http.post(
      Uri.parse('$baseUrl/forum/posts/$postId/like'),
      headers: _authHeaders,
      body: jsonEncode({'isCurrentlyLiked': isCurrentlyLiked}),
    );
    if (response.statusCode != 200) {
      throw 'Failed to toggle like: ${response.statusCode} - ${response.body}';
    }
  }

  Future<void> acceptAnswer(String postId, String commentId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/forum/posts/$postId/accept-answer'),
      headers: _authHeaders,
      body: jsonEncode({'commentId': commentId}),
    );
    if (response.statusCode != 200) {
      Map<String, dynamic> errorBody = {};
      try {
        errorBody = jsonDecode(response.body);
      } catch (_) {}
      throw errorBody['message'] ?? 'Failed to accept answer: ${response.statusCode} - ${response.body}';
    }
  }

  Future<void> deletePost(String postId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/forum/posts/$postId'),
      headers: _authHeaders,
    );
    if (response.statusCode != 200) {
      throw 'Failed to delete post: ${response.statusCode} - ${response.body}';
    }
  }

  Future<void> deleteComment(String commentId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/forum/comments/$commentId'),
      headers: _authHeaders,
    );
    if (response.statusCode != 200) {
      throw 'Failed to delete comment: ${response.statusCode} - ${response.body}';
    }
  }

  Future<void> updatePost({
    required String postId,
    required String category,
    required String title,
    required String content,
    String? imageUrl,
    String? meetingLink,
    String? eventDate,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/forum/posts/$postId'),
      headers: _authHeaders,
      body: jsonEncode({
        'category': category,
        'title': title,
        'content': content,
        'image_url': imageUrl,
        'meeting_link': meetingLink,
        'event_date': eventDate,
      }),
    );
    if (response.statusCode != 200) {
      Map<String, dynamic> errorBody = {};
      try {
        errorBody = jsonDecode(response.body);
      } catch (_) {}
      throw errorBody['message'] ?? 'Failed to update post: ${response.statusCode} - ${response.body}';
    }
  }

  Future<void> markPostAsRead(String postId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/forum/posts/read'),
      headers: _authHeaders,
      body: jsonEncode({'postId': postId}),
    );
    if (response.statusCode != 200) {
      throw 'Failed to mark post as read: ${response.statusCode} - ${response.body}';
    }
  }

  Future<List<String>> fetchReadPostIds() async {
    final response = await http.get(
      Uri.parse('$baseUrl/forum/posts/read-ids'),
      headers: _authHeaders,
    );
    if (response.statusCode != 200) {
      throw 'Failed to fetch read post IDs: ${response.statusCode} - ${response.body}';
    }
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((e) => e.toString()).toList();
  }

  Future<String> uploadForumImage(dynamic file) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/forum/upload-image'));
    
    if (file is File) {
      request.files.add(await http.MultipartFile.fromPath('image', file.path));
    } else {
      final platformFile = file;
      if (platformFile.path != null) {
        request.files.add(await http.MultipartFile.fromPath('image', platformFile.path!));
      } else if (platformFile.bytes != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'image',
          platformFile.bytes!,
          filename: platformFile.name,
        ));
      } else {
        throw 'No file data available for upload';
      }
    }

    if (CurrentSession().token != null) {
      request.headers['Authorization'] = 'Bearer ${CurrentSession().token}';
    }

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    if (response.statusCode != 200) {
      throw 'Error uploading forum image: ${response.statusCode} - $responseBody';
    }
    final data = jsonDecode(responseBody);
    return data['imageUrl'] as String;
  }

  // Profile operations
  Future<List<dynamic>> fetchDepartments() async {
    final response = await http.get(
      Uri.parse('$baseUrl/profile/departments'),
      headers: _authHeaders,
    );
    if (response.statusCode != 200) {
      throw 'Failed to fetch departments: ${response.statusCode} - ${response.body}';
    }
    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> fetchUserById(String userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/profile/$userId'),
      headers: _authHeaders,
    );
    if (response.statusCode != 200) {
      throw 'Failed to fetch user by ID: ${response.statusCode} - ${response.body}';
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> fetchMentorReviews(String userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/profile/$userId/reviews'),
      headers: _authHeaders,
    );
    if (response.statusCode != 200) {
      throw 'Failed to fetch reviews: ${response.statusCode} - ${response.body}';
    }
    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<void> deleteProfileImage(String userId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/profile/$userId/image'),
      headers: _authHeaders,
    );
    if (response.statusCode != 200) {
      throw 'Failed to delete profile image: ${response.statusCode} - ${response.body}';
    }
  }

  Future<Map<String, dynamic>> fetchLastLogin(String userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/profile/$userId/last-login'),
      headers: _authHeaders,
    );
    if (response.statusCode != 200) {
      throw 'Failed to fetch last login: ${response.statusCode} - ${response.body}';
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // Admin operations
  Future<List<dynamic>> fetchAdminUsers() async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/users'),
      headers: _authHeaders,
    );
    if (response.statusCode != 200) {
      throw 'Failed to fetch admin users: ${response.statusCode} - ${response.body}';
    }
    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<void> updateAdminUserField(String userId, String field, dynamic value) async {
    final response = await http.put(
      Uri.parse('$baseUrl/admin/users/$userId'),
      headers: _authHeaders,
      body: jsonEncode({
        'field': field,
        'value': value,
      }),
    );
    if (response.statusCode != 200) {
      throw 'Failed to update user field: ${response.statusCode} - ${response.body}';
    }
  }

  Future<Map<String, dynamic>> fetchAdminStats() async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/stats'),
      headers: _authHeaders,
    );
    if (response.statusCode != 200) {
      throw 'Failed to fetch admin statistics: ${response.statusCode} - ${response.body}';
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> fetchSupportTickets() async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/tickets'),
      headers: _authHeaders,
    );
    if (response.statusCode != 200) {
      throw 'Failed to fetch support tickets: ${response.statusCode} - ${response.body}';
    }
    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<List<dynamic>> fetchAllReviews() async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/reviews'),
      headers: _authHeaders,
    );
    if (response.statusCode != 200) {
      throw 'Failed to fetch reviews: ${response.statusCode} - ${response.body}';
    }
    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<void> updateTicket(String ticketId, Map<String, dynamic> updateData) async {
    final response = await http.put(
      Uri.parse('$baseUrl/admin/tickets/$ticketId'),
      headers: _authHeaders,
      body: jsonEncode(updateData),
    );
    if (response.statusCode != 200) {
      throw 'Failed to update ticket: ${response.statusCode} - ${response.body}';
    }
  }

  Future<void> sendAdminMessage(String receiverId, String content) async {
    final response = await http.post(
      Uri.parse('$baseUrl/admin/messages'),
      headers: _authHeaders,
      body: jsonEncode({
        'receiver_id': receiverId,
        'content': content,
      }),
    );
    if (response.statusCode != 200) {
      throw 'Failed to send admin message: ${response.statusCode} - ${response.body}';
    }
  }

  // Messaging operations
  Future<List<dynamic>> fetchConversations() async {
    final response = await http.get(
      Uri.parse('$baseUrl/messages/conversations'),
      headers: _authHeaders,
    );
    if (response.statusCode != 200) {
      throw 'Failed to fetch conversations: ${response.statusCode} - ${response.body}';
    }
    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<List<Map<String, dynamic>>> fetchChat(String targetUserId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/messages/chat/$targetUserId'),
      headers: _authHeaders,
    );
    if (response.statusCode != 200) {
      throw 'Failed to fetch chat messages: ${response.statusCode} - ${response.body}';
    }
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<Map<String, dynamic>> sendMessage(String receiverId, String content) async {
    final response = await http.post(
      Uri.parse('$baseUrl/messages/send'),
      headers: _authHeaders,
      body: jsonEncode({
        'receiver_id': receiverId,
        'content': content,
      }),
    );
    if (response.statusCode != 201) {
      throw 'Failed to send message: ${response.statusCode} - ${response.body}';
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> markMessagesAsRead(String targetUserId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/messages/mark-read'),
      headers: _authHeaders,
      body: jsonEncode({
        'senderId': targetUserId,
      }),
    );
    if (response.statusCode != 200) {
      throw 'Failed to mark messages as read: ${response.statusCode} - ${response.body}';
    }
  }

  Future<void> deleteChat(String targetUserId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/messages/delete-chat'),
      headers: _authHeaders,
      body: jsonEncode({
        'targetUserId': targetUserId,
      }),
    );
    if (response.statusCode != 200) {
      throw 'Failed to delete chat: ${response.statusCode} - ${response.body}';
    }
  }

  Future<Map<String, dynamic>> checkConnectionStatus(String targetUserId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/messages/connection-status/$targetUserId'),
      headers: _authHeaders,
    );
    if (response.statusCode != 200) {
      throw 'Failed to check connection status: ${response.statusCode} - ${response.body}';
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> fetchWorkshopParticipants(String meetingId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/meetings/$meetingId/participants'),
      headers: _authHeaders,
    );
    if (response.statusCode != 200) {
      throw 'Failed to fetch workshop participants: ${response.statusCode} - ${response.body}';
    }
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<Map<String, dynamic>?> fetchActiveMatch() async {
    final response = await http.get(
      Uri.parse('$baseUrl/matching/active'),
      headers: _authHeaders,
    );
    if (response.statusCode != 200) {
      throw 'Failed to fetch active match: ${response.statusCode} - ${response.body}';
    }
    final Map<String, dynamic> data = jsonDecode(response.body);
    return data;
  }
}
