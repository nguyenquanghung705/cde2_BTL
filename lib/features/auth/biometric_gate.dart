import 'package:financy_ui/app/services/Local/biometric_settings.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

/// Wraps a subtree behind biometric authentication when the user has opted in.
///
/// Behavior:
/// - Shows nothing behind a lock screen until [LocalAuthentication.authenticate]
///   succeeds.
/// - On app resume after [BiometricSettings.lockIdleAfter] idle, re-locks.
/// - If the user disables biometrics in settings, this widget becomes a no-op.
class BiometricGate extends StatefulWidget {
  final Widget child;
  const BiometricGate({super.key, required this.child});

  @override
  State<BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends State<BiometricGate>
    with WidgetsBindingObserver {
  final _auth = LocalAuthentication();
  bool _unlocked = false;
  bool _prompting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePrompt());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        BiometricSettings.shouldPromptNow()) {
      setState(() => _unlocked = false);
      _maybePrompt();
    }
  }

  Future<void> _maybePrompt() async {
    if (kIsWeb || !BiometricSettings.isEnabled()) {
      setState(() => _unlocked = true);
      return;
    }
    if (!BiometricSettings.shouldPromptNow()) {
      setState(() => _unlocked = true);
      return;
    }
    if (_prompting) return;
    _prompting = true;
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Xác thực để mở Financy',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      if (!mounted) return;
      if (ok) {
        await BiometricSettings.markUnlocked();
        setState(() => _unlocked = true);
      }
    } catch (_) {
      // Fall through — user can retry from the locked screen.
    } finally {
      _prompting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_unlocked || !BiometricSettings.isEnabled() || kIsWeb) {
      return widget.child;
    }
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock, size: 72),
            const SizedBox(height: 16),
            const Text('Ứng dụng đã khóa'),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _maybePrompt,
              icon: const Icon(Icons.fingerprint),
              label: const Text('Mở khóa'),
            ),
          ],
        ),
      ),
    );
  }
}
