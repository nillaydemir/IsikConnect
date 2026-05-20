import 'dart:convert';

void main() {
  Map<String, dynamic> userResponse = {
    'id': '123',
    'role': 'mentor',
    'mentors': {
      'available_days': ['Monday', 'Friday'],
      'company': 'Apple'
    }
  };

  final Map<String, dynamic> userDoc = Map<String, dynamic>.from(userResponse);
  
  Map<String, dynamic>? extractData(dynamic data) {
    if (data == null) return null;
    if (data is List && data.isNotEmpty) return Map<String, dynamic>.from(data.first);
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  if (userDoc['role'] == 'mentor') {
    final mentorData = extractData(userDoc['mentors']);
    if (mentorData != null) userDoc.addAll(mentorData);
  }

  print(userDoc);
}
