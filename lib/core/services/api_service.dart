import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'current_session.dart';

class ApiService {
  final String baseUrl;

  ApiService({String? baseUrl}) : baseUrl = baseUrl ?? (Platform.isAndroid ? 'http://10.0.2.2:3000' : 'http://localhost:3000');

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
    if (file is File) {
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
    } else {
      // Handle PlatformFile from file_picker
      final platformFile = file;
      print('--- Upload Debug ---');
      print('Name: ${platformFile.name}');
      print('Path: ${platformFile.path}');
      print('Bytes: ${platformFile.bytes?.length}');

      if (platformFile.path != null) {
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
    if (file is File) {
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
    } else {
      final platformFile = file;
      if (platformFile.path != null) {
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

  Future<List<dynamic>> getPendingApplications() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/admin/applications/pending'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
    } catch (_) {}
    return [];
  }

  Future<void> updateApplicationStatus(String applicationId, String status) async {
    await http.post(
      Uri.parse('$baseUrl/admin/applications/update'),
      headers: {'Content-Type': 'application/json'},
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

  Future<void> updatePassword(String newPassword) async {
    // Supabase has a direct flutter package method to update password if the user is authenticated.
    // So we use the flutter SDK directly instead of node.js backend.
    final response = await Supabase.instance.client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
    if (response.user == null) {
      throw 'Failed to update password.';
    }
  }
}
