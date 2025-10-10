import 'package:flutter/material.dart';

/// Simple responsive helpers.
/// Base width = 375 (iPhone X logical width). Scales relative to shortest side.
class Responsive {
  Responsive._();

  static double _base = 375.0;

  static double scale(BuildContext context) {
    final mq = MediaQuery.of(context);
    final shortest = mq.size.shortestSide; // works for portrait/landscape
    return (shortest / _base).clamp(0.75, 1.4);
  }

  // width percentage
  static double wp(BuildContext context, double percent) =>
      MediaQuery.of(context).size.width * (percent / 100);

  // height percentage
  static double hp(BuildContext context, double percent) =>
      MediaQuery.of(context).size.height * (percent / 100);

  // scale a size value by device scale
  static double s(BuildContext context, double value) => value * scale(context);

  // scale font size
  static double sp(BuildContext context, double fontSize) =>
      (fontSize * scale(context)).clamp(10.0, 42.0);
}
