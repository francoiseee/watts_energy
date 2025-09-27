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
      home: const StartPage(),
    );
  }
}