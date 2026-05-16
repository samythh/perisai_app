import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../models/detection.dart';
import '../../models/child.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Detection> _detections = [];
  List<Child> _children = [];
  bool _isLoading = true;
  String _userName = '';

  // Variabel untuk menyimpan soket koneksi Realtime
  late final RealtimeChannel _realtimeChannel;

  final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initLocalNotif();

    // PERBAIKAN ARSITEKTUR 1: Sinkronisasi Balapan Waktu (Race Condition)
    // Tunggu _loadData() selesai mengunduh data anak, BARU nyalakan soket Realtime
    _loadData().then((_) {
      _subscribeRealtime();
    });
  }

  @override
  void dispose() {
    // PENGAMANAN MEMORI: Matikan soket saat halaman ditutup agar RAM HP tidak bocor
    Supabase.instance.client.removeChannel(_realtimeChannel);
    super.dispose();
  }

  Future<void> _initLocalNotif() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _localNotif.initialize(settings);
  }

  // PERBAIKAN ARSITEKTUR 2: Menggunakan PostgresChanges bukan Stream global
  void _subscribeRealtime() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    _realtimeChannel = Supabase.instance.client
        .channel('public:detections')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'detections',
          callback: (payload) {
            final newData = payload.newRecord;

            if (newData.isEmpty) return;

            // 1. Ambil kumpulan ID Anak yang sah milik orang tua ini
            final childIds = _children.map((c) => c.id).toList();
            if (childIds.isEmpty) return;

            // 2. Jika baris deteksi yang baru masuk adalah milik anak kita
            if (childIds.contains(newData['child_id'])) {
              // Tampilkan Notifikasi Darurat
              _showLocalNotif(newData);

              // Muat ulang daftar list di UI agar Realtime
              _loadData();
            }
          },
        )
        .subscribe();
  }

  Future<void> _showLocalNotif(Map<String, dynamic> data) async {
    try {
      // Handle confidence yang bisa String atau double
      final rawConfidence = data['confidence'];
      final confidence = rawConfidence is String
          ? double.tryParse(rawConfidence) ?? 0.0
          : (rawConfidence as num?)?.toDouble() ?? 0.0;

      final confidencePercent = (confidence * 100).toStringAsFixed(0);
      final triggeredBy = data['triggered_by'] ?? '';

      // Label triggered_by yang friendly
      final triggeredByLabel = switch (triggeredBy) {
        'ocr' => 'Baca Teks',
        'mobilenet' => 'Lihat Gambar',
        'trustpositif' => 'Cek URL',
        'combined' => 'Kombinasi',
        _ => triggeredBy,
      };

      await _localNotif.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000, // ID unik per notif
        '⚠️ Konten judol terdeteksi!',
        'AI $confidencePercent% yakin — terdeteksi via $triggeredByLabel',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'perisai_channel',
            'PERISAI Deteksi',
            channelDescription: 'Notifikasi deteksi judol dari PERISAI',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
          ),
        ),
      );
    } catch (e) {
      debugPrint('PERISAI: Error show notif → $e');
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Ambil nama user
      setState(() {
        _userName = user.userMetadata?['full_name'] ?? 'Orang Tua';
      });

      // Ambil list anak
      final childrenRes = await Supabase.instance.client
          .from('children')
          .select()
          .eq('parent_id', user.id);

      _children =
          (childrenRes as List).map((json) => Child.fromJson(json)).toList();

      // Ambil deteksi dari semua anak
      if (_children.isNotEmpty) {
        final childIds = _children.map((c) => c.id).toList();

        final detectionsRes = await Supabase.instance.client
            .from('detections')
            .select()
            .inFilter('child_id', childIds)
            .order('created_at', ascending: false);

        _detections = (detectionsRes as List)
            .map((json) => Detection.fromJson(json))
            .toList();
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // Hitung deteksi hari ini
  int get _todayCount {
    final now = DateTime.now();
    return _detections
        .where((d) =>
            d.createdAt.year == now.year &&
            d.createdAt.month == now.month &&
            d.createdAt.day == now.day)
        .length;
  }

  // Hitung deteksi minggu ini
  int get _weekCount {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    return _detections.where((d) => d.createdAt.isAfter(weekAgo)).length;
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    context.go('/role-select');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hei, $_userName! 👋'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => _showLogoutDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status card
                    _StatusCard(isActive: true),
                    const SizedBox(height: 16),

                    // Stats row
                    _StatsRow(
                      todayCount: _todayCount,
                      weekCount: _weekCount,
                      safeCount: _children.length,
                    ),
                    const SizedBox(height: 24),

                    // Header list
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Riwayat Deteksi',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${_detections.length} total',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // List deteksi atau empty state
                    _detections.isEmpty
                        ? _EmptyState()
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _detections.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final detection = _detections[index];
                              return _DetectionCard(
                                detection: detection,
                                onTap: () =>
                                    context.push('/detail/${detection.id}'),
                              );
                            },
                          ),
                  ],
                ),
              ),
            ),

      // FAB tambah anak
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/add-child'),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Tambah Anak',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Mau keluar nih? 👋',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        content: const Text(
          'Kamu bakal keluar dari akun PERISAI. '
          'Data anak tetap aman kok!',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          // Tombol batal
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Batal',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),

          // Tombol logout
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _logout();
            },
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }
}

// ─── Widget Status Card ───────────────────────────────
class _StatusCard extends StatelessWidget {
  final bool isActive;
  const _StatusCard({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isActive
              ? [AppColors.primary, AppColors.primaryLight]
              : [AppColors.danger, AppColors.danger],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isActive ? Icons.shield_rounded : Icons.shield_outlined,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isActive ? AppStrings.active : AppStrings.inactive,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isActive
                      ? 'PERISAI lagi jaga si kecil 🛡️'
                      : 'HP anak tidak terlindungi ⚠️',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
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

// ─── Widget Stats Row ─────────────────────────────────
class _StatsRow extends StatelessWidget {
  final int todayCount;
  final int weekCount;
  final int safeCount;

  const _StatsRow({
    required this.todayCount,
    required this.weekCount,
    required this.safeCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: AppStrings.todayDetection,
            value: '$todayCount',
            color: AppColors.danger,
            icon: Icons.today_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: AppStrings.weekDetection,
            value: '$weekCount',
            color: AppColors.warning,
            icon: Icons.calendar_month_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Anak Terhubung',
            value: '$safeCount',
            color: AppColors.success,
            icon: Icons.people_outline_rounded,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Widget Detection Card ────────────────────────────
class _DetectionCard extends StatelessWidget {
  final Detection detection;
  final VoidCallback onTap;

  const _DetectionCard({
    required this.detection,
    required this.onTap,
  });

  Color get _badgeColor {
    switch (detection.triggeredBy) {
      case 'ocr':
        return AppColors.ocr;
      case 'mobilenet':
        return AppColors.mobilenet;
      case 'trustpositif':
        return AppColors.trustpositif;
      case 'combined':
        return AppColors.combined;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon bahaya
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.warning_rounded,
                color: AppColors.danger,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),

            // Info deteksi
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge triggered_by
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _badgeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      detection.triggeredByLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: _badgeColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Keywords
                  if (detection.keywords.isNotEmpty)
                    Text(
                      detection.keywords.join(', '),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                  const SizedBox(height: 4),

                  // Waktu
                  Text(
                    _timeAgo(detection.createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Confidence
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  detection.confidencePercent,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.danger,
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }
}

// ─── Widget Empty State ───────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            const Text('🛡️', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text(
              AppStrings.noDetection,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              AppStrings.noDetectionDesc,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
