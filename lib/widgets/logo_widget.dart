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
        // If .ong requested and missing, try .png fallback automatically.
        if (imagePath.endsWith('.ong')) {
          final fallback = imagePath.substring(0, imagePath.length - 3) + 'png';
          return Image.asset(
            fallback,
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