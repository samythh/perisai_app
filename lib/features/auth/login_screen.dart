import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_strings.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Simpan role setelah login berhasil
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('role', 'parent');

      if (!mounted) return;
      context.go('/dashboard');
    } catch (e) {
      if (!mounted) return;

      String errorMsg = AppStrings.errorLogin;
      final errorStr = e.toString().toLowerCase();

      if (errorStr.contains('invalid login credentials') ||
          errorStr.contains('invalid_credentials')) {
        errorMsg = 'Email atau password salah nih';
      } else if (errorStr.contains('user not found') ||
          errorStr.contains('email not confirmed')) {
        errorMsg = 'Email belum terdaftar. Yuk daftar dulu!';
      } else if (errorStr.contains('network') || errorStr.contains('socket')) {
        errorMsg = AppStrings.errorNetwork;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Expanded(child: Text(errorMsg)),
              if (errorStr.contains('user not found') ||
                  errorStr.contains('email not confirmed'))
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    context.push('/register');
                  },
                  child: const Text(
                    'Daftar',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
            ],
          ),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),

                // Back button — pakai pop biar bisa balik ke role select
                GestureDetector(
                  onTap: () => context.pop(),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 32),

                const Text(
                  AppStrings.loginTitle,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  AppStrings.loginSubtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 40),

                // Email field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: AppStrings.email,
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return AppStrings.validEmail;
                    }
                    if (!val.contains('@')) {
                      return AppStrings.validEmailFormat;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: AppStrings.password,
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(
                        () => _obscurePassword = !_obscurePassword,
                      ),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return AppStrings.validPasswordEmpty;
                    }
                    if (val.length < 6) {
                      return AppStrings.validPassword;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Tombol login
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(AppStrings.login),
                ),
                const SizedBox(height: 16),

                // Link ke register
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      AppStrings.noAccount,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    TextButton(
                      onPressed: () => context.push('/register'),
                      child: const Text(
                        AppStrings.registerLink,
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
