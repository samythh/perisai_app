import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../../core/theme/app_colors.dart';
import '../../models/child.dart';
import '../../models/detection.dart';

class ChildDetailScreen extends StatefulWidget {
  final Child child;
  const ChildDetailScreen({super.key, required this.child});

  @override
  State<ChildDetailScreen> createState() => _ChildDetailScreenState();
}

class _ChildDetailScreenState extends State<ChildDetailScreen> {
  List<Detection> _detections = [];
  bool _isLoading = true;
  late Child _child;
  RealtimeChannel? _statusChannel;

  @override
  void initState() {
    super.initState();
    _child = widget.child;
    _loadDetections();
    _refreshChildStatus();
    _subscribeChildStatus();
  }

  @override
  void dispose() {
    if (_statusChannel != null) {
      Supabase.instance.client.removeChannel(_statusChannel!);
    }
    super.dispose();
  }

  // Realtime listener — auto-refresh saat status anak berubah
  void _subscribeChildStatus() {
    _statusChannel = Supabase.instance.client
        .channel('child_status_${_child.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'children',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: _child.id,
          ),
          callback: (payload) {
            final newData = payload.newRecord;
            if (newData.isEmpty || !mounted) return;
            debugPrint('PERISAI: Detail — status berubah realtime!');
            setState(() {
              _child = Child.fromJson(newData);
            });
          },
        )
        .subscribe();
  }

  // Fetch fresh connection status dari DB
  Future<void> _refreshChildStatus() async {
    try {
      final data = await Supabase.instance.client
          .from('children')
          .select()
          .eq('id', _child.id)
          .single();
      if (!mounted) return;
      setState(() {
        _child = Child.fromJson(data);
      });
    } catch (e) {
      debugPrint('PERISAI: Gagal refresh child status → $e');
    }
  }

  // ─── Show QR Bottom Sheet ───────────────────────────
  void _showQrSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Header icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.qr_code_2_rounded,
                  color: AppColors.primary, size: 24),
            ),
            const SizedBox(height: 14),

            // Title
            Text(
              'QR Akun ${_child.firstName}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Scan QR ini dari HP anak untuk\nmenghubungkan kembali',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // QR Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.15),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // QR Code
                  QrImageView(
                    data: _child.id,
                    version: QrVersions.auto,
                    size: 200,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.circle,
                      color: AppColors.primary,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.circle,
                      color: Color(0xFF1A1A2E),
                    ),
                    gapless: true,
                  ),
                  const SizedBox(height: 16),

                  // Child name badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_rounded,
                            color: AppColors.primary, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          _child.childName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Instruction
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.1),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: AppColors.primary, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Buka PERISAI di HP anak → pilih "Saya Anak" → Scan QR ini',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditSheet() async {
    final nameCtrl  = TextEditingController(text: _child.childName);
    final phoneCtrl = TextEditingController(text: _child.phone ?? '');
    final formKey   = GlobalKey<FormState>();
    bool saving     = false;

    final now = DateTime.now();
    DateTime selectedDate =
        DateTime(now.year - _child.age, now.month, now.day);
    Uint8List? pickedImageBytes;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        // Ambil MediaQuery dari parent context (bukan sheet context)
        // untuk menghindari crash _dependents.isEmpty
        final screenHeight = MediaQuery.of(context).size.height;
        return StatefulBuilder(
        builder: (innerCtx, setModal) {
          // Hitung usia dari tanggal yang dipilih
          int computedAge = now.year - selectedDate.year;
          if (now.month < selectedDate.month ||
              (now.month == selectedDate.month &&
                  now.day < selectedDate.day)) {
            computedAge--;
          }
          computedAge = computedAge.clamp(0, 18);

          return Container(
            constraints:
                BoxConstraints(maxHeight: screenHeight * 0.88),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(innerCtx).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.edit_rounded,
                            color: AppColors.primary, size: 18),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Edit Identitas Anak',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary)),
                          Text('Ubah profil anak kamu',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Scrollable form
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Foto profil ──
                          Center(
                            child: GestureDetector(
                              onTap: () async {
                                final picker = ImagePicker();
                                final picked = await picker.pickImage(
                                    source: ImageSource.gallery,
                                    imageQuality: 80);
                                if (picked == null) return;
                                final bytes = await picked.readAsBytes();
                                setModal(() => pickedImageBytes = bytes);
                              },
                              child: Stack(
                                children: [
                                  Container(
                                    width: 84,
                                    height: 84,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: pickedImageBytes != null
                                        ? ClipOval(
                                            child: Image.memory(
                                              pickedImageBytes!,
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : (_child.avatarUrl != null &&
                                                _child.avatarUrl!.isNotEmpty
                                            ? ClipOval(
                                                child: Image.network(
                                                  _child.avatarUrl!,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      _InitialAvatar(
                                                          name: _child.firstName,
                                                          size: 28),
                                                ),
                                              )
                                            : _InitialAvatar(
                                                name: _child.firstName,
                                                size: 28)),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      width: 26,
                                      height: 26,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white, width: 2),
                                      ),
                                      child: const Icon(
                                          Icons.camera_alt_rounded,
                                          color: Colors.white,
                                          size: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Center(
                            child: Text('Ketuk untuk ganti foto',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                          ),
                          const SizedBox(height: 24),

                          // ── Nama ──
                          const Text('Nama Lengkap',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary)),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: nameCtrl,
                            textCapitalization: TextCapitalization.words,
                            style: const TextStyle(
                                fontSize: 14, color: AppColors.textPrimary),
                            decoration: _inputDecoration('Masukkan nama anak',
                                Icons.person_outline_rounded),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Nama tidak boleh kosong'
                                : null,
                          ),
                          const SizedBox(height: 16),

                          // ── Nomor HP ──
                          const Text('Nomor HP Anak',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary)),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: phoneCtrl,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(
                                fontSize: 14, color: AppColors.textPrimary),
                            decoration: _inputDecoration(
                                'Contoh: 08123456789', Icons.phone_outlined),
                          ),
                          const SizedBox(height: 16),

                          // ── Tanggal lahir ──
                          const Text('Tanggal Lahir',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary)),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: innerCtx,
                                initialDate: selectedDate,
                                firstDate: DateTime(now.year - 18),
                                lastDate: now,
                                helpText: 'Pilih Tanggal Lahir Anak',
                              );
                              if (picked != null) {
                                setModal(() => selectedDate = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.cake_outlined,
                                      color: AppColors.textSecondary, size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}  •  $computedAge tahun',
                                      style: const TextStyle(
                                          fontSize: 14,
                                          color: AppColors.textPrimary),
                                    ),
                                  ),
                                  const Icon(Icons.calendar_today_outlined,
                                      color: AppColors.textSecondary, size: 16),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),

                          // ── Tombol simpan ──
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                              onPressed: saving
                                  ? null
                                  : () async {
                                      if (!formKey.currentState!.validate()) return;
                                      setModal(() => saving = true);
                                      try {
                                        // Hitung usia final dari tanggal lahir
                                        int newAge = now.year - selectedDate.year;
                                        if (now.month < selectedDate.month ||
                                            (now.month == selectedDate.month &&
                                                now.day < selectedDate.day)) {
                                          newAge--;
                                        }
                                        newAge = newAge.clamp(0, 18);

                                        // Upload foto jika dipilih
                                        String? newAvatarUrl = _child.avatarUrl;
                                        if (pickedImageBytes != null) {
                                          final compressed =
                                              await _compressImage(pickedImageBytes!);
                                          if (compressed != null) {
                                            final path =
                                                '${_child.parentId}/children/${_child.id}/profile.jpg';
                                            await Supabase.instance.client.storage
                                                .from('avatars')
                                                .uploadBinary(
                                                  path,
                                                  compressed,
                                                  fileOptions: const FileOptions(
                                                    upsert: true,
                                                    contentType: 'image/jpeg',
                                                  ),
                                                );
                                            newAvatarUrl = Supabase
                                                .instance.client.storage
                                                .from('avatars')
                                                .getPublicUrl(path);
                                          }
                                        }

                                        final phoneVal =
                                            phoneCtrl.text.trim().isEmpty
                                                ? null
                                                : phoneCtrl.text.trim();

                                        await Supabase.instance.client
                                            .from('children')
                                            .update({
                                              'child_name': nameCtrl.text.trim(),
                                              'age': newAge,
                                              'phone': phoneVal,
                                              'avatar_url': newAvatarUrl,
                                            })
                                            .eq('id', _child.id);

                                        final updated = Child(
                                          id: _child.id,
                                          parentId: _child.parentId,
                                          childName: nameCtrl.text.trim(),
                                          age: newAge,
                                          phone: phoneVal,
                                          avatarUrl: newAvatarUrl,
                                          createdAt: _child.createdAt,
                                          connectionStatus: _child.connectionStatus,
                                          lastSeen: _child.lastSeen,
                                        );
                                        // ignore: use_build_context_synchronously
                                        Navigator.pop(innerCtx);
                                        if (!mounted) return;
                                        setState(() => _child = updated);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: const Text(
                                                'Identitas anak berhasil diperbarui ✅'),
                                            backgroundColor: AppColors.success,
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12)),
                                          ),
                                        );
                                      } catch (e) {
                                        setModal(() => saving = false);
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Gagal menyimpan: $e'),
                                            backgroundColor: AppColors.danger,
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12)),
                                          ),
                                        );
                                      }
                                    },
                              child: saving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2))
                                  : const Text('Simpan Perubahan',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
      },
    );
  }

  Future<Uint8List?> _compressImage(Uint8List bytes) async {
    return FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 256,
      minHeight: 256,
      quality: 60,
      format: CompressFormat.jpeg,
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
      filled: true,
      fillColor: AppColors.background,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger)),
    );
  }

  Future<void> _loadDetections() async {
    try {
      final res = await Supabase.instance.client
          .from('detections')
          .select()
          .eq('child_id', widget.child.id)
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _detections = (res as List).map((j) => Detection.fromJson(j)).toList();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  // ─── Computed props ────────────────────────────────
  List<Detection> get _thisWeek {
    final now = DateTime.now();
    final weekStart =
        DateTime(now.year, now.month, now.day - (now.weekday - 1));
    return _detections.where((d) => d.createdAt.isAfter(weekStart)).toList();
  }

  List<int> get _weeklyCount {
    final counts = List<int>.filled(7, 0);
    final now = DateTime.now();
    final weekStart =
        DateTime(now.year, now.month, now.day - (now.weekday - 1));
    for (final d in _detections) {
      final diff = d.createdAt.difference(weekStart).inDays;
      if (diff >= 0 && diff < 7) counts[diff]++;
    }
    return counts;
  }

  int get _safeScore => (100 - (_thisWeek.length * 10)).clamp(0, 100);
  bool get _isSafe => _thisWeek.isEmpty;

  Color get _scoreColor {
    if (_safeScore >= 80) return AppColors.success;
    if (_safeScore >= 50) return AppColors.warning;
    return AppColors.danger;
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 60) return '${diff.inMinutes} mnt lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }

  String _detectionTitle(String by) {
    switch (by) {
      case 'ocr':          return 'Teks Judol Terdeteksi';
      case 'mobilenet':    return 'Visual Judol Terdeteksi';
      case 'trustpositif': return 'URL Judol Terdeteksi';
      case 'combined':     return 'Judol Terdeteksi';
      default:             return 'Konten Mencurigakan';
    }
  }

  // ─── Build ─────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final child = _child;
    final firstName = child.childName.split(' ').first;
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : CustomScrollView(
              slivers: [
                // ── App bar area ───────────────────────
                SliverToBoxAdapter(
                  child: Container(
                    color: AppColors.primary,
                    padding: EdgeInsets.fromLTRB(20, top + 12, 20, 0),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.pop(),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.arrow_back_rounded,
                                color: Colors.white, size: 18),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Detail Anak',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _showQrSheet,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.qr_code_rounded,
                                color: Colors.white, size: 18),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _showEditSheet,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.edit_rounded,
                                color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Hero card (biru) ───────────────────
                SliverToBoxAdapter(
                  child: Container(
                    color: AppColors.primary,
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Profile section
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                // Avatar
                                Stack(
                                  children: [
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: child.avatarUrl != null &&
                                              child.avatarUrl!.isNotEmpty
                                          ? ClipOval(
                                              child: Image.network(
                                                child.avatarUrl!,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    _InitialAvatar(
                                                        name: firstName,
                                                        size: 24),
                                              ),
                                            )
                                          : _InitialAvatar(
                                              name: firstName, size: 24),
                                    ),
                                    Positioned(
                                      bottom: 2,
                                      right: 2,
                                      child: _buildStatusDot(child.effectiveStatus),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        child.childName,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${child.age} tahun',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Status badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: _isSafe
                                        ? AppColors.success
                                            .withValues(alpha: 0.1)
                                        : AppColors.warning
                                            .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: _isSafe
                                          ? AppColors.success
                                              .withValues(alpha: 0.3)
                                          : AppColors.warning
                                              .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    _isSafe ? '✓ Aman' : '⚠ Waspada',
                                    style: TextStyle(
                                      color: _isSafe
                                          ? AppColors.success
                                          : AppColors.warning,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Divider
                          const Divider(height: 1, color: AppColors.border),

                          // 3 Stats
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Row(
                              children: [
                                _StatItem(
                                  label: 'Ancaman\nMinggu Ini',
                                  value: '${_thisWeek.length}',
                                  color: _isSafe
                                      ? AppColors.success
                                      : AppColors.danger,
                                ),
                                _VerticalDivider(),
                                _StatItem(
                                  label: 'Total\nDeteksi',
                                  value: '${_detections.length}',
                                  color: AppColors.primary,
                                ),
                                _VerticalDivider(),
                                _StatItem(
                                  label: 'Safe\nScore',
                                  value: '$_safeScore%',
                                  color: _scoreColor,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Penutup biru → abu ─────────────────
                SliverToBoxAdapter(
                  child: Container(
                    height: 24,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(0),
                      ),
                    ),
                  ),
                ),

                // ── Status Koneksi ──────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: _ConnectionStatusCard(child: child),
                  ),
                ),

                // ── Chart ──────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _SectionCard(
                      title: 'Aktivitas Minggu Ini',
                      subtitle: 'Deteksi per hari',
                      child: _WeeklyBarChart(counts: _weeklyCount),
                    ),
                  ),
                ),

                // ── Riwayat ────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Riwayat Deteksi',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (_detections.isNotEmpty)
                          Text(
                            '${_detections.length} kejadian',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                _detections.isEmpty
                    ? SliverToBoxAdapter(child: _EmptyDetection())
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => Padding(
                            padding:
                                const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: _DetectionTile(
                              detection: _detections[i],
                              title: _detectionTitle(
                                  _detections[i].triggeredBy),
                              timeAgo: _timeAgo(_detections[i].createdAt),
                              onTap: () =>
                                  context.push('/detail/${_detections[i].id}'),
                            ),
                          ),
                          childCount: _detections.length,
                        ),
                      ),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
    );
  }

  // ─── Status dot helper ──────────────────────────────
  Widget _buildStatusDot(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.online:
        return Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: AppColors.success,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        );
      case ConnectionStatus.offlineInternet:
        return Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: AppColors.danger,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        );
      case ConnectionStatus.offlineManual:
        return Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: AppColors.warning,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: const Icon(
            Icons.link_off_rounded,
            size: 8,
            color: Colors.white,
          ),
        );
    }
  }
}

// ─── Connection Status Card ───────────────────────────
class _ConnectionStatusCard extends StatelessWidget {
  final Child child;
  const _ConnectionStatusCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final Color statusColor;
    final IconData statusIcon;
    final Color bgColor;

    switch (child.effectiveStatus) {
      case ConnectionStatus.online:
        statusColor = AppColors.success;
        statusIcon = Icons.wifi_rounded;
        bgColor = AppColors.success.withValues(alpha: 0.06);
      case ConnectionStatus.offlineInternet:
        statusColor = AppColors.danger;
        statusIcon = Icons.wifi_off_rounded;
        bgColor = AppColors.danger.withValues(alpha: 0.06);
      case ConnectionStatus.offlineManual:
        statusColor = AppColors.warning;
        statusIcon = Icons.link_off_rounded;
        bgColor = AppColors.warning.withValues(alpha: 0.06);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Text(
                'Status Koneksi',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              // Status chip
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      child.connectionLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Detail card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 20),
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        child.connectionDescription,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                          height: 1.4,
                        ),
                      ),
                      if (!child.isOnline && child.lastSeen != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 13,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Terakhir terlihat ${child.lastSeenText}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
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

// ─── Initial Avatar ───────────────────────────────────
class _InitialAvatar extends StatelessWidget {
  final String name;
  final double size;
  const _InitialAvatar({required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          color: AppColors.primary,
          fontSize: size,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ─── Stat Item ────────────────────────────────────────
class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatItem(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 40, color: AppColors.border);
  }
}

// ─── Section Card ─────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const _SectionCard(
      {required this.title, required this.subtitle, required this.child});

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
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ─── Detection Tile ───────────────────────────────────
class _DetectionTile extends StatelessWidget {
  final Detection detection;
  final String title;
  final String timeAgo;
  final VoidCallback onTap;
  const _DetectionTile({
    required this.detection,
    required this.title,
    required this.timeAgo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: AppColors.danger, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      )),
                  const SizedBox(height: 2),
                  Text(timeAgo,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────
class _EmptyDetection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: const [
          Text('🛡️', style: TextStyle(fontSize: 48)),
          SizedBox(height: 12),
          Text('Tidak ada deteksi',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          SizedBox(height: 4),
          Text('HP anak aman dari konten berbahaya',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ─── Weekly Bar Chart ─────────────────────────────────
class _WeeklyBarChart extends StatelessWidget {
  final List<int> counts;
  const _WeeklyBarChart({required this.counts});

  static const _days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  @override
  Widget build(BuildContext context) {
    final maxVal = counts.reduce((a, b) => a > b ? a : b);
    final chartMax = maxVal < 4 ? 4 : maxVal + 1;
    final today = DateTime.now().weekday - 1;

    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (i) {
          final ratio = counts[i] / chartMax;
          final isToday = i == today;
          final hasDetection = counts[i] > 0;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (hasDetection)
                    Text(
                      '${counts[i]}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isToday
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    )
                  else
                    const SizedBox(height: 14),
                  const SizedBox(height: 2),
                  Flexible(
                    child: FractionallySizedBox(
                      heightFactor: ratio == 0 ? 0.05 : ratio,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isToday
                              ? AppColors.primary
                              : AppColors.primaryLight
                                  .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _days[i],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight:
                          isToday ? FontWeight.w700 : FontWeight.w400,
                      color: isToday
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
