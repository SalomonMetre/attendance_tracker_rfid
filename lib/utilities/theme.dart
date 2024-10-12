import 'package:flutter/material.dart';

final ThemeData appTheme = ThemeData(
  primaryColor: const Color(0xFF6F35A5), // Purple
  primaryColorLight: const Color(0xFFD1C4E9), // Light Purple
  primaryColorDark: const Color(0xFF4A148C), // Dark Purple
  hintColor: const Color(0xFFFFC107), // Amber
  scaffoldBackgroundColor: const Color(0xFFF3E5F5), // Error Color

  // Text Theme
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.bold,
      color: Color(0xFF3E2723), // Dark Brown
    ),
    headlineMedium: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: Color(0xFF3E2723),
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.normal,
      color: Color(0xFF4A4A4A), // Dark Gray
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: Color(0xFF757575), // Gray
    ),
  ),

  // Button Theme
  buttonTheme: const ButtonThemeData(
    buttonColor: Color(0xFF6F35A5), // Button Color
    textTheme: ButtonTextTheme.primary, // Text Color
  ),

  // Card Theme
  cardTheme: CardTheme(
    color: Colors.white,
    elevation: 4,
    shadowColor: Colors.grey.withOpacity(0.5),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    ),
  ),

  // App Bar Theme
  appBarTheme: const AppBarTheme(
    color: Color(0xFF6F35A5), // AppBar Color
    elevation: 4,
    titleTextStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
    iconTheme: IconThemeData(
      color: Colors.white, // AppBar Icon Color
    ),
  ),

  // Floating Action Button Theme
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: Color(0xFFFFC107), // FAB Color
    foregroundColor: Colors.black, // FAB Icon Color
  ),

  // Divider Theme
  dividerColor: Colors.grey,
  dividerTheme: DividerThemeData(
    thickness: 1,
    color: Colors.grey.shade300,
  ),

  // Input Decoration Theme
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(
        color: Colors.grey.shade400,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(
        color: Color(0xFF6F35A5), // Focused Border Color
      ),
    ),
    hintStyle: TextStyle(
      color: Colors.grey.shade600, // Hint Text Color
    ),
  ),

  // Icon Theme
  iconTheme: const IconThemeData(
    color: Color(0xFF6F35A5), // Default Icon Color
    size: 24,
  ), colorScheme: const ColorScheme.light(),
);
