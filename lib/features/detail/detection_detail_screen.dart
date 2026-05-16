import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../models/detection.dart';

class DetectionDetailScreen extends StatefulWidget {
  final String detectionId;
  const DetectionDetailScreen({super.key, required this.detectionId});

  @override
  State<DetectionDetailScreen> createState() => _DetectionDetailScreenState();
}

class _DetectionDetailScreenState extends State<DetectionDetailScreen> {
  Detection? _detection;
  bool _isLoading = true;
  String? _signedUrl; // ← signed URL untuk tampilkan gambar

  @override
  void initState() {
    super.initState();
    _loadDetection();
  }

  Future<void> _loadDetection() async {
    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client
          .from('detections')
          .select()
          .eq('id', widget.detectionId)
          .maybeSingle();

      if (!mounted) return;

      if (response != null) {
        _detection = Detection.fromJson(response);

        // Generate signed URL
        await _generateSignedUrl(_detection!.screenshotUrl);
      }

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('PERISAI: load detection error → $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateSignedUrl(String screenshotUrl) async {
    if (screenshotUrl.isEmpty) return;

    try {
      // Ambil path dari URL
      // Format: .../storage/v1/object/public/screenshots/{child_id}/{timestamp}.jpg
      // atau  : .../storage/v1/object/screenshots/{child_id}/{timestamp}.jpg
      final uri = Uri.parse(screenshotUrl);
      final segments = uri.pathSegments;

      debugPrint('PERISAI: URL segments = $segments');

      final bucketIndex = segments.indexOf('screenshots');
      if (bucketIndex != -1 && bucketIndex < segments.length - 1) {
        final filePath = segments.sublist(bucketIndex + 1).join('/');
        debugPrint('PERISAI: filePath = $filePath');

        final signed = await Supabase.instance.client.storage
            .from('screenshots')
            .createSignedUrl(filePath, 3600);

        debugPrint('PERISAI: signed URL = $signed');
        if (mounted) setState(() => _signedUrl = signed);
      }
    } catch (e) {
      debugPrint('PERISAI: signed URL error → $e');
      // Fallback pakai URL asli
      if (mounted) setState(() => _signedUrl = screenshotUrl);
    }
  }

  Color get _badgeColor {
    switch (_detection?.triggeredBy) {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.detectionTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _detection == null
              ? _NotFound()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Screenshot — pakai signedUrl kalau ada
                      _ScreenshotSection(
                        screenshotUrl: _signedUrl ?? _detection!.screenshotUrl,
                      ),
                      const SizedBox(height: 20),

                      // Info card
                      _InfoCard(
                        detection: _detection!,
                        badgeColor: _badgeColor,
                      ),
                      const SizedBox(height: 16),

                      // Keywords
                      if (_detection!.keywords.isNotEmpty)
                        _KeywordsSection(keywords: _detection!.keywords),

                      const SizedBox(height: 16),

                      // Saran tindakan
                      _SuggestionSection(),
                      const SizedBox(height: 24),

                      // Tombol tandai dibaca
                      ElevatedButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Oke, sudah ditandai! ✅'),
                              backgroundColor: AppColors.success,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                          context.pop();
                        },
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        label: const Text(AppStrings.markAsRead),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
    );
  }
}

// ─── Screenshot Section ───────────────────────────────
class _ScreenshotSection extends StatelessWidget {
  final String screenshotUrl;
  const _ScreenshotSection({required this.screenshotUrl});

  @override
  Widget build(BuildContext context) {
    // Kalau URL kosong, tampilkan placeholder
    if (screenshotUrl.isEmpty) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_not_supported_outlined,
                size: 48,
                color: AppColors.textSecondary,
              ),
              SizedBox(height: 8),
              Text(
                'Screenshot tidak tersedia',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => Dialog(
            backgroundColor: Colors.black,
            insetPadding: EdgeInsets.zero,
            child: Stack(
              children: [
                Center(
                  child: CachedNetworkImage(
                    imageUrl: screenshotUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const CircularProgressIndicator(
                      color: Colors.white,
                    ),
                    errorWidget: (_, __, ___) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white,
                      size: 64,
                    ),
                  ),
                ),
                Positioned(
                  top: 40,
                  right: 16,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            CachedNetworkImage(
              imageUrl: screenshotUrl,
              width: double.infinity,
              height: 220,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                height: 220,
                color: AppColors.border,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                height: 220,
                color: AppColors.border,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.image_not_supported_outlined,
                        size: 48,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Gagal load gambar',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Overlay tap to fullscreen
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.fullscreen_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Tap untuk perbesar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Info Card ────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final Detection detection;
  final Color badgeColor;
  const _InfoCard({required this.detection, required this.badgeColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(
            icon: Icons.access_time_rounded,
            label: 'Waktu Terdeteksi',
            value: _formatDate(detection.createdAt),
          ),
          const Divider(height: 24),
          _InfoRow(
            icon: Icons.radar_rounded,
            label: AppStrings.triggeredBy,
            value: detection.triggeredByLabel,
            valueColor: badgeColor,
          ),
          const Divider(height: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.psychology_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    AppStrings.confidence,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    detection.confidencePercent,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.danger,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: detection.confidence,
                  backgroundColor: AppColors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    detection.confidence >= 0.8
                        ? AppColors.danger
                        : AppColors.warning,
                  ),
                  minHeight: 8,
                ),
              ),
            ],
          ),
          if (detection.details.isNotEmpty) ...[
            const Divider(height: 24),
            const Text(
              'Detail per Layer AI',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            if (detection.details['trustpositif'] != null)
              _LayerRow(
                label: 'Trustpositif',
                isDetected: detection.details['trustpositif'] == true,
                color: AppColors.trustpositif,
              ),
            if (detection.details['mobilenet_confidence'] != null)
              _LayerRow(
                label: 'MobileNet',
                isDetected: (detection.details['mobilenet_confidence'] is num)
                    ? (detection.details['mobilenet_confidence'] as num) >= 0.5
                    : false,
                color: AppColors.mobilenet,
                extra: (detection.details['mobilenet_confidence'] is num)
                    ? '${((detection.details['mobilenet_confidence'] as num) * 100).toStringAsFixed(0)}%'
                    : '',
              ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _LayerRow extends StatelessWidget {
  final String label;
  final bool isDetected;
  final Color color;
  final String? extra;

  const _LayerRow({
    required this.label,
    required this.isDetected,
    required this.color,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            isDetected ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 16,
            color: isDetected ? color : AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDetected ? color : AppColors.textSecondary,
            ),
          ),
          if (extra != null && extra!.isNotEmpty) ...[
            const Spacer(),
            Text(
              extra!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDetected ? color : AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Keywords Section ─────────────────────────────────
class _KeywordsSection extends StatelessWidget {
  final List<String> keywords;
  const _KeywordsSection({required this.keywords});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.text_fields_rounded,
                  size: 18, color: AppColors.danger),
              SizedBox(width: 8),
              Text(
                AppStrings.keywords,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: keywords.map((keyword) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                ),
                child: Text(
                  keyword,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.danger,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─── Suggestion Section ───────────────────────────────
class _SuggestionSection extends StatelessWidget {
  final List<String> _suggestions = const [
    'Ajak si kecil ngobrol dengan tenang, jangan langsung marah ya 😊',
    'Jelaskan bahaya judi online dengan bahasa yang mudah dimengerti',
    'Tanyakan dari mana mereka tau soal konten ini',
    'Pertimbangkan batasan waktu pemakaian HP',
    'Berikan kegiatan positif sebagai alternatif',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded,
                  size: 18, color: AppColors.success),
              SizedBox(width: 8),
              Text(
                'Yang Bisa Kamu Lakukan 💡',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._suggestions.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: AppColors.success)),
                  Expanded(
                    child: Text(
                      s,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Not Found ────────────────────────────────────────
class _NotFound extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🔍', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          const Text(
            'Deteksi tidak ditemukan',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Mungkin datanya sudah dihapus',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.pop(),
            child: const Text('Balik ke Dashboard'),
          ),
        ],
      ),
    );
  }
}
