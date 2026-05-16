import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_strings.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Animasi logo
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();

    // Cek session & role setelah 2 detik
    Future.delayed(const Duration(seconds: 2), _checkAndNavigate);
  }

  Future<void> _checkAndNavigate() async {
    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('role'); // 'parent' atau 'child'
    final childId = prefs.getString('child_id');

    if (!mounted) return;

    if (session != null && role == 'parent') {
      // Parent sudah login → dashboard
      context.go('/dashboard');
    } else if (role == 'child' && childId != null) {
      // Anak sudah pernah scan QR → langsung scan-qr
      context.go('/scan-qr');
    } else {
      // Belum ada session / belum paired → pilih role dulu
      context.go('/role-select');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo shield
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    size: 72,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),

                // Nama app
                const Text(
                  AppStrings.appName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 8),

                // Tagline
                Text(
                  AppStrings.appTagline,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),

                const SizedBox(height: 48),

                // Loading indicator
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white.withOpacity(0.7),
                    strokeWidth: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
