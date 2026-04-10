import 'package:flutter/material.dart';

// Import feature screens here as they are developed
// import '../features/auth/screens/login_screen.dart';

class AppRoutes {
  static const String initialRoute = '/';

  static Map<String, WidgetBuilder> get routes {
    return {
      initialRoute: (context) => const PlaceholderScreen(title: 'Home / Splash'),
      // '/login': (context) => const LoginScreen(),
    };
  }
}

// Temporary placeholder for initial boilerplate
class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('Welcome to $title')),
    );
  }
}
