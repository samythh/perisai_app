import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../services/channel_service.dart';

class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isProcessing = false;
  bool _hasScanned = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _onQrDetected(String childId) async {
    // Cegah scan berulang
    if (_isProcessing || _hasScanned) return;
    setState(() {
      _isProcessing = true;
      _hasScanned = true;
    });

    HapticFeedback.mediumImpact();

    // Validasi UUID format
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );

    if (!uuidRegex.hasMatch(childId)) {
      setState(() {
        _isProcessing = false;
        _hasScanned = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'QR Code-nya bukan dari PERISAI nih 🤔 Coba scan ulang ya',
          ),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    // Simpan child_id & role ke local storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('child_id', childId);
    await prefs.setString('role', 'child');

    if (!mounted) return;

    // Tampilkan panduan izin sebelum minta permission
    _showPermissionGuide(childId);
  }

  void _showPermissionGuide(String childId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.92,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Icon sukses scan
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                      size: 44,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Scan Berhasil! 🎉',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Satu langkah lagi untuk mengaktifkan\nperlindungan PERISAI',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),

                  // ── Panduan langkah-langkah ──
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.info_outline_rounded,
                                  color: AppColors.primary, size: 18),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Panduan Izin Perekaman Layar',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Step 1
                        _buildGuideStep(
                          number: '1',
                          title: 'Pop-up izin akan muncul',
                          desc: 'Setelah kamu tekan tombol di bawah, Android akan menampilkan pop-up izin perekaman layar.',
                          icon: Icons.notifications_active_rounded,
                        ),
                        const SizedBox(height: 14),

                        // Step 2
                        _buildGuideStep(
                          number: '2',
                          title: 'Pilih "Entire Screen"',
                          desc: 'Pada pop-up tersebut, pastikan kamu memilih opsi "Entire Screen" atau "Seluruh Layar" agar PERISAI bisa memantau secara menyeluruh.',
                          icon: Icons.smartphone_rounded,
                        ),
                        const SizedBox(height: 14),

                        // Step 3
                        _buildGuideStep(
                          number: '3',
                          title: 'Tekan "Start" / "Mulai"',
                          desc: 'Setelah memilih Entire Screen, tekan tombol Start atau Mulai untuk mengaktifkan perlindungan.',
                          icon: Icons.play_circle_outline_rounded,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Warning box
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Color(0xFFF59E0B), size: 22),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Jika izin ditolak, PERISAI tidak bisa memantau dan HP anak tidak akan terlindungi.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF92400E),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Tombol "Saya Paham"
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        Navigator.pop(sheetCtx);
                        await _startServiceAndCheckPermission(childId);
                      },
                      child: const Text(
                        'Saya Paham, Lanjutkan 🛡️',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGuideStep({
    required String number,
    required String title,
    required String desc,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Mulai service → tunggu hasil: service_started atau permission_denied
  Future<void> _startServiceAndCheckPermission(String childId) async {
    // Update status ke online di Supabase via RPC
    try {
      await Supabase.instance.client.rpc('update_child_connection', params: {
        'p_child_id': childId,
        'p_status': 'online',
        'p_last_seen': DateTime.now().toUtc().toIso8601String(),
      });
      debugPrint('PERISAI: Status berhasil diupdate → online ✅');
    } catch (e) {
      debugPrint('PERISAI: Gagal update status connect → $e');
    }

    // Mulai service — permission popup akan muncul
    await ChannelService.startService(childId);

    if (!mounted) return;

    // Navigasi ke layar aktif
    context.go('/active');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Scanner kamera
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              final barcode = capture.barcodes.firstOrNull;
              if (barcode?.rawValue != null) {
                _onQrDetected(barcode!.rawValue!);
              }
            },
          ),

          // Overlay UI di atas kamera
          SafeArea(
            child: Column(
              children: [
                // AppBar manual
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                        ),
                        onPressed: () => context.pop(),
                      ),
                      const Text(
                        AppStrings.scanQR,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),

                      // Toggle flash
                      IconButton(
                        icon: const Icon(
                          Icons.flash_on_rounded,
                          color: Colors.white,
                        ),
                        onPressed: () => _scannerController.toggleTorch(),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Frame scanner
                Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.primary,
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Stack(
                    children: [
                      // Sudut kiri atas
                      _Corner(top: 0, left: 0),
                      // Sudut kanan atas
                      _Corner(top: 0, right: 0),
                      // Sudut kiri bawah
                      _Corner(bottom: 0, left: 0),
                      // Sudut kanan bawah
                      _Corner(bottom: 0, right: 0),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Instruksi
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    AppStrings.scanQRDesc,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const Spacer(),

                // Loading indicator saat processing
                if (_isProcessing)
                  Container(
                    margin: const EdgeInsets.only(bottom: 32),
                    child: const CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Corner Widget ────────────────────────────────────
class _Corner extends StatelessWidget {
  final double? top;
  final double? bottom;
  final double? left;
  final double? right;

  const _Corner({this.top, this.bottom, this.left, this.right});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          border: Border(
            top: top != null
                ? const BorderSide(color: Colors.white, width: 4)
                : BorderSide.none,
            bottom: bottom != null
                ? const BorderSide(color: Colors.white, width: 4)
                : BorderSide.none,
            left: left != null
                ? const BorderSide(color: Colors.white, width: 4)
                : BorderSide.none,
            right: right != null
                ? const BorderSide(color: Colors.white, width: 4)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}
