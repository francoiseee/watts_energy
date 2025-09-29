import 'package:flutter/material.dart';
import '../app/app_theme.dart';
import '../app/constants.dart';
import '../widgets/glass_container.dart';
import '../widgets/gradient_button.dart';
import '../widgets/logo_widget.dart';
import 'homepage.dart';

class StartPage extends StatelessWidget {
  const StartPage({Key? key}) : super(key: key);
  
  void _onStartPressed(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // White gradient overlay
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x22FFFFFF),
                        Color(0x44FFFFFF),
                        Color(0x22FFFFFF),
                      ],
                      stops: [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    
                    // Logo 
                    const LogoWidget(imagePath: 'assets/logo.png',
                    size: 180.0,
                    ),
                    
                    
                    const SizedBox(height: 40),
                    
                    // App Name with split colors - Watts (Black) + Energy (White)
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 38, // Slightly larger for rounded font
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          fontFamily: 'VarelaRound', // Using your custom rounded font
                        ),
                        children: [
                          const TextSpan(
                            text: 'Watts',
                            style: TextStyle(
                              color: AppTheme.black,
                              shadows: [
                                Shadow(
                                  color: Colors.black26,
                                  blurRadius: 3,
                                  offset: Offset(1, 1),
                                ),
                              ],
                            ),
                          ),
                          TextSpan(
                            text: 'Energy',
                            style: TextStyle(
                              color: AppTheme.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.4),
                                  blurRadius: 5,
                                  offset: const Offset(2, 2),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 10),
                    
                    // Slogan
                    Text(
                      AppConstants.slogan,
                      style: AppTheme.subtitleTextStyle.copyWith(
                        fontFamily: 'VarelaRound', // Apply rounded font to slogan too
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Glass container with description
                    GlassContainer(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          Text(
                            AppConstants.description,
                            style: AppTheme.bodyTextStyle.copyWith(
                              fontFamily: 'VarelaRound', // Apply rounded font to description
                            ),
                            textAlign: TextAlign.center,
                          ),
                          
                          const SizedBox(height: 20),
                          
                          Text(
                            AppConstants.ctaText,
                            style: AppTheme.bodyTextStyle.copyWith(
                              fontWeight: FontWeight.bold,
                              fontStyle: FontStyle.italic,
                              fontFamily: 'VarelaRound', // Apply rounded font to CTA
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Divider
                    Container(
                      height: 1,
                      width: double.infinity,
                      color: Colors.black.withOpacity(0.2),
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // Start Button
                    GradientButton(
                      text: AppConstants.startButtonText,
                      onPressed: () => _onStartPressed(context),
                    ),
                    
                    const Spacer(),
                    
                    // Footer text
                    const Text(
                      '© 2024 WatsEnergy. All rights reserved.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        fontFamily: 'VarelaRound', // Apply rounded font to footer
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}