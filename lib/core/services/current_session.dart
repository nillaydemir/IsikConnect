import '../models/app_user_model.dart';

class CurrentSession {
  // Singleton pattern for easy global access
  static final CurrentSession _instance = CurrentSession._internal();
  factory CurrentSession() => _instance;
  CurrentSession._internal();

  AppUser? user;

  // Clear session on logout
  void clear() {
    user = null;
  }
}
