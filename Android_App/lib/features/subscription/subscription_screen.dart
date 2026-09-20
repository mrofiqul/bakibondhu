import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:bakibondhu/core/app_scope.dart';
import 'package:bakibondhu/core/config.dart';
import 'package:bakibondhu/core/strings_bn.dart';

/// Subscription info: the free trial, the monthly price (auto-picked for
/// Bangladesh vs. outside, with a manual toggle), the shop's current status,
/// and how to pay & renew (bKash + WhatsApp/email confirmation). No payment is
/// taken in the app — the owner pays out-of-band and the admin extends expiry.
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  /// True = show the Bangladesh price (৳), false = outside (US$). Seeded from
  /// the device region, then the owner can flip it.
  late bool _inBd;

  @override
  void initState() {
    super.initState();
    final country = WidgetsBinding
            .instance.platformDispatcher.locale.countryCode
            ?.toUpperCase() ??
        '';
    _inBd = country.isEmpty || country == 'BD';
  }

  String get _priceLabel => _inBd
      ? '৳$kPriceBdtPerMonth'
      : '\$$kPriceUsdPerMonth';

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _copyBkash() async {
    await Clipboard.setData(const ClipboardData(text: kBkashNumber));
    if (mounted) _snack(S.copied);
  }

  Future<void> _openWhatsApp() async {
    final uri = Uri.parse(
        'https://wa.me/$kSupportWhatsAppIntl?text=${Uri.encodeComponent(S.subWhatsAppMessage)}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _emailUs() async {
    final uri = Uri(
      scheme: 'mailto',
      path: kSupportEmail,
      query: 'subject=${Uri.encodeComponent(S.subEmailSubject)}',
    );
    await launchUrl(uri);
  }

  /// Days until expiry (negative = expired); null when there's no expiry set
  /// (unlimited / logged out / offline).
  int? _daysLeft() {
    final expiresAt = AppScope.sessionOf(context).expiresAt;
    if (expiresAt == null || expiresAt.isEmpty) return null;
    final exp = DateTime.tryParse(expiresAt);
    if (exp == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return DateTime(exp.year, exp.month, exp.day).difference(today).inDays;
  }

  String? _expiryDate() {
    final expiresAt = AppScope.sessionOf(context).expiresAt;
    if (expiresAt == null || expiresAt.isEmpty) return null;
    final exp = DateTime.tryParse(expiresAt);
    if (exp == null) return null;
    return '${exp.year}-${exp.month.toString().padLeft(2, '0')}-${exp.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final days = _daysLeft();
    final expiryDate = _expiryDate();
    return Scaffold(
      appBar: AppBar(title: Text(S.subscription)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Free trial
          _Card(
            color: scheme.secondaryContainer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.card_giftcard, color: scheme.onSecondaryContainer),
                  const SizedBox(width: 10),
                  Text('${S.subFreeTrial} · ${S.subTrialDays(kTrialDays)}',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: scheme.onSecondaryContainer)),
                ]),
                const SizedBox(height: 8),
                Text(S.subTrialBlurb,
                    style: TextStyle(
                        color: scheme.onSecondaryContainer, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Current status
          if (days != null || expiryDate != null)
            _Card(
              color: scheme.surfaceContainerHighest,
              child: Row(
                children: [
                  Icon(
                    (days != null && days < 0)
                        ? Icons.error_outline
                        : Icons.verified_user_outlined,
                    color: (days != null && days < 0)
                        ? scheme.error
                        : scheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(S.subYourPlan,
                            style: Theme.of(context).textTheme.labelLarge),
                        const SizedBox(height: 2),
                        Text(
                          days == null
                              ? S.subActive
                              : (days < 0
                                  ? S.subExpired
                                  : '${S.subActive} · ${S.subDaysLeft(days)}'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: (days != null && days < 0)
                                ? scheme.error
                                : scheme.onSurface,
                          ),
                        ),
                        if (expiryDate != null)
                          Text(S.subExpiresOn(expiryDate),
                              style: TextStyle(
                                  color: scheme.onSurfaceVariant, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (days != null || expiryDate != null) const SizedBox(height: 12),

          // Pricing (with BD / outside toggle)
          _Card(
            color: scheme.primaryContainer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(S.subPricing,
                    style: TextStyle(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_priceLabel,
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: scheme.onPrimaryContainer,
                        )),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(S.subPerMonth,
                          style: TextStyle(
                              color: scheme.onPrimaryContainer, fontSize: 16)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: true, label: Text(S.subInsideBd)),
                    ButtonSegment(value: false, label: Text(S.subOutsideBd)),
                  ],
                  selected: {_inBd},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _inBd = s.first),
                ),
                const SizedBox(height: 8),
                Text(
                  '${S.subInsideBd}: ৳$kPriceBdtPerMonth${S.subPerMonth}  ·  ${S.subOutsideBd}: \$$kPriceUsdPerMonth${S.subPerMonth}',
                  style: TextStyle(
                      color: scheme.onPrimaryContainer.withValues(alpha: 0.85),
                      fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // How to renew
          _Card(
            color: scheme.surface,
            border: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(S.subHowToRenew,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Text(S.subRenewStep1(_priceLabel),
                    style: const TextStyle(height: 1.4)),
                const SizedBox(height: 8),
                _PayRow(
                  icon: Icons.account_balance_wallet,
                  label: S.subBkash,
                  value: kBkashNumber,
                  actionIcon: Icons.copy,
                  actionTooltip: S.subCopyNumber,
                  onAction: _copyBkash,
                ),
                const SizedBox(height: 14),
                Text(S.subRenewStep2, style: const TextStyle(height: 1.4)),
                const SizedBox(height: 8),
                _PayRow(
                  icon: Icons.chat,
                  label: S.subWhatsApp,
                  value: kSupportWhatsApp,
                  actionIcon: Icons.open_in_new,
                  actionTooltip: S.subOpenWhatsApp,
                  onAction: _openWhatsApp,
                ),
                const SizedBox(height: 10),
                _PayRow(
                  icon: Icons.email_outlined,
                  label: S.subEmail,
                  value: kSupportEmail,
                  actionIcon: Icons.open_in_new,
                  actionTooltip: S.subEmailUs,
                  onAction: _emailUs,
                ),
                const SizedBox(height: 14),
                Text(S.subRenewNote,
                    style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 13,
                        height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final Color color;
  final bool border;
  const _Card({required this.child, required this.color, this.border = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: border
            ? Border.all(color: Theme.of(context).dividerColor)
            : null,
      ),
      child: child,
    );
  }
}

class _PayRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final IconData actionIcon;
  final String actionTooltip;
  final VoidCallback onAction;
  const _PayRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.actionIcon,
    required this.actionTooltip,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(actionIcon),
            tooltip: actionTooltip,
            onPressed: onAction,
          ),
        ],
      ),
    );
  }
}
