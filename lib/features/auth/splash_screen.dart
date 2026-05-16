import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _bgController;
  late AnimationController _contentController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _bgAnimation;

  @override
  void initState() {
    super.initState();

    // Animasi background geser — loop terus
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _bgAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.3, -0.3),
    ).animate(
      CurvedAnimation(parent: _bgController, curve: Curves.linear),
    );

    // Animasi konten fade + scale
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: Curves.elasticOut,
      ),
    );
    _contentController.forward();

    Future.delayed(const Duration(seconds: 3), _checkAndNavigate);
  }

  Future<void> _checkAndNavigate() async {
    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('role');
    final childId = prefs.getString('child_id');

    if (session != null && role == 'parent') {
      context.go('/dashboard');
    } else if (role == 'child' && childId != null) {
      context.go('/active');
    } else {
      context.go('/role-select');
    }
  }

  @override
  void dispose() {
    _bgController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background pattern bergeser
          AnimatedBuilder(
            animation: _bgAnimation,
            builder: (_, __) {
              return SlideTransition(
                position: _bgAnimation,
                child: Transform.scale(
                  // Scale lebih besar biar tidak keliatan ujungnya
                  scale: 1.5,
                  child: Image.asset(
                    'assets/images/splash.png',
                    fit: BoxFit.cover,
                    repeat: ImageRepeat.repeat,
                  ),
                ),
              );
            },
          ),

          // Overlay warna primary supaya tetap branded
          Container(
            color: AppColors.primary.withOpacity(0.6),
          ),

          // Konten tengah
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Maskot
                    Image.asset(
                      'assets/images/maskot.png',
                      width: 180,
                      height: 180,
                    ),
                    const SizedBox(height: 24),

                    // Teks PERISAI
                    Image.asset(
                      'assets/images/text_maskot.png',
                      width: 300,
                    ),
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
