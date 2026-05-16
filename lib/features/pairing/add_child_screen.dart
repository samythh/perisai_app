import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_strings.dart';

class AddChildScreen extends StatefulWidget {
  const AddChildScreen({super.key});

  @override
  State<AddChildScreen> createState() => _AddChildScreenState();
}

class _AddChildScreenState extends State<AddChildScreen> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _childId;
  String? _childName;
  File? _avatarFile;
  String? _avatarLocalPath;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Pilih Foto Anak',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt_rounded,
                    color: AppColors.primary),
              ),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.photo_library_rounded,
                    color: AppColors.primary),
              ),
              title: const Text('Galeri'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    if (picked == null) return;
    setState(() {
      _avatarFile = File(picked.path);
      _avatarLocalPath = picked.path;
    });
  }

  Future<String?> _uploadAvatar(String childId) async {
    if (_avatarFile == null) return null;
    try {
      final bytes = await _avatarFile!.readAsBytes();
      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 256,
        minHeight: 256,
        quality: 70,
        format: CompressFormat.jpeg,
      );

      final path = 'children/$childId/profile.jpg';
      await Supabase.instance.client.storage.from('avatars').uploadBinary(
            path,
            compressed,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      return Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(path);
    } catch (e) {
      debugPrint('PERISAI: upload avatar anak error → $e');
      return null;
    }
  }

  Future<void> _addChild() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User tidak ditemukan');

      // Insert anak dulu untuk dapat child_id
      final response = await Supabase.instance.client
          .from('children')
          .insert({
            'parent_id': user.id,
            'child_name': _nameController.text.trim(),
            'age': int.parse(_ageController.text.trim()),
            'phone': _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
          })
          .select()
          .single();

      final childId = response['id'] as String;

      // Upload avatar kalau ada
      if (_avatarFile != null) {
        final avatarUrl = await _uploadAvatar(childId);
        if (avatarUrl != null) {
          await Supabase.instance.client
              .from('children')
              .update({'avatar_url': avatarUrl}).eq('id', childId);
        }
      }

      setState(() {
        _childId = childId;
        _childName = _nameController.text.trim();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Aduh, gagal nambah anak. Coba lagi?'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FA),
        elevation: 0,
        title: const Text(AppStrings.addChild),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _childId == null
            ? _FormSection(
                formKey: _formKey,
                nameController: _nameController,
                ageController: _ageController,
                phoneController: _phoneController,
                isLoading: _isLoading,
                avatarLocalPath: _avatarLocalPath,
                onPickAvatar: _pickAvatar,
                onSubmit: _addChild,
              )
            : _QRSection(
                childId: _childId!,
                childName: _childName!,
              ),
      ),
    );
  }
}

// ─── Form Section ─────────────────────────────────────
class _FormSection extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController ageController;
  final TextEditingController phoneController;
  final bool isLoading;
  final String? avatarLocalPath;
  final VoidCallback onPickAvatar;
  final VoidCallback onSubmit;

  const _FormSection({
    required this.formKey,
    required this.nameController,
    required this.ageController,
    required this.phoneController,
    required this.isLoading,
    required this.avatarLocalPath,
    required this.onPickAvatar,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text(
            'Siapa si kecilnya? 👶',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Lengkapi data anak, nanti kita buatkan\nQR Code khusus buat mereka.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),

          // ─── Avatar Picker ──────────────────────────
          Center(
            child: GestureDetector(
              onTap: onPickAvatar,
              child: Stack(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: avatarLocalPath != null
                        ? ClipOval(
                            child: Image.file(
                              File(avatarLocalPath!),
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(
                            Icons.child_care_rounded,
                            color: AppColors.primary,
                            size: 40,
                          ),
                  ),

                  // Icon kamera di kiri bawah
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Foto anak (opsional)',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 28),

          // ─── Nama Anak ──────────────────────────────
          _FieldLabel(label: 'Nama Anak'),
          TextFormField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Contoh: Budi Santoso',
              prefixIcon: const Icon(Icons.child_care_rounded,
                  color: AppColors.textSecondary),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
            validator: (val) {
              if (val == null || val.isEmpty) {
                return 'Nama si kecil nggak boleh kosong ya';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          // ─── Umur ───────────────────────────────────
          _FieldLabel(label: 'Umur'),
          TextFormField(
            controller: ageController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              hintText: 'Contoh: 10',
              prefixIcon: const Icon(Icons.cake_rounded,
                  color: AppColors.textSecondary),
              suffixText: 'tahun',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
            validator: (val) {
              if (val == null || val.isEmpty) return 'Umurnya diisi dulu ya';
              final age = int.tryParse(val);
              if (age == null || age < 1 || age > 18) {
                return 'Umurnya antara 1 sampai 18 tahun ya';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          // ─── Nomor HP ───────────────────────────────
          _FieldLabel(label: 'Nomor HP Anak (opsional)'),
          TextFormField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: 'Contoh: 08123456789',
              prefixIcon: const Icon(Icons.phone_outlined,
                  color: AppColors.textSecondary),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
            validator: (val) => null, // opsional
          ),
          const SizedBox(height: 40),

          // ─── Tombol Simpan ──────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              icon: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.qr_code_rounded, color: Colors.white),
              label: Text(
                isLoading ? 'Lagi diproses...' : 'Buat QR Code',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Field Label ──────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

// ─── QR Section ───────────────────────────────────────
class _QRSection extends StatefulWidget {
  final String childId;
  final String childName;

  const _QRSection({required this.childId, required this.childName});

  @override
  State<_QRSection> createState() => _QRSectionState();
}

class _QRSectionState extends State<_QRSection> {
  late final RealtimeChannel _channel;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _listenForPairing();
  }

  @override
  void dispose() {
    Supabase.instance.client.removeChannel(_channel);
    super.dispose();
  }

  void _listenForPairing() {
    _channel = Supabase.instance.client
        .channel('pairing-${widget.childId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'children',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.childId,
          ),
          callback: (payload) {
            final newData = payload.newRecord;
            if (newData['device_id'] != null &&
                newData['device_id'].toString().isNotEmpty) {
              _showSuccessDialog();
            }
          },
        )
        .subscribe();
  }

  void _showSuccessDialog() {
    if (!mounted) return;
    setState(() => _isConnected = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 56),
            ),
            const SizedBox(height: 20),
            Text(
              'HP ${widget.childName} berhasil terhubung! 🎉',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'PERISAI sekarang aktif di HP ${widget.childName}. '
              'Kamu bisa pantau aktivitasnya dari dashboard.',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.go('/main');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Lihat Dashboard',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tetap di sini',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _isConnected
              ? const Icon(Icons.check_circle_rounded,
                  key: ValueKey('c'), color: AppColors.success, size: 48)
              : const Icon(Icons.qr_code_rounded,
                  key: ValueKey('w'), color: AppColors.primary, size: 48),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            _isConnected
                ? '${widget.childName} sudah terhubung! ✅'
                : 'QR Code untuk ${widget.childName} sudah siap! 🎉',
            key: ValueKey('t$_isConnected'),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isConnected
              ? 'HP anak sudah terhubung dengan PERISAI.'
              : 'Minta si kecil scan QR ini dari HP-nya ya.\n'
                  'Kalau putus, tinggal scan ulang.',
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _isConnected
                ? AppColors.success.withOpacity(0.1)
                : AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isConnected
                  ? AppColors.success.withOpacity(0.3)
                  : AppColors.primary.withOpacity(0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isConnected
                    ? Icons.shield_rounded
                    : Icons.hourglass_empty_rounded,
                color: _isConnected ? AppColors.success : AppColors.primary,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                _isConnected
                    ? 'PERISAI aktif di HP anak'
                    : 'Menunggu anak scan QR...',
                style: TextStyle(
                  color: _isConnected ? AppColors.success : AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: QrImageView(
            data: widget.childId,
            version: QrVersions.auto,
            size: 220,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: AppColors.primary,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              const Text('ID Manual (kalau QR susah discan)',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              SelectableText(
                widget.childId,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () => context.go('/main'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            icon: const Icon(Icons.dashboard_rounded, color: Colors.white),
            label: const Text('Lihat Dashboard',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => context.pushReplacement('/add-child'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            side: const BorderSide(color: AppColors.primary),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.add_rounded, color: AppColors.primary),
          label: const Text('Tambah Anak Lagi',
              style: TextStyle(color: AppColors.primary)),
        ),
      ],
    );
  }
}
