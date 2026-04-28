import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';

class ApiService {
  final String baseUrl;

  ApiService({String? baseUrl}) : baseUrl = baseUrl ?? (Platform.isAndroid ? 'http://10.0.2.2:3000' : 'http://localhost:3000');

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

  Future<String?> uploadDocument(File file) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/mentor/upload-doc'));
    request.files.add(await http.MultipartFile.fromPath('document', file.path));
    
    final response = await request.send();
    if (response.statusCode == 200 || response.statusCode == 201) {
      final responseBody = await response.stream.bytesToString();
      try {
        final data = jsonDecode(responseBody);
        return data['url'];
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
