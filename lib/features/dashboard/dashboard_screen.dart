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

  late final RealtimeChannel _realtimeChannel;
  final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initLocalNotif();
    _loadData().then((_) => _subscribeRealtime());
  }

  @override
  void dispose() {
    Supabase.instance.client.removeChannel(_realtimeChannel);
    super.dispose();
  }

  Future<void> _initLocalNotif() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _localNotif.initialize(settings);
  }

  void _subscribeRealtime() {
    _realtimeChannel = Supabase.instance.client
        .channel('public:detections')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'detections',
          callback: (payload) {
            final newData = payload.newRecord;
            if (newData.isEmpty) return;
            final childIds = _children.map((c) => c.id).toList();
            if (childIds.contains(newData['child_id'])) {
              _showLocalNotif(newData);
              _loadData();
            }
          },
        )
        .subscribe();
  }

  Future<void> _showLocalNotif(Map<String, dynamic> data) async {
    try {
      final raw = data['confidence'];
      final confidence = raw is String
          ? double.tryParse(raw) ?? 0.0
          : (raw as num?)?.toDouble() ?? 0.0;
      final pct = (confidence * 100).toStringAsFixed(0);
      final by = data['triggered_by'] ?? '';
      final label = switch (by) {
        'ocr' => 'Baca Teks',
        'mobilenet' => 'Lihat Gambar',
        'trustpositif' => 'Cek URL',
        'combined' => 'Kombinasi',
        _ => by,
      };
      await _localNotif.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        '⚠️ Konten judol terdeteksi!',
        'AI $pct% yakin — terdeteksi via $label',
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
      debugPrint('PERISAI: notif error → $e');
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      setState(() {
        _userName = user.userMetadata?['full_name'] ?? 'Orang Tua';
      });

      final childrenRes = await Supabase.instance.client
          .from('children')
          .select()
          .eq('parent_id', user.id);

      _children = (childrenRes as List).map((j) => Child.fromJson(j)).toList();

      if (_children.isNotEmpty) {
        final ids = _children.map((c) => c.id).toList();
        final detRes = await Supabase.instance.client
            .from('detections')
            .select()
            .inFilter('child_id', ids)
            .order('created_at', ascending: false);

        _detections =
            (detRes as List).map((j) => Detection.fromJson(j)).toList();
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  int get _todayCount {
    final now = DateTime.now();
    return _detections
        .where((d) =>
            d.createdAt.year == now.year &&
            d.createdAt.month == now.month &&
            d.createdAt.day == now.day)
        .length;
  }

  int get _securityScore {
    if (_detections.isEmpty) return 100;
    final score = 100 - (_detections.length * 5);
    return score.clamp(0, 100);
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    context.go('/role-select');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FA),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Dashboard',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined,
                color: AppColors.textPrimary),
            onPressed: () => context.push('/settings'),
          ),
          IconButton(
            icon:
                const Icon(Icons.logout_rounded, color: AppColors.textPrimary),
            onPressed: _showLogoutDialog,
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
                    // ─── 3 Summary Cards ───────────────
                    _SummaryCards(
                      totalDetected: _detections.length,
                      todayDetected: _todayCount,
                      securityScore: _securityScore,
                    ),
                    const SizedBox(height: 24),

                    // ─── List Anak Horizontal ───────────
                    if (_children.isNotEmpty) ...[
                      _ChildrenRow(children: _children),
                      const SizedBox(height: 24),
                    ],

                    // ─── Riwayat Aktivitas ──────────────
                    const Text(
                      'Riwayat Aktivitas',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _detections.isEmpty
                        ? _EmptyState()
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _detections.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final d = _detections[index];
                              final child = _children.firstWhere(
                                (c) => c.id == d.childId,
                                orElse: () => Child(
                                  id: '',
                                  parentId: '',
                                  childName: 'Anak',
                                  age: 0,
                                  createdAt: DateTime.now(),
                                ),
                              );
                              return _ActivityCard(
                                detection: d,
                                child: child,
                                onTap: () => context.push('/detail/${d.id}'),
                              );
                            },
                          ),
                    const SizedBox(height: 80),
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
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Mau keluar nih? 👋',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        content: const Text(
          'Kamu bakal keluar dari akun PERISAI.\nData anak tetap aman kok!',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
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

// ─── 3 Summary Cards ──────────────────────────────────
class _SummaryCards extends StatelessWidget {
  final int totalDetected;
  final int todayDetected;
  final int securityScore;

  const _SummaryCards({
    required this.totalDetected,
    required this.todayDetected,
    required this.securityScore,
  });

  Color get _scoreColor {
    if (securityScore >= 80) return AppColors.success;
    if (securityScore >= 50) return AppColors.warning;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Total Terdeteksi
        Expanded(
          child: _SummaryCard(
            icon: Icons.warning_rounded,
            iconColor: AppColors.danger,
            label: 'Total\nTerdeteksi',
            value: '$totalDetected',
            valueColor: AppColors.danger,
          ),
        ),
        const SizedBox(width: 12),

        // Screen Time (hari ini)
        Expanded(
          child: _SummaryCard(
            icon: Icons.today_rounded,
            iconColor: AppColors.warning,
            label: 'Deteksi\nHari Ini',
            value: '$todayDetected',
            valueColor: AppColors.warning,
          ),
        ),
        const SizedBox(width: 12),

        // Skor Keamanan
        Expanded(
          child: _SummaryCard(
            icon: Icons.shield_rounded,
            iconColor: _scoreColor,
            label: 'Skor\nKeamanan',
            value: '$securityScore',
            valueColor: _scoreColor,
            suffix: '%',
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color valueColor;
  final String suffix;

  const _SummaryCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.valueColor,
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: valueColor,
                  ),
                ),
                if (suffix.isNotEmpty)
                  TextSpan(
                    text: suffix,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: valueColor,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Children Row (horizontal scroll) ────────────────
class _ChildrenRow extends StatelessWidget {
  final List<Child> children;
  const _ChildrenRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Anak Terhubung',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: children.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final child = children[index];
              return _ChildAvatar(child: child);
            },
          ),
        ),
      ],
    );
  }
}

class _ChildAvatar extends StatelessWidget {
  final Child child;
  const _ChildAvatar({required this.child});

  // Nama pertama saja
  String get _firstName => child.childName.split(' ').first;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          children: [
            // Avatar
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  _firstName[0].toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),

            // Dot hijau online di kiri atas
            Positioned(
              top: 2,
              left: 2,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Nama pertama
        Text(
          _firstName,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ─── Activity Card ────────────────────────────────────
class _ActivityCard extends StatelessWidget {
  final Detection detection;
  final Child child;
  final VoidCallback onTap;

  const _ActivityCard({
    required this.detection,
    required this.child,
    required this.onTap,
  });

  String get _firstName => child.childName.split(' ').first;

  String get _title {
    switch (detection.triggeredBy) {
      case 'ocr':
        return 'Teks Judol Terdeteksi';
      case 'mobilenet':
        return 'Visual Judol Terdeteksi';
      case 'trustpositif':
        return 'URL Judol Terdeteksi';
      case 'combined':
        return 'Judol Terdeteksi';
      default:
        return 'Konten Mencurigakan';
    }
  }

  String get _desc {
    if (detection.keywords.isNotEmpty) {
      return 'Kata mencurigakan: ${detection.keywords.join(', ')}';
    }
    return 'Terdeteksi via ${detection.triggeredByLabel} '
        '— ${detection.confidencePercent} yakin';
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar anak
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      child.childName.isNotEmpty
                          ? child.childName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                // Danger triangle di kanan atas avatar
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_rounded,
                      color: Colors.white,
                      size: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),

            // Konten
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + waktu
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          _title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _timeAgo(detection.createdAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Nama anak
                  Text(
                    _firstName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Deskripsi
                  Text(
                    _desc,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Arrow
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────
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
