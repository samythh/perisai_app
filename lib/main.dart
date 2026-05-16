import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'router.dart';
import 'services/channel_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Supabase
  await Supabase.initialize(
    url:    SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  ChannelService.startListening();

  runApp(
    // Riverpod wrapper
    const ProviderScope(
      child: PerisaiApp(),
    ),
  );
}

class PerisaiApp extends StatelessWidget {
  const PerisaiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PERISAI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
    );
  }
}