import 'package:flutter/material.dart';

import 'package:bakibondhu/core/strings_bn.dart';
import 'package:bakibondhu/features/auth/login_screen.dart';
import 'package:bakibondhu/features/dashboard/home_screen.dart';
import 'package:bakibondhu/features/onboarding/onboarding_screen.dart';

/// Opening screen (spec §7): a welcome page offering Login, Register, or
/// continue-offline. Login/Register open the auth form; offline goes through the
/// shop-name onboarding. Any successful path lands on Home and is not shown again.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  Future<void> _openAuth(BuildContext context, {required bool register}) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(startInRegister: register),
      ),
    );
    if (ok == true && context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  void _continueOffline(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Text(
                S.appName,
                textAlign: TextAlign.center,
                style: theme.textTheme.displaySmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                S.landingTagline,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _openAuth(context, register: false),
                  child: const Text(S.landingLogin),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: () => _openAuth(context, register: true),
                  child: const Text(S.landingRegister),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _continueOffline(context),
                child: const Text(S.continueOffline),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
