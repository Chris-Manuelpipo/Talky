// lib/features/auth/presentation/otp_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors_provider.dart';
import '../../../shared/widgets/talky_button.dart';
import '../data/auth_providers.dart';
//import '../data/auth_service.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String phoneNumber;
  const OtpScreen({super.key, required this.phoneNumber});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  int _remainingSeconds = 60;
  Timer? _timer;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
    // Focus sur le premier champ
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  void _startTimer() {
    _remainingSeconds = 60;
    _canResend = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds == 0) {
        setState(() => _canResend = true);
        timer.cancel();
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  String get _otpCode => _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_otpCode.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entrez le code complet à 6 chiffres')),
      );
      return;
    }

    final success = await ref.read(otpProvider.notifier).verifyOtp(_otpCode);
    if (!mounted) return;

    if (success) {
      // Vérifier si le profil est complet
      final uid = ref.read(authServiceProvider).currentUser?.uid;
      if (uid != null) {
        final isComplete =
            await ref.read(authServiceProvider).isProfileComplete(uid);
        if (mounted) {
          context.go(isComplete ? AppRoutes.home : AppRoutes.profileSetup);
        }
      }
    } else {
      final error = ref.read(otpProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Code incorrect'),
          backgroundColor: AppColors.error,
        ),
      );
      // Vider les champs
      for (final c in _controllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
    }
  }

  Future<void> _resendOtp() async {
    if (!_canResend) return;
    await ref.read(otpProvider.notifier).sendOtp(widget.phoneNumber);
    _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    final otpState = ref.watch(otpProvider);
    final colors = context.appThemeColors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // ── Icône ──────────────────────────────────────────
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: context.accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: context.accentColor.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Icon(AppIcons.verify,
                      color: context.accentColor, size: 30),
                ),
              ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),

              const SizedBox(height: 24),

              Text(
                'Code de vérification',
                style: Theme.of(context).textTheme.displaySmall,
              ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.2, end: 0),

              const SizedBox(height: 8),

              RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                  children: [
                    const TextSpan(text: 'Code envoyé au '),
                    TextSpan(
                      text: widget.phoneNumber,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ).animate(delay: 150.ms).fadeIn(),

              const SizedBox(height: 40),

              // ── 6 champs OTP ───────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                    6,
                    (index) => _OtpBox(
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          onChanged: (value) {
                            if (value.isNotEmpty && index < 5) {
                              _focusNodes[index + 1].requestFocus();
                            }
                            if (value.isEmpty && index > 0) {
                              _focusNodes[index - 1].requestFocus();
                            }
                            // Auto-vérifier quand les 6 chiffres sont saisis
                            if (_otpCode.length == 6) _verify();
                          },
                        )),
              ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.2, end: 0),

              const SizedBox(height: 32),

              // ── Renvoyer le code ───────────────────────────────
              Center(
                child: _canResend
                    ? TextButton.icon(
                        onPressed: _resendOtp,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Renvoyer le code'),
                      )
                    : Text(
                        'Renvoyer dans $_remainingSeconds s',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 14),
                      ),
              ).animate(delay: 250.ms).fadeIn(),

              const Spacer(),

              // ── Bouton vérifier ────────────────────────────────
              TalkyButton(
                label: 'Vérifier',
                onPressed: _verify,
                isLoading: otpState.isLoading,
                icon: Icons.check_circle_outline_rounded,
              ).animate(delay: 300.ms).fadeIn(),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widget champ OTP individuel ────────────────────────────────────────
class _OtpBox extends ConsumerWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Function(String) onChanged;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appThemeColors;
    return SizedBox(
      width: 48,
      height: 58,
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: colors.textPrimary,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: colors.surfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colors.primary, width: 2),
          ),
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: onChanged,
      ),
    );
  }
}
