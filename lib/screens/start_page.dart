import 'package:flutter/material.dart';
import '../app/app_theme.dart';
import '../app/responsive.dart';
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
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background gradient across the entire screen
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: AppTheme.backgroundGradient,
              ),
            ),
          ),
          // White overlay gradient across the entire screen
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
          SafeArea(
            child: Padding(
              padding: EdgeInsets.all(Responsive.s(context, 20)),
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + Responsive.s(context, 12),
                ),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                    SizedBox(height: Responsive.hp(context, 3)),
                    
                    // Logo 
                    LogoWidget(
                      imagePath: 'assets/logo.png',
                      size: Responsive.s(context, 160),
                    ),
                    
                    
                    SizedBox(height: Responsive.hp(context, 2.5)),
                    
                    // App Name with split colors - Watts (Black) + Energy (White)
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: Responsive.sp(context, 34),
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
                    
                    SizedBox(height: Responsive.hp(context, 1)),
                    
                    // Slogan
                    Text(
                      AppConstants.slogan,
                      style: AppTheme.subtitleTextStyle.copyWith(
                        fontFamily: 'VarelaRound', // Apply rounded font to slogan too
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    SizedBox(height: Responsive.hp(context, 2.5)),
                    
                    // Glass container with description
                    GlassContainer(
                      padding: EdgeInsets.all(Responsive.s(context, 18)),
                      child: Column(
                        children: [
                          Text(
                            AppConstants.description,
                            style: AppTheme.bodyTextStyle.copyWith(
                              fontFamily: 'VarelaRound', // Apply rounded font to description
                            ),
                            textAlign: TextAlign.center,
                          ),
                          
                          SizedBox(height: Responsive.s(context, 14)),
                          
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
                    
                    SizedBox(height: Responsive.hp(context, 2.5)),
                    
                    // Divider
                    Container(
                      height: 1,
                      width: double.infinity,
                      color: Colors.black.withOpacity(0.2),
                      margin: EdgeInsets.symmetric(horizontal: Responsive.s(context, 16)),
                    ),
                    
                    SizedBox(height: Responsive.hp(context, 2)),
                    
                    // Start Button
                    GradientButton(
                      text: AppConstants.startButtonText,
                      onPressed: () => _onStartPressed(context),
                    ),
                    
                    SizedBox(height: Responsive.hp(context, 1.5)),
                    
                    // Footer text
                    const Text(
                      '© 2024 WatsEnergy. All rights reserved.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        fontFamily: 'VarelaRound', // Apply rounded font to footer
                      ),
                    ),
                    
                    SizedBox(height: Responsive.s(context, 10)),
                ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}