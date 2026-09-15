import 'package:flutter/material.dart';

import 'package:bakibondhu/core/app_scope.dart';
import 'package:bakibondhu/core/bd_geo.dart';
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
  // Location is chosen from cascading dropdowns: pick a zila (district) first,
  // then a thana/upazila within it. Both are optional.
  String? _zila;
  String? _thana;

  late bool _registering = widget.startInRegister;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _business.dispose();
    _password.dispose();
    super.dispose();
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
    try {
      final phone = normalizeBdMobile(_phone.text.trim());
      final result = _registering
          ? await api.register(
              name: _name.text.trim(),
              phone: phone,
              password: _password.text,
              businessName: _business.text.trim(),
              thana: _thana,
              zila: _zila,
            )
          : await api.login(
              identifier: phone,
              password: _password.text,
            );
      await session.save(result);
      // Mark setup complete so the landing screen doesn't reappear; on register,
      // reuse the business name as the shop name for reminder signatures.
      if (_registering && _business.text.trim().isNotEmpty) {
        await settings.setShopName(_business.text.trim());
      }
      await settings.setOnboardingComplete(true);
      if (mounted) Navigator.pop(context, true);
    } on AuthException catch (e) {
      setState(() => _error = '${S.authFailed} (${e.status})');
    } catch (_) {
      setState(() => _error = S.couldNotOpen);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
                  decoration: const InputDecoration(labelText: S.yourNameLabel),
                  validator: (v) => (v == null || v.trim().isEmpty) ? S.nameRequired : null,
                ),
                TextFormField(
                  controller: _business,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: S.businessNameLabel),
                  validator: (v) => (v == null || v.trim().isEmpty) ? S.businessRequired : null,
                ),
              ],
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: S.identifierLabel),
                validator: bdMobileValidator,
              ),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: S.passwordLabel),
                validator: (v) => (v == null || v.length < 6) ? S.passwordShort : null,
              ),
              if (_registering) ...[
                // Zila (district) first; thana/upazila is derived from it.
                DropdownButtonFormField<String>(
                  initialValue: _zila,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: S.zilaLabel),
                  hint: const Text(S.selectZilaHint),
                  items: [
                    for (final z in kBdZilas)
                      DropdownMenuItem(value: z, child: Text(z)),
                  ],
                  onChanged: (v) => setState(() {
                    _zila = v;
                    _thana = null; // reset thana when the district changes
                  }),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _thana,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: S.thanaLabel,
                    // Nudge the user to pick a district first.
                    helperText: _zila == null ? S.selectZilaFirst : null,
                  ),
                  hint: const Text(S.selectThanaHint),
                  items: [
                    for (final t in (kBdThanasByZila[_zila] ?? const <String>[]))
                      DropdownMenuItem(value: t, child: Text(t)),
                  ],
                  // Disabled until a zila is chosen.
                  onChanged: _zila == null ? null : (v) => setState(() => _thana = v),
                ),
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
