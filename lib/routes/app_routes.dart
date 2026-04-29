import 'package:flutter/material.dart';

import '../features/auth/screens/login_page.dart';
import '../features/auth/screens/register_page.dart';
import '../features/student/screens/home_page_student.dart';
import '../features/student/screens/announcements_page.dart';
import '../features/admin/presentation/screens/admin_main_screen.dart';

import '../features/auth/screens/pending_approval_page.dart';
import '../features/mentor/screens/home_page_mentor.dart';

class AppRoutes {
  static const String initialRoute = '/';
  static const String loginRoute = '/';
  static const String registerRoute = '/register';
  static const String studentHomeRoute = '/studentHome';
  static const String announcementsRoute = '/announcements';
  static const String adminRoute = '/admin';
  static const String pendingRoute = '/pending';

  static Map<String, WidgetBuilder> get routes {
    return {
      loginRoute: (context) => const LoginPage(),
      registerRoute: (context) => const RegisterPage(),
      studentHomeRoute: (context) => const HomePageStudent(),
      announcementsRoute: (context) => const AnnouncementsPage(),
      adminRoute: (context) => const AdminMainScreen(),
      pendingRoute: (context) => const PendingApprovalPage(),
      '/mentorHome': (context) => const HomePageMentor(),
    };
  }
}
