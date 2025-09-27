import 'package:flutter/material.dart';

class LogoWidget extends StatelessWidget {
  final String imagePath;
  final double size;
  
  const LogoWidget({
    Key? key,
    required this.imagePath,
    this.size = 120.0,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Image.asset(
      imagePath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: Colors.grey,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.energy_savings_leaf, size: 60, color: Colors.white),
        );
      },
    );
  }
}