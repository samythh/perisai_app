import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    await ChannelService.startService(childId);

    if (!mounted) return;

    // Tampilkan dialog sukses sebelum lanjut
    _showSuccessDialog(childId);
  }

  void _showSuccessDialog(String childId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Yeay, berhasil! 🎉',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'HP kamu sekarang terhubung dengan\norang tua. PERISAI siap menjaga kamu!',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Navigasi ke layar aktif
                context.go('/active');
              },
              child: const Text('Oke, siap! 🛡️'),
            ),
          ],
        ),
      ),
    );
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
                    color: Colors.black.withOpacity(0.6),
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
