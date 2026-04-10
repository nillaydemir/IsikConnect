import 'package:flutter/material.dart';
import 'core/theme/theme.dart';
import 'routes/app_routes.dart';

void main() {
  runApp(const IsikConnectApp());
}

class IsikConnectApp extends StatelessWidget {
  const IsikConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IsikConnect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: AppRoutes.initialRoute,
      routes: AppRoutes.routes,
    );
  }
}
