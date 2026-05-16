import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingData> _pages = [
    const _OnboardingData(
      image: 'assets/images/Onboarding1.png',
      title: 'Senang bertemu\ndenganmu!\nAku PERISAI',
      desc: 'Aku temen kecil di HP kamu. Tugasku bantu '
          'kamu tetap aman pas main HP, tanpa ganggu '
          'keseruan kamu.',
    ),
    const _OnboardingData(
      image: 'assets/images/Onboarding2.png',
      title: 'Dunia kamu seru, aku\nbantu jagain biar\ntetap begitu.',
      desc: 'Lakuin aja semuanya kayak biasa. Aku ada '
          'di belakang layar, kamu nggak bakal kerasa.',
    ),
    const _OnboardingData(
      image: 'assets/images/Onboarding3.png',
      title: 'Tapi kadang, ada yang\nnyoba masuk tanpa\nkamu sadari.',
      desc: 'Sebuah jebakan yang bikin rugi. Aku di sini '
          'buat bantu kamu kenalin dan hindarin, '
          'sebelum kamu klik.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _skip() => context.go('/scan-qr');
  void _start() => context.go('/scan-qr');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) =>
                    _OnboardingPage(data: _pages[index]),
              ),
            ),

            // Dots indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? AppColors.primary
                        : AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Tombol bawah — smooth transition
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.1, 0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOut,
                      )),
                      child: child,
                    ),
                  );
                },
                child: _currentPage == _pages.length - 1

                    // Halaman terakhir — tombol MULAI
                    ? SizedBox(
                        key: const ValueKey('mulai'),
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _start,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'MULAI',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      )

                    // Halaman 1 & 2 — Lewati & Next
                    : SizedBox(
                        key: ValueKey('nav-$_currentPage'),
                        height: 52,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Tombol Lewati
                            TextButton(
                              onPressed: _skip,
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                              ),
                              child: const Text(
                                'Lewati',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),

                            // Tombol Next bulat
                            SizedBox(
                              width: 52,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _nextPage,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  shape: const CircleBorder(),
                                  padding: EdgeInsets.zero,
                                  elevation: 0,
                                ),
                                child: const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Data Model ───────────────────────────────────────
class _OnboardingData {
  final String image;
  final String title;
  final String desc;

  const _OnboardingData({
    required this.image,
    required this.title,
    required this.desc,
  });
}

// ─── Page Widget ──────────────────────────────────────
class _OnboardingPage extends StatelessWidget {
  final _OnboardingData data;
  const _OnboardingPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Gambar lebih kecil
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Image.asset(
                data.image,
                fit: BoxFit.contain,
                height: 200,
              ),
            ),
          ),

          // Teks
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  data.desc,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
