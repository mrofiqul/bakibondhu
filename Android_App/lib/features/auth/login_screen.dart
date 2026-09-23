import 'package:flutter/material.dart';

import 'package:bakibondhu/core/app_scope.dart';
import 'package:bakibondhu/core/bd_geo.dart';
import 'package:bakibondhu/core/countries.dart';
import 'package:bakibondhu/core/language.dart';
import 'package:bakibondhu/core/strings_bn.dart';
import 'package:bakibondhu/core/validators.dart';
import 'package:bakibondhu/data/auth_api.dart';

/// Login / register (spec REST §2). Pops `true` on success. Optional — the app
/// works offline without it; this is only needed to sync with the backend.
class LoginScreen extends StatefulWidget {
  /// Open directly on the registration form (from the landing "Register" button)
  /// instead of the login form.
  final bool startInRegister;
  const LoginScreen({this.startInRegister = false, super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _business = TextEditingController();
  final _password = TextEditingController();

  /// Registration location is country-driven. For Bangladesh we show the
  /// cascading division→district→thana dropdowns; for any other country we show
  /// free-text State/Province + City fields instead.
  String _country = kDefaultCountry;
  String? _bivag;
  String? _zila;
  String? _thana;
  final _state = TextEditingController();
  final _city = TextEditingController();

  late bool _registering = widget.startInRegister;
  bool _busy = false;
  String? _error;

  bool get _isBd => _country == kDefaultCountry;

  @override
  void initState() {
    super.initState();
    // Seed the country from the device region so an owner abroad starts on the
    // right form; the app's startup language default is handled in main.dart.
    final code =
        WidgetsBinding.instance.platformDispatcher.locale.countryCode;
    _country = countryNameForCode(code) ?? kDefaultCountry;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _business.dispose();
    _password.dispose();
    _state.dispose();
    _city.dispose();
    super.dispose();
  }

  /// When the owner picks a country other than Bangladesh, default the app
  /// language to English (a deliberate choice; they can still switch it in
  /// Settings). Picking Bangladesh leaves the current language untouched.
  void _onCountryChanged(String? value) {
    setState(() {
      _country = value ?? kDefaultCountry;
      // Reset whichever set of location fields no longer applies.
      _bivag = null;
      _zila = null;
      _thana = null;
    });
    if (!_isBd && S.lang != AppLang.en) {
      applyLanguage(AppLang.en);
      AppScope.settingsOf(context).setLanguage(codeOfLang(AppLang.en));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final api = AppScope.authApiOf(context);
    final session = AppScope.sessionOf(context);
    final settings = AppScope.settingsOf(context);
    final repo = AppScope.of(context);
    final syncStore = AppScope.syncStoreOf(context);
    final syncEngine = AppScope.syncEngineOf(context);
    try {
      final phone = _isBd
          ? normalizeBdMobile(_phone.text.trim())
          : normalizeIntlMobile(_phone.text.trim());
      // Reuse the two location columns: BD stores thana/zila; other countries
      // store city/state in the same slots, with the country recorded too.
      final locThana = _isBd ? _thana : _nullIfEmpty(_city.text);
      final locZila = _isBd ? _zila : _nullIfEmpty(_state.text);
      final result = _registering
          ? await api.register(
              name: _name.text.trim(),
              phone: phone,
              password: _password.text,
              businessName: _business.text.trim(),
              country: _country,
              thana: locThana,
              zila: locZila,
            )
          : await api.login(
              identifier: phone,
              password: _password.text,
            );

      // Shop isolation on a shared device: if the shop signing in differs from
      // the one whose data is on this device, wipe that data and re-pull the new
      // shop's from the cloud — so an owner only ever sees their own customers.
      // On register we keep any offline-added data (it becomes this new shop's,
      // and is pushed up); only a genuine account switch clears it.
      final prevOwner = await settings.dataOwnerBusinessId();
      final newBiz = result.businessId;
      final switchingAccount = _registering
          ? (prevOwner != null && prevOwner != newBiz)
          : (prevOwner != newBiz);
      if (switchingAccount) {
        await repo.clearAllData();
        await syncStore.reset();
      }
      await session.save(result);
      await settings.setDataOwnerBusinessId(newBiz);
      // Mark setup complete so the landing screen doesn't reappear; on register,
      // reuse the business name as the shop name for reminder signatures.
      if (_registering && _business.text.trim().isNotEmpty) {
        await settings.setShopName(_business.text.trim());
      }
      await settings.setOnboardingComplete(true);
      // Pull this shop's data now so the home list reflects the account right
      // away (especially after a wipe). Best-effort — the Sync Center can retry.
      if (syncEngine != null) {
        try {
          await syncEngine.syncNow();
        } catch (_) {/* offline or failed: user can Sync Now later */}
      }
      if (mounted) Navigator.pop(context, true);
    } on AuthException catch (e) {
      setState(() => _error = '${S.authFailed} (${e.status})');
    } catch (_) {
      setState(() => _error = S.couldNotOpen);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String? _nullIfEmpty(String s) {
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_registering ? S.registerAction : S.logIn)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_registering) ...[
                TextFormField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: S.yourNameLabel),
                  validator: (v) => (v == null || v.trim().isEmpty) ? S.nameRequired : null,
                ),
                TextFormField(
                  controller: _business,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: S.businessNameLabel),
                  validator: (v) => (v == null || v.trim().isEmpty) ? S.businessRequired : null,
                ),
                // Country first — it drives the phone rule and location fields.
                DropdownButtonFormField<String>(
                  initialValue: _country,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: S.countryLabel),
                  items: [
                    for (final c in kCountries)
                      DropdownMenuItem(value: c.name, child: Text(c.name)),
                  ],
                  onChanged: _onCountryChanged,
                ),
              ],
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: S.identifierLabel),
                validator: (_registering && !_isBd)
                    ? intlMobileValidator
                    : bdMobileValidator,
              ),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: InputDecoration(labelText: S.passwordLabel),
                validator: (v) => (v == null || v.length < 6) ? S.passwordShort : null,
              ),
              if (_registering) ...[
                if (_isBd) ...[
                  // Bivag (division) first; zila derives from it, thana from zila.
                  DropdownButtonFormField<String>(
                    initialValue: _bivag,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: S.bivagLabel),
                    hint: Text(S.selectBivagHint),
                    items: [
                      for (final b in kBdBivags)
                        DropdownMenuItem(value: b, child: Text(b)),
                    ],
                    onChanged: (v) => setState(() {
                      _bivag = v;
                      _zila = null; // reset district + thana when division changes
                      _thana = null;
                    }),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _zila,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: S.zilaLabel,
                      helperText: _bivag == null ? S.selectBivagFirst : null,
                    ),
                    hint: Text(S.selectZilaHint),
                    items: [
                      for (final z in (kBdZilasByBivag[_bivag] ?? const <String>[]))
                        DropdownMenuItem(value: z, child: Text(z)),
                    ],
                    onChanged: _bivag == null
                        ? null
                        : (v) => setState(() {
                              _zila = v;
                              _thana = null; // reset thana when district changes
                            }),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _thana,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: S.thanaLabel,
                      helperText: _zila == null ? S.selectZilaFirst : null,
                    ),
                    hint: Text(S.selectThanaHint),
                    items: [
                      for (final t in (kBdThanasByZila[_zila] ?? const <String>[]))
                        DropdownMenuItem(value: t, child: Text(t)),
                    ],
                    onChanged: _zila == null ? null : (v) => setState(() => _thana = v),
                  ),
                ] else ...[
                  // Non-Bangladesh: free-text location (no per-country geo data).
                  TextFormField(
                    controller: _state,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(labelText: S.stateLabel),
                  ),
                  TextFormField(
                    controller: _city,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(labelText: S.cityLabel),
                  ),
                ],
              ],
              const SizedBox(height: 16),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_registering ? S.registerAction : S.logIn),
              ),
              TextButton(
                onPressed: _busy ? null : () => setState(() => _registering = !_registering),
                child: Text(_registering ? S.toggleToLogin : S.toggleToRegister),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
