import 'package:flutter/material.dart';

import 'package:bakibondhu/core/app_scope.dart';
import 'package:bakibondhu/core/strings_bn.dart';
import 'package:bakibondhu/features/dashboard/home_screen.dart';

/// First run (spec §7 / FR-7): no signup wall. We ask only for an optional shop
/// name (used in reminder signatures), then go straight to Home.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _shopCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _shopCtrl.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_busy) return;
    setState(() => _busy = true);
    final settings = AppScope.settingsOf(context);
    await settings.setShopName(_shopCtrl.text.trim());
    await settings.setOnboardingComplete(true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(S.appName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(S.welcome,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 24),
              Text(S.onboardSubtitle, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              TextField(
                controller: _shopCtrl,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _start(),
                decoration: const InputDecoration(
                  labelText: S.shopNameLabel,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _start,
                child: const Text(S.getStarted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
