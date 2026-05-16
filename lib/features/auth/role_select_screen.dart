import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_strings.dart';

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  Future<void> _selectRole(BuildContext context, String role) async {
    HapticFeedback.lightImpact();

    if (!context.mounted) return;

    if (role == 'parent') {
      context.push('/login');
    } else {
      context.push('/scan-qr');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              // Header
              const Text(
                '🛡️',
                style: TextStyle(fontSize: 48),
              ),
              const SizedBox(height: 16),
              const Text(
                AppStrings.roleSelectTitle,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pilih dulu ya, biar PERISAI tau\nmau nampilin apa buat kamu.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),

              const Spacer(),

              // Card Orang Tua
              _RoleCard(
                emoji: '👨‍👩‍👧',
                title: AppStrings.roleParent,
                desc: AppStrings.roleParentDesc,
                color: AppColors.primary,
                onTap: () => _selectRole(context, 'parent'),
              ),

              const SizedBox(height: 16),

              // Card Anak
              _RoleCard(
                emoji: '👦',
                title: AppStrings.roleChild,
                desc: AppStrings.roleChildDesc,
                color: AppColors.success,
                onTap: () => _selectRole(context, 'child'),
              ),

              const Spacer(),

              // Footer
              Center(
                child: Text(
                  'PERISAI v1.0.0',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String desc;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.emoji,
    required this.title,
    required this.desc,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // Emoji
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 32),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Arrow
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: color,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}