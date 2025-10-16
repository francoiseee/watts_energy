import 'package:flutter/material.dart';
import 'screens/start_page.dart';

void main() {
  runApp(const WatsEnergyApp());
}

class WatsEnergyApp extends StatelessWidget {
  const WatsEnergyApp({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WattsEnergy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFFF4D35E),
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Roboto',
      ),
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final clampedTextScale = mq.textScaleFactor.clamp(0.85, 1.2);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(clampedTextScale)),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const StartPage(),
    );
  }
}