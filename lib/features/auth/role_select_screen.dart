import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';

class RoleSelectScreen extends StatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen> {
  String? _selectedRole;

  void _selectRole(String role) {
    HapticFeedback.lightImpact();
    setState(() => _selectedRole = role);
  }

  void _continue() {
    if (_selectedRole == null) return;
    HapticFeedback.lightImpact();

    if (_selectedRole == 'parent') {
      context.push('/login');
    } else {
      context.push('/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header biru
          _HeaderSection(),

          // List role
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              child: Column(
                children: [
                  _RoleOption(
                    image: 'assets/images/orangtua.png',
                    label: 'Orang Tua',
                    isSelected: _selectedRole == 'parent',
                    onTap: () => _selectRole('parent'),
                  ),
                  const SizedBox(height: 12),
                  _RoleOption(
                    image: 'assets/images/anak.png',
                    label: 'Anak', // ← diubah
                    isSelected: _selectedRole == 'child',
                    onTap: () => _selectRole('child'),
                  ),
                ],
              ),
            ),
          ),

          // Tombol Lanjutkan
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _selectedRole == null ? null : _continue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedRole == null
                      ? const Color(0xFFE5E5E5)
                      : AppColors.primary,
                  disabledBackgroundColor: const Color(0xFFE5E5E5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'LANJUTKAN',
                  style: TextStyle(
                    color: _selectedRole == null
                        ? const Color(0xFFAAAAAA)
                        : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Header Biru ──────────────────────────────────────
class _HeaderSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.38,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Stack(
        children: [
          // Background splash pattern
          Positioned.fill(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              child: Image.asset(
                'assets/images/splash.png',
                fit: BoxFit.cover,
                opacity: const AlwaysStoppedAnimation(0.15),
              ),
            ),
          ),

          // Konten — di bawah, hampir sejajar garis bawah
          Positioned(
            bottom: 24, // ← jarak dari bawah widget biru
            left: 24,
            right: 24,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end, // ← sejajar bawah
              children: [
                // Maskot di kiri — lebih besar
                Image.asset(
                  'assets/images/maskot.png',
                  width: 130, // ← dibesarkan
                  height: 130,
                ),

                const SizedBox(width: 8),

                // Speech bubble di kanan
                Expanded(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Segitiga ekor di kiri bubble
                      Positioned(
                        left: -12,
                        top: 0,
                        bottom: 0,
                        child: Align(
                          alignment: Alignment.center,
                          child: ClipPath(
                            clipper: _BubbleTailClipper(),
                            child: Container(
                              width: 16,
                              height: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                      // Bubble
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          'Halo! Ayo pilih peran\nkamu di Perisai',
                          style: TextStyle(
                            fontSize: 16, // ← dibesarkan
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500,
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
        ],
      ),
    );
  }
}

// Segitiga mengarah ke kiri
class _BubbleTailClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width, 0);
    path.lineTo(0, size.height / 2);
    path.lineTo(size.width, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

// ─── Role Option ──────────────────────────────────────
class _RoleOption extends StatelessWidget {
  final String image;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleOption({
    required this.image,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFE5E5E5),
            width: isSelected ? 2.5 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Image.asset(
              image,
              width: 48,
              height: 48,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color:
                      isSelected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ),
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
