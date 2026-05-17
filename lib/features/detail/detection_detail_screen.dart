import 'dart:ui'; // Tambahan untuk efek Blur
import 'package:url_launcher/url_launcher.dart';
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
  String? _signedUrl;
  String?
      _childPhoneNumber; // ← Tambahan variabel untuk menyimpan nomor HP anak

  @override
  void initState() {
    super.initState();
    _loadDetection();
  }

  // =================================================================
  // LOGIKA MENGAMBIL DATA DETEKSI & NOMOR HP ANAK DARI SUPABASE
  // =================================================================
  Future<void> _loadDetection() async {
    setState(() => _isLoading = true);

    try {
      // 1. Ambil data deteksi
      final response = await Supabase.instance.client
          .from('detections')
          .select()
          .eq('id', widget.detectionId)
          .maybeSingle();

      if (!mounted) return;

      if (response != null) {
        _detection = Detection.fromJson(response);
        await _generateSignedUrl(_detection!.screenshotUrl);

        // 2. Ambil data nomor HP anak dari tabel 'children'
        try {
          final childId = response['child_id'];
          if (childId != null) {
            final childRes = await Supabase.instance.client
                .from('children')
                .select(
                    'phone') // Sesuaikan nama kolom jika berbeda (misal: 'no_hp' atau 'phone')
                .eq('id', childId)
                .maybeSingle();

            if (childRes != null && childRes['phone'] != null) {
              _childPhoneNumber = childRes['phone'].toString();
            }
          }
        } catch (e) {
          debugPrint('PERISAI: Gagal mengambil nomor HP anak → $e');
        }
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
      final uri = Uri.parse(screenshotUrl);
      final segments = uri.pathSegments;

      final bucketIndex = segments.indexOf('screenshots');
      if (bucketIndex != -1 && bucketIndex < segments.length - 1) {
        final filePath = segments.sublist(bucketIndex + 1).join('/');

        final signed = await Supabase.instance.client.storage
            .from('screenshots')
            .createSignedUrl(filePath, 3600);

        if (mounted) setState(() => _signedUrl = signed);
      }
    } catch (e) {
      debugPrint('PERISAI: signed URL error → $e');
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
      backgroundColor: const Color(0xFFF8F9FA), // Latar abu-abu sangat muda
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1A1A)),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _detection == null
              ? _NotFound()
              : SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ==========================================
                      // HEADER: BADGE & JUDUL
                      // ==========================================
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE4E6), // Merah muda pudar
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_rounded,
                                size: 16, color: Color(0xFFE11D48)),
                            SizedBox(width: 6),
                            Text(
                              'Bahaya Terdeteksi',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFE11D48),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Deteksi Aktivitas\nMencurigakan',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A1A),
                          height: 1.3,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ==========================================
                      // SCREENSHOT DENGAN BLUR & TOMBOL MATA
                      // ==========================================
                      _ScreenshotSection(
                        screenshotUrl: _signedUrl ?? _detection!.screenshotUrl,
                      ),
                      const SizedBox(height: 24),

                      // ==========================================
                      // INFO CARD UTAMA (Desain Dibersihkan)
                      // ==========================================
                      _InfoCard(
                        detection: _detection!,
                        badgeColor: _badgeColor,
                      ),
                      const SizedBox(height: 16),

                      // ==========================================
                      // KATA KUNCI & SARAN
                      // ==========================================
                      if (_detection!.keywords.isNotEmpty) ...[
                        _KeywordsSection(keywords: _detection!.keywords),
                        const SizedBox(height: 16),
                      ],
                      _SuggestionSection(),
                      const SizedBox(height: 32),

                      // ==========================================
                      // ACTION BUTTON: HUBUNGI ANAK
                      // ==========================================
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            HapticFeedback.lightImpact();

                            // Validasi apakah nomor HP ada
                            if (_childPhoneNumber == null ||
                                _childPhoneNumber!.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                      'Nomor HP anak belum terdaftar di sistem!'),
                                  backgroundColor: AppColors.warning,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              );
                              return;
                            }

                            // Format Nomor HP (Bersihkan karakter selain angka)
                            String cleanPhone = _childPhoneNumber!
                                .replaceAll(RegExp(r'[^0-9]'), '');

                            // Ubah format 08... menjadi 628...
                            if (cleanPhone.startsWith('0')) {
                              cleanPhone = '62${cleanPhone.substring(1)}';
                            }

                            final String pesanTeks =
                                "Nak, orang tua mendapat peringatan keamanan dari PERISAI. Tolong angkat teleponnya ya.";
                            final Uri whatsappUrl = Uri.parse(
                                "https://wa.me/$cleanPhone?text=${Uri.encodeComponent(pesanTeks)}");

                            // Buka WhatsApp
                            if (await canLaunchUrl(whatsappUrl)) {
                              await launchUrl(whatsappUrl,
                                  mode: LaunchMode.externalApplication);
                            } else {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                        'Gagal membuka WhatsApp. Pastikan aplikasi terinstal.'),
                                    backgroundColor: AppColors.danger,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF10B981), // Hijau
                            side: const BorderSide(
                                color: Color(0xFFE5E7EB), width: 1.5),
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon:
                              const Icon(Icons.phone_in_talk_rounded, size: 20),
                          label: const Text(
                            'HUBUNGI VIA WHATSAPP',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }
}

// ─── Screenshot Section DENGAN EFEK BLUR ─────────────────
class _ScreenshotSection extends StatelessWidget {
  final String screenshotUrl;
  const _ScreenshotSection({required this.screenshotUrl});

  @override
  Widget build(BuildContext context) {
    if (screenshotUrl.isEmpty) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_not_supported_outlined,
                  size: 48, color: Color(0xFF9CA3AF)),
              SizedBox(height: 8),
              Text('Screenshot tidak tersedia',
                  style: TextStyle(color: Color(0xFF6B7280))),
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
                    placeholder: (_, __) =>
                        const CircularProgressIndicator(color: Colors.white),
                    errorWidget: (_, __, ___) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white,
                        size: 64),
                  ),
                ),
                Positioned(
                  top: 40,
                  right: 16,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 32),
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
        child: SizedBox(
          height: 220,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: screenshotUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(color: const Color(0xFFE5E7EB)),
                errorWidget: (_, __, ___) =>
                    Container(color: const Color(0xFFE5E7EB)),
              ),
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  color: Colors.black.withOpacity(0.3),
                ),
              ),
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility_rounded,
                          color: Color(0xFF1A1A1A), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'TAMPILKAN BUKTI',
                        style: TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Info Card (Desain Baru, Tanpa Detail Layer) ────────────────
class _InfoCard extends StatelessWidget {
  final Detection detection;
  final Color badgeColor;
  const _InfoCard({required this.detection, required this.badgeColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'WAKTU DETEKSI',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF9CA3AF),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDateTop(detection.createdAt),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'KATEGORI',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF9CA3AF),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'High Risk',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFE5E7EB), height: 1),
          const SizedBox(height: 16),

          _InfoRow(
            icon: Icons.radar_rounded,
            label: AppStrings.triggeredBy,
            value: detection.triggeredByLabel,
            valueColor: badgeColor,
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              const Icon(Icons.psychology_rounded,
                  size: 18, color: Color(0xFF6B7280)),
              const SizedBox(width: 8),
              const Text(
                AppStrings.confidence,
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
              const Spacer(),
              Text(
                detection.confidencePercent,
                style: TextStyle(
                  fontSize: 15,
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
              backgroundColor: const Color(0xFFF3F4F6),
              valueColor: AlwaysStoppedAnimation<Color>(
                detection.confidence >= 0.8
                    ? AppColors.danger
                    : AppColors.warning,
              ),
              minHeight: 6,
            ),
          ),

          // Bagian Detail Layer AI sudah dihapus seluruhnya dari sini
        ],
      ),
    );
  }

  String _formatDateTop(DateTime dt) {
    final now = DateTime.now();
    final timeStr =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} WIB';

    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '$timeStr, Hari ini';
    }
    return '$timeStr, ${dt.day}/${dt.month}/${dt.year}';
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
        Icon(icon, size: 18, color: const Color(0xFF6B7280)),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: valueColor ?? const Color(0xFF1A1A1A),
          ),
        ),
      ],
    );
  }
}

// ─── Keywords Section (Sama persis) ────────────────────
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
        border: Border.all(color: AppColors.danger.withOpacity(0.15)),
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
                  fontWeight: FontWeight.w700,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.3)),
                ),
                child: Text(
                  keyword,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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

// ─── Suggestion Section (Sama persis) ──────────────────
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
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD1FAE5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded,
                  size: 18, color: Color(0xFF10B981)),
              SizedBox(width: 8),
              Text(
                'Yang Bisa Kamu Lakukan 💡',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF10B981),
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
                  const Text('• ',
                      style: TextStyle(
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Text(
                      s,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF4B5563),
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

// ─── Not Found (Sama persis) ──────────────────────────
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
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Mungkin datanya sudah dihapus',
            style: TextStyle(color: Color(0xFF6B7280)),
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
