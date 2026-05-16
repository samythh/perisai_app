import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChannelService {
  static const EventChannel _channel = EventChannel(
    'com.perisai.app/detection_stream',
  );

  static const MethodChannel _methodChannel = MethodChannel(
    'com.perisai.app/service_control',
  );

  static Future<void> sendTestEvent() async {
    try {
      await _methodChannel.invokeMethod('sendTestEvent');
    } catch (e) {
      debugPrint('PERISAI: Error sendTestEvent → $e');
    }
  }

  static Future<void> startService(String childId) async {
    try {
      await _methodChannel.invokeMethod('startService', {
        'child_id': childId,
      });
    } catch (e) {
      debugPrint('PERISAI: Error startService → $e');
    }
  }

  static Future<void> stopService() async {
    try {
      await _methodChannel.invokeMethod('stopService');
    } catch (e) {
      debugPrint('PERISAI: Error stopService → $e');
    }
  }

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static bool _isListening = false;

  /// Timer heartbeat — update last_seen tiap 30 detik selama service aktif
  static Timer? _heartbeatTimer;

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
            case 'permission_denied':
              _handlePermissionDenied();
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

  // ─── Update status koneksi ke Supabase ──────────────
  static Future<void> _updateConnectionStatus(String status) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final childId = prefs.getString('child_id');
      if (childId == null || childId.isEmpty) {
        debugPrint('PERISAI: Tidak bisa update status — child_id kosong');
        return;
      }

      await Supabase.instance.client.rpc('update_child_connection', params: {
        'p_child_id': childId,
        'p_status': status,
        'p_last_seen': DateTime.now().toUtc().toIso8601String(),
      });

      debugPrint('PERISAI: Status koneksi diupdate → $status');
    } catch (e) {
      debugPrint('PERISAI: Gagal update status koneksi → $e');
    }
  }

  // ─── Heartbeat — update last_seen berkala ────────────
  static void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _sendHeartbeat(),
    );
    // Kirim langsung sekali
    _sendHeartbeat();
  }

  static void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  static Future<void> _sendHeartbeat() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final childId = prefs.getString('child_id');
      if (childId == null || childId.isEmpty) return;

      await Supabase.instance.client.rpc('update_child_connection', params: {
        'p_child_id': childId,
        'p_status': 'online',
        'p_last_seen': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      // Gagal heartbeat = internet mungkin mati — diam saja
      debugPrint('PERISAI: Heartbeat gagal → $e');
    }
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

    // Update status ke Supabase → online
    _updateConnectionStatus('online');

    // Mulai heartbeat
    _startHeartbeat();

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
  static void _handleServiceStopped(Map<String, dynamic> data) async {
    debugPrint('PERISAI: Service berhenti ⚠️');

    // Cek apakah HP ini mode anak — hanya tampilkan warning di mode anak
    final prefs = await SharedPreferences.getInstance();
    final childId = prefs.getString('child_id');

    // Update status ke Supabase → offline_manual
    _updateConnectionStatus('offline_manual');

    // Stop heartbeat
    _stopHeartbeat();

    // Hanya tampilkan warning kalau ini HP anak
    if (childId == null || childId.isEmpty) return;

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

  // ─── Handler permission_denied ────────────────────────
  static void _handlePermissionDenied() async {
    debugPrint('PERISAI: Izin ditolak — revert status ke offline_manual');

    // Revert status via RPC
    _updateConnectionStatus('offline_manual');
    _stopHeartbeat();

    // Hapus child_id dari local storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('child_id');
    await prefs.remove('role');

    final context = navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.block_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text('Izin ditolak — PERISAI tidak bisa memantau'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
}
