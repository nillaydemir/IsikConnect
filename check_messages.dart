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
  
  // Just testing if we can fetch all distinct communicators
  final res1 = await supabase.from('messages').select('sender_id').eq('receiver_id', 'some_id');
  print(res1);
}
