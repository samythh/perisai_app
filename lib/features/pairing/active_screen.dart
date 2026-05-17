import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../services/channel_service.dart';

class ActiveScreen extends StatefulWidget {
  const ActiveScreen({super.key});

  @override
  State<ActiveScreen> createState() => _ActiveScreenState();
}

class _ActiveScreenState extends State<ActiveScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  String _childId = '';
  String _parentName = '';

  @override
  void initState() {
    super.initState();
    _loadData();

    // Animasi maskot naik turun
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final childId = prefs.getString('child_id') ?? '';

    if (childId.isEmpty) return;

    // Ambil data anak untuk dapatkan parent_id
    String parentName = '';
    try {
      final childData = await Supabase.instance.client
          .from('children')
          .select('parent_id')
          .eq('id', childId)
          .single();

      final parentId = childData['parent_id'] as String;

      // Ambil nama parent
      final parentData = await Supabase.instance.client
          .from('parents')
          .select('name')
          .eq('id', parentId)
          .single();

      parentName = parentData['name'] as String? ?? '';
    } catch (e) {
      debugPrint('PERISAI: Gagal ambil data parent → $e');
    }

    if (!mounted) return;
    setState(() {
      _childId = childId;
      _parentName = parentName;
    });
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

      // Tidak bisa back dengan tombol HP
      body: PopScope(
        canPop: false,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                // Maskot animasi
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Image.asset(
                    'assets/images/maskot.png',
                    width: 160,
                    height: 160,
                  ),
                ),
                const SizedBox(height: 28),

                // Status teks
                const Text(
                  AppStrings.serviceActive,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),

                Text(
                  _parentName.isNotEmpty
                      ? 'Terhubung dengan $_parentName.\nPERISAI berjalan di latar belakang.'
                      : 'PERISAI berjalan di latar belakang.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),

                // Info box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Column(
                    children: [
                      _InfoItem(
                        icon: Icons.visibility_outlined,
                        text: 'Layar dipindai secara berkala',
                      ),
                      SizedBox(height: 16),
                      _InfoItem(
                        icon: Icons.notifications_outlined,
                        text:
                            'Orang tua langsung diberitahu kalau ada aktivitas mencurigakan',
                      ),
                      SizedBox(height: 16),
                      _InfoItem(
                        icon: Icons.lock_outline_rounded,
                        text: 'Data kamu aman dan hanya bisa dilihat orang tua',
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // ID terhubung
                if (_childId.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.link_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _parentName.isNotEmpty
                              ? 'Terhubung dengan $_parentName'
                              : 'Terhubung',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // Tombol test — HAPUS sebelum presentasi
                TextButton.icon(
                  onPressed: () async {
                    await ChannelService.sendTestEvent();
                  },
                  icon: const Icon(
                    Icons.bug_report_outlined,
                    color: Colors.white38,
                    size: 16,
                  ),
                  label: const Text(
                    'Test Layar Edukasi',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Info Item ────────────────────────────────────────
class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
