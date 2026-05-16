import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Setelah anak ditambahkan, simpan child_id untuk generate QR
  String? _childId;
  String? _childName;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _addChild() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User tidak ditemukan');

      // Insert ke tabel children
      final response = await Supabase.instance.client
          .from('children')
          .insert({
            'parent_id': user.id,
            'child_name': _nameController.text.trim(),
            'age': int.parse(_ageController.text.trim()),
          })
          .select()
          .single();

      // Ambil child_id dari response
      setState(() {
        _childId = response['id'] as String;
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
                isLoading: _isLoading,
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

// ─── Form Tambah Anak ─────────────────────────────────
class _FormSection extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController ageController;
  final bool isLoading;
  final VoidCallback onSubmit;

  const _FormSection({
    required this.formKey,
    required this.nameController,
    required this.ageController,
    required this.isLoading,
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

          // Header
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
            'Isi data anak dulu, nanti kita buatkan\nQR Code khusus buat mereka.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),

          // Nama anak
          TextFormField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: AppStrings.childName,
              prefixIcon: Icon(Icons.child_care_rounded),
              hintText: 'Contoh: Budi, Siti',
            ),
            validator: (val) {
              if (val == null || val.isEmpty) {
                return 'Nama si kecil nggak boleh kosong ya';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Umur anak
          TextFormField(
            controller: ageController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: AppStrings.childAge,
              prefixIcon: Icon(Icons.cake_rounded),
              hintText: 'Contoh: 10',
              suffixText: 'tahun',
            ),
            validator: (val) {
              if (val == null || val.isEmpty) {
                return 'Umurnya diisi dulu ya';
              }
              final age = int.tryParse(val);
              if (age == null || age < 1 || age > 18) {
                return 'Umurnya antara 1 sampai 18 tahun ya';
              }
              return null;
            },
          ),
          const SizedBox(height: 40),

          // Tombol simpan
          ElevatedButton.icon(
            onPressed: isLoading ? null : onSubmit,
            icon: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.qr_code_rounded),
            label: Text(
              isLoading ? 'Lagi diproses...' : 'Buat QR Code',
            ),
          ),
        ],
      ),
    );
  }
}

// ─── QR Code Section ──────────────────────────────────
class _QRSection extends StatelessWidget {
  final String childId;
  final String childName;

  const _QRSection({
    required this.childId,
    required this.childName,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 8),

        // Header sukses
        const Icon(
          Icons.check_circle_rounded,
          color: AppColors.success,
          size: 48,
        ),
        const SizedBox(height: 12),
        Text(
          'QR Code untuk $childName sudah siap! 🎉',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Minta si kecil scan QR ini dari HP-nya ya.\nSatu QR hanya untuk satu HP anak.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        // QR Code
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
            data: childId,
            version: QrVersions.auto,
            size: 250,
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
        const SizedBox(height: 24),

        // Child ID sebagai teks manual
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              const Text(
                'ID Manual (kalau QR susah discan)',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(
                childId,
                style: const TextStyle(
                  fontSize: 13,
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

        // Tombol selesai
        ElevatedButton.icon(
          onPressed: () => context.go('/dashboard'),
          icon: const Icon(Icons.dashboard_rounded),
          label: const Text('Lihat Dashboard'),
        ),
        const SizedBox(height: 12),

        // Tombol tambah anak lagi
        OutlinedButton.icon(
          onPressed: () => context.pushReplacement('/add-child'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            side: const BorderSide(color: AppColors.primary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.add_rounded, color: AppColors.primary),
          label: const Text(
            'Tambah Anak Lagi',
            style: TextStyle(color: AppColors.primary),
          ),
        ),
      ],
    );
  }
}
