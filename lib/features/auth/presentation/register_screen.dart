// lib/features/auth/presentation/register_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_colors_provider.dart';
import '../../../core/widgets/talky_text_field.dart';
import '../../../core/widgets/talky_button.dart';
import '../data/auth_providers.dart';
import '../domain/user_model.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final result = await ApiService.instance.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        nom: _nameController.text.trim(),
      );
      if (mounted) {
        setState(() => _isLoading = false);
        final userData = result['user'] as Map<String, dynamic>?;
        final token = result['token'] as String?;
        if (userData != null && token != null) {
          final user = UserModel.fromJson({
            ...userData,
            'uid': userData['alanyaID']?.toString() ?? '',
          });
          ref.read(authCustomProvider.notifier).setUser(user, token);
        }
        context.go(AppRoutes.home);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.go(AppRoutes.login),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Text(
                  'Créer un compte',
                  style: Theme.of(context).textTheme.displaySmall,
                ).animate().fadeIn().slideY(begin: 0.2, end: 0),
                const SizedBox(height: 8),
                Text(
                  'Rejoignez Talky et commencez à collaborer',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.textSecondary,
                      ),
                ).animate(delay: 50.ms).fadeIn(),
                const SizedBox(height: 40),
                TalkyTextField(
                  controller: _nameController,
                  label: 'Nom complet',
                  hint: 'Chris ETCHOME',
                  prefixIcon: Icons.person_outline,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Nom requis';
                    if (v.length < 2) return 'Nom trop court';
                    return null;
                  },
                ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.2, end: 0),
                const SizedBox(height: 16),
                TalkyTextField(
                  controller: _emailController,
                  label: 'Adresse email',
                  hint: 'etchomechris2000@gmail.com',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Email requis';
                    if (!v.contains('@')) return 'Email invalide';
                    return null;
                  },
                ).animate(delay: 150.ms).fadeIn().slideY(begin: 0.2, end: 0),
                const SizedBox(height: 16),
                TalkyTextField(
                  controller: _passwordController,
                  label: 'Mot de passe',
                  hint: '••••••••',
                  prefixIcon: Icons.lock_outline,
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: colors.textHint,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Mot de passe requis';
                    if (v.length < 6) return 'Minimum 6 caractères';
                    return null;
                  },
                ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.2, end: 0),
                const SizedBox(height: 32),
                TalkyButton(
                  label: 'Créer mon compte',
                  onPressed: _register,
                  isLoading: _isLoading,
                ).animate(delay: 250.ms).fadeIn(),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Déjà un compte ? ',
                      style:
                          TextStyle(color: colors.textSecondary, fontSize: 14),
                    ),
                    GestureDetector(
                      onTap: () => context.go(AppRoutes.login),
                      child: Text(
                        'Se connecter',
                        style: TextStyle(
                          color: colors.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ).animate(delay: 300.ms).fadeIn(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
