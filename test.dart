void main() {
  Map<String, dynamic> mergedData = {
    "role": "student",
    "students": {
      "interests": ["AI"],
      "available_days": ["Monday"]
    }
  };
  
  final s = mergedData['students'];
  mergedData.addAll(s is List ? (s.isNotEmpty ? s.first as Map<String, dynamic> : {}) : s as Map<String, dynamic>);
  
  print(mergedData);
}
