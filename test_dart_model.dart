import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';

Future<void> main() async {
  var env = File('.env').readAsStringSync();
  var url = '';
  var key = '';
  for (var line in env.split('\n')) {
    if (line.startsWith('SUPABASE_URL=')) url = line.split('=')[1];
    if (line.startsWith('SUPABASE_SERVICE_ROLE_KEY=')) key = line.split('=')[1];
  }
  
  final supabase = SupabaseClient(url, key);
  
  final res = await supabase.from('users').select('*, students(*), mentors(*)').eq('email', 'student6@test.com').single();
  
  final Map<String, dynamic> userDoc = Map<String, dynamic>.from(res);
  Map<String, dynamic>? extractData(dynamic data) {
    if (data == null) return null;
    if (data is List && data.isNotEmpty) return Map<String, dynamic>.from(data.first);
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }
  if (userDoc['role'] == 'student') {
    final studentData = extractData(userDoc['students']);
    if (studentData != null) userDoc.addAll(studentData);
  }
  print(userDoc['available_days']);
  print(userDoc['interests']);
  print(userDoc['department']);
}
