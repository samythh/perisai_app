import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_strings.dart';

class EducationScreen extends StatefulWidget {
  // Keywords dari deteksi, dikirim dari Event Channel Daffa
  final List<String> keywords;
  final String triggeredBy;
  final double confidence;

  const EducationScreen({
    super.key,
    this.keywords = const [],
    this.triggeredBy = '',
    this.confidence = 0.0,
  });

  @override
  State<EducationScreen> createState() => _EducationScreenState();
}

class _EducationScreenState extends State<EducationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Countdown sebelum tombol bisa ditap
  int _countdown = 5;
  bool _canDismiss = false;

  @override
  void initState() {
    super.initState();

    // Animasi masuk
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();

    // Mulai countdown
    _startCountdown();

    // Paksa layar tetap menyala
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _startCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        }
        if (_countdown == 0) {
          _canDismiss = true;
        }
      });
      return _countdown > 0;
    });
  }

  void _dismiss() {
    if (!_canDismiss) return;
    HapticFeedback.lightImpact();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    context.go('/active');
  }

  @override
  void dispose() {
    _controller.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),

      // Tidak bisa di-back sama sekali
      body: PopScope(
        canPop: false,
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    const Spacer(),

                    // Ilustrasi emoji
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.8, end: 1.0),
                      duration: const Duration(seconds: 2),
                      curve: Curves.easeInOut,
                      builder: (_, val, child) =>
                          Transform.scale(scale: val, child: child),
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text(
                            '🫂',
                            style: TextStyle(fontSize: 60),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Judul
                    const Text(
                      AppStrings.educationTitle,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    // Pesan utama
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: const Text(
                        AppStrings.educationBody,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          height: 1.7,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Keywords yang terdeteksi
                    if (widget.keywords.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.danger.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Kata yang bikin PERISAI curiga:',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: widget.keywords.map((keyword) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.danger.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    keyword,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),

                    const Spacer(),

                    // Tombol dengan countdown
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _canDismiss ? _dismiss : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _canDismiss
                              ? AppColors.success
                              : Colors.white.withValues(alpha: 0.2),
                          disabledBackgroundColor:
                              Colors.white.withValues(alpha: 0.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          _canDismiss
                              ? AppStrings.educationButton
                              : 'Baca dulu ya... ($_countdown)',
                          style: TextStyle(
                            color: _canDismiss ? Colors.white : Colors.white60,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Teks kecil di bawah
                    Text(
                      'Pesan ini dikirim oleh orang tua kamu ❤️',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
