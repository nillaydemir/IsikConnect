import 'package:flutter/material.dart';

class AppTheme {
  // Define custom colors, fonts, and text themes here
  static ThemeData get lightTheme {
    return ThemeData(
      primarySwatch: Colors.blue,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      // Add more specific theme properties later
    );
  }

  // Add dark theme if needed
}
