import 'package:financy_ui/app/services/Local/biometric_settings.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

class BiometricSettingsScreen extends StatefulWidget {
  const BiometricSettingsScreen({super.key});

  @override
  State<BiometricSettingsScreen> createState() =>
      _BiometricSettingsScreenState();
}

class _BiometricSettingsScreenState extends State<BiometricSettingsScreen> {
  final _auth = LocalAuthentication();
  bool _enabled = false;
  bool _deviceSupports = false;
  List<BiometricType> _available = const [];

  @override
  void initState() {
    super.initState();
    _enabled = BiometricSettings.isEnabled();
    _probe();
  }

  Future<void> _probe() async {
    if (kIsWeb) return;
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final supported = await _auth.isDeviceSupported();
      final list = await _auth.getAvailableBiometrics();
      if (!mounted) return;
      setState(() {
        _deviceSupports = canCheck && supported;
        _available = list;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _deviceSupports = false);
    }
  }

  Future<void> _toggle(bool value) async {
    if (value && _deviceSupports) {
      try {
        final ok = await _auth.authenticate(
          localizedReason: 'Xác thực để bật khóa bảo mật',
          options: const AuthenticationOptions(stickyAuth: true),
        );
        if (!ok) return;
      } catch (_) {
        return;
      }
    }
    await BiometricSettings.setEnabled(value);
    if (value) await BiometricSettings.markUnlocked();
    if (!mounted) return;
    setState(() => _enabled = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: const Text('Khóa sinh trắc học'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Bật khóa ứng dụng'),
            subtitle: Text(
              kIsWeb
                  ? 'Không hỗ trợ trên web'
                  : _deviceSupports
                      ? 'Xác thực bằng vân tay / khuôn mặt khi mở app'
                      : 'Thiết bị chưa cấu hình sinh trắc học',
            ),
            value: _enabled,
            onChanged:
                (kIsWeb || !_deviceSupports) ? null : _toggle,
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Phương thức khả dụng',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          if (_available.isEmpty)
            const Text('Chưa phát hiện vân tay/khuôn mặt đã đăng ký')
          else
            ..._available.map(
              (b) => ListTile(
                leading: Icon(_iconFor(b)),
                title: Text(b.name),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            'App sẽ yêu cầu xác thực lại sau '
            '${BiometricSettings.lockIdleAfter.inMinutes} phút không hoạt động.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  IconData _iconFor(BiometricType t) {
    switch (t) {
      case BiometricType.face:
        return Icons.face;
      case BiometricType.fingerprint:
        return Icons.fingerprint;
      case BiometricType.iris:
        return Icons.remove_red_eye;
      case BiometricType.strong:
      case BiometricType.weak:
        return Icons.shield;
    }
  }
}
