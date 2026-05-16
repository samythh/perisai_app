import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'features/auth/splash_screen.dart';
import 'features/auth/role_select_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/detail/detection_detail_screen.dart';
import 'features/pairing/add_child_screen.dart';
import 'features/pairing/scan_qr_screen.dart';
import 'features/pairing/active_screen.dart';
import 'features/education/education_screen.dart';
import 'features/settings/settings_screen.dart';
import 'services/channel_service.dart';
import 'features/test/test_event_page.dart';

final appRouter = GoRouter(
  navigatorKey: ChannelService.navigatorKey,
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/role-select',
      builder: (context, state) => const RoleSelectScreen(),
    ),

    // Orang Tua
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/add-child',
      builder: (context, state) => const AddChildScreen(),
    ),
    GoRoute(
      path: '/detail/:id',
      builder: (context, state) => DetectionDetailScreen(
        detectionId: state.pathParameters['id'] ?? '',
      ),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),

    // Anak
    GoRoute(
      path: '/scan-qr',
      builder: (context, state) => const ScanQrScreen(),
    ),
    GoRoute(
      path: '/education',
      builder: (context, state) {
        // Terima extra dari Event Channel
        final extra = state.extra as Map<String, dynamic>?;
        return EducationScreen(
          keywords: List<String>.from(extra?['keywords'] ?? []),
          triggeredBy: extra?['triggeredBy']?.toString() ?? '',
          confidence: (extra?['confidence'] as num?)?.toDouble() ?? 0.0,
        );
      },
    ),
    GoRoute(
      path: '/active',
      builder: (context, state) => const ActiveScreen(),
    ),
    GoRoute(
      path: '/test',
      builder: (context, state) => const TestEventPage(),
    ),
  ],
);

// Placeholder sementara biar app bisa jalan
// Nanti diganti satu per satu dengan screen asli
class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Tambahkan ini — tombol back otomatis muncul
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(), // ← ini yang bikin bisa back
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🛡️', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Screen ini belum dibuat',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
