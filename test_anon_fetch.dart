import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';

Future<void> main() async {
  var env = File('.env').readAsStringSync();
  var url = '';
  var key = '';
  for (var line in env.split('\n')) {
    if (line.startsWith('SUPABASE_URL=')) url = line.split('=')[1];
    if (line.startsWith('SUPABASE_ANON_KEY=')) key = line.split('=')[1];
  }
  
  final supabase = SupabaseClient(url, key);
  
  final res = await supabase.from('users').select('*, students(*), mentors(*)').eq('email', 'student6@test.com').maybeSingle();
  
  print('Anon response: $res');
}
