import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';

class ChannelService {
  static const EventChannel _channel = EventChannel(
    'com.perisai.app/detection_stream',
  );

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static bool _isListening = false;

  // Mulai listen event dari Daffa
  static void startListening() {
    if (_isListening) return;
    _isListening = true;

    _channel.receiveBroadcastStream().listen(
      (dynamic event) {
        try {
          // Parse JSON dari Daffa
          final Map<String, dynamic> data = event is String
              ? jsonDecode(event)
              : Map<String, dynamic>.from(event);

          final String eventType = data['event_type'] ?? '';

          switch (eventType) {
            case 'gambling_detected':
              _handleGamblingDetected(data);
              break;
            case 'service_started':
              _handleServiceStarted(data);
              break;
            case 'service_stopped':
              _handleServiceStopped(data);
              break;
            default:
              debugPrint('PERISAI: Unknown event type → $eventType');
          }
        } catch (e) {
          debugPrint('PERISAI: Error parse event → $e');
        }
      },
      onError: (dynamic error) {
        debugPrint('PERISAI: Channel error → $error');
        _isListening = false;
      },
    );
  }

  // ─── Handler gambling_detected ──────────────────────
  static void _handleGamblingDetected(Map<String, dynamic> data) {
    final keywords = List<String>.from(data['keywords'] ?? []);
    final triggeredBy = data['triggered_by']?.toString() ?? '';
    final confidence = (data['confidence'] as num?)?.toDouble() ?? 0.0;

    debugPrint('PERISAI: Judol terdeteksi! confidence=$confidence');

    // Navigasi ke Layar Edukasi
    final context = navigatorKey.currentContext;
    if (context != null) {
      GoRouter.of(context).push(
        '/education',
        extra: {
          'keywords': keywords,
          'triggeredBy': triggeredBy,
          'confidence': confidence,
        },
      );
    }
  }

  // ─── Handler service_started ────────────────────────
  static void _handleServiceStarted(Map<String, dynamic> data) {
    debugPrint('PERISAI: Service mulai jalan ✅');

    final context = navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.shield_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('PERISAI aktif melindungi kamu 🛡️'),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  // ─── Handler service_stopped ────────────────────────
  static void _handleServiceStopped(Map<String, dynamic> data) {
    debugPrint('PERISAI: Service berhenti ⚠️');

    final context = navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Expanded(
                child:
                    Text('PERISAI tidak aktif ⚠️ HP anak tidak terlindungi!'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
}
