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
    return jsonDecode(responseBody);
  }

  Future<Map<String, dynamic>> loginMentor(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/mentor/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return jsonDecode(response.body);
  }

  Future<String?> uploadDocument(File file) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/mentor/upload-doc'));
    request.files.add(await http.MultipartFile.fromPath('document', file.path));
    
    final response = await request.send();
    if (response.statusCode == 200) {
      final responseBody = await response.stream.bytesToString();
      final data = jsonDecode(responseBody);
      return data['url'];
    }
    return null;
  }
}
