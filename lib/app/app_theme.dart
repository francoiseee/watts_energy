import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryYellow = Color(0xFFF4D35E);
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  
  // Updated gradient - yellow background with white overlay
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      primaryYellow,
      Color(0xFFF8E88B),
      Color(0xFFF4D35E),
    ],
    stops: [0.0, 0.5, 1.0],
  );
  
  // White overlay gradient for the glass effect
  static const LinearGradient whiteOverlayGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x22FFFFFF),
      Color(0x11FFFFFF),
      Color(0x08FFFFFF),
    ],
  );
  
  static const TextStyle titleTextStyle = TextStyle(
    fontSize: 38,
    fontWeight: FontWeight.w900,
    color: black,
    letterSpacing: 1.2,
    fontFamily: 'VarelaRound', // Added rounded font
  );
  
  static const TextStyle subtitleTextStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w300,
    color: black,
    height: 1.5,
    fontFamily: 'VarelaRound', // Added rounded font
  );
  
  static const TextStyle bodyTextStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: black,
    height: 1.4,
    fontFamily: 'VarelaRound', // Added rounded font
  );
}