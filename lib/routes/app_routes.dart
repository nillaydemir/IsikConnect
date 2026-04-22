import 'package:flutter/material.dart';

import '../features/auth/screens/login_page.dart';
import '../features/auth/screens/register_page.dart';
import '../features/student/screens/home_page_student.dart';
import '../features/student/screens/announcements_page.dart';

class AppRoutes {
  static const String initialRoute = '/';
  static const String registerRoute = '/register';
  static const String studentHomeRoute = '/studentHome';
  static const String announcementsRoute = '/announcements';

  static Map<String, WidgetBuilder> get routes {
    return {
      initialRoute: (context) => const LoginPage(),
      registerRoute: (context) => const RegisterPage(),
      studentHomeRoute: (context) => const HomePageStudent(),
      announcementsRoute: (context) => const AnnouncementsPage(),
    };
  }
}
