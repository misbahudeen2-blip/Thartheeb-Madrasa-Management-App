import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _floatController;
  late AnimationController _fadeController;
  late AnimationController _progressController;
  late Animation<double> _floatAnimation;
  late Animation<double> _logoFade;
  late Animation<double> _titleFade;
  late Animation<double> _subtitleFade;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();

    // Float animation for logo
    _floatController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    // Fade animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..forward();
    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );
    _titleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.3, 0.6, curve: Curves.easeOut),
      ),
    );
    _subtitleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.5, 0.8, curve: Curves.easeOut),
      ),
    );

    // Progress bar
    _progressController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..forward();
    _progressAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );

    // Auto navigate after 3.5 seconds
    Future.delayed(const Duration(milliseconds: 3500), _navigateNext);
  }

  Future<void> _navigateNext() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final tenantId = prefs.getString('tenant_id');
    if (tenantId != null && tenantId.isNotEmpty) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  void dispose() {
    _floatController.dispose();
    _fadeController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.splashGradientStart,
              AppTheme.splashGradientMid,
              AppTheme.splashGradientEnd,
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Islamic geometric pattern overlay
              Positioned.fill(
                child: Opacity(
                  opacity: 0.04,
                  child: CustomPaint(painter: _GeometricPatternPainter()),
                ),
              ),

              // Skip intro button
              Positioned(
                top: 16,
                right: 16,
                child: FadeTransition(
                  opacity: _subtitleFade,
                  child: TextButton(
                    onPressed: _navigateNext,
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.brandTitle,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    child: Text(
                      'Skip Intro ›',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),

              // Center content
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo with glow and float animation
                    AnimatedBuilder(
                      animation: _floatAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _floatAnimation.value),
                          child: child,
                        );
                      },
                      child: FadeTransition(
                        opacity: _logoFade,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.emerald500.withValues(alpha: 0.3),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/thartheeb-logo.png',
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Title — Tartheeb
                    FadeTransition(
                      opacity: _titleFade,
                      child: Text(
                        'Tartheeb',
                        style: GoogleFonts.philosopher(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.brandTitle,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Subtitle
                    FadeTransition(
                      opacity: _subtitleFade,
                      child: Text(
                        'Madrasa Management App',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: AppTheme.brandTitle.withValues(alpha: 0.7),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Description
                    FadeTransition(
                      opacity: _subtitleFade,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 48),
                        child: Text(
                          'A complete digital platform to simplify\ndaily administration of your Madrasa',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppTheme.brandTitle.withValues(alpha: 0.5),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Progress bar at bottom
              Positioned(
                bottom: 60,
                left: 48,
                right: 48,
                child: FadeTransition(
                  opacity: _subtitleFade,
                  child: Column(
                    children: [
                      AnimatedBuilder(
                        animation: _progressAnimation,
                        builder: (context, _) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _progressAnimation.value,
                              backgroundColor:
                                  AppTheme.emerald500.withValues(alpha: 0.15),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppTheme.emerald500,
                              ),
                              minHeight: 4,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Loading...',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.brandTitle.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Footer
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: _subtitleFade,
                  child: Text(
                    '© 2026 Tartheeb',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppTheme.brandTitle.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Simple geometric pattern painter for Islamic decoration
class _GeometricPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.emerald700
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const spacing = 60.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        // Draw star pattern
        canvas.drawCircle(Offset(x, y), 15, paint);
        canvas.drawLine(
          Offset(x - 15, y),
          Offset(x + 15, y),
          paint,
        );
        canvas.drawLine(
          Offset(x, y - 15),
          Offset(x, y + 15),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
