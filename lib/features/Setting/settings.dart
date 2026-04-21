// ignore_for_file: deprecated_member_use

import 'package:financy_ui/features/Users/Cubit/userCubit.dart';
import 'package:financy_ui/app/services/Local/settings_service.dart';
import 'package:financy_ui/features/auth/repository/authRepo.dart';
import 'package:financy_ui/features/ai_assistant/view/ai_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:financy_ui/l10n/app_localizations.dart';

class Settings extends StatelessWidget {
  const Settings({super.key});

  // Hàm tiện ích
  String _localText(
    BuildContext context,
    String Function(AppLocalizations) getter,
  ) {
    final appLocal = AppLocalizations.of(context);
    return appLocal != null ? getter(appLocal) : '';
  }

  Future<void> _logout(BuildContext context) async {
    final appLocal = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(appLocal?.logout ?? 'Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(appLocal?.logout ?? 'Đăng xuất'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await Authrepo().logout();
    if (!context.mounted) return;

    // Route back to the login screen and drop every screen in between.
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(appLocal?.loggedOut ?? 'Đã đăng xuất'),
        backgroundColor: theme.primaryColor,
      ),
    );
    await SettingsService.setJustLoggedOut(false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildMenuItem(
              icon: Icons.translate,
              title: _localText(context, (l) => l.language),
              iconColor: theme.primaryColor,
              onTap: () {
                Navigator.pushNamed(context, '/languageSelection');
              },
            ),
            const SizedBox(height: 12),
            _buildMenuItem(
              icon: Icons.people,
              title: _localText(context, (l) => l.manageCategory),
              iconColor: Colors.orange,
              onTap: () {
                Navigator.pushNamed(context, '/manageCategory');
              },
            ),
            const SizedBox(height: 12),
            _buildMenuItem(
              icon: Icons.campaign,
              title: _localText(context, (l) => l.systemTheme),
              iconColor: Colors.red,
              onTap: () {
                Navigator.pushNamed(context, '/interfaceSettings');
              },
            ),
            const SizedBox(height: 12),
            _buildMenuItem(
              icon: Icons.people_alt,
              title: _localText(context, (l) => l.userManagement),
              iconColor: Colors.green,
              onTap: () {
                final isGuest = SettingsService.isGuestLogin();
                if (isGuest) {
                  _showLoginPromptDialog(context);
                } else {
                  Navigator.pushNamed(
                    context,
                    '/profile',
                    arguments: context.read<UserCubit>().currentUser,
                  );
                }
              },
            ),
            const SizedBox(height: 12),
            _buildMenuItem(
              icon: Icons.account_balance_wallet,
              title: _localText(context, (l) => l.account),
              iconColor: Colors.teal,
              onTap: () {
                Navigator.pushNamed(context, '/manageAccount');
              },
            ),
            const SizedBox(height: 12),
            _buildMenuItem(
              icon: Icons.pie_chart,
              title: 'Ngân sách',
              iconColor: Colors.purple,
              onTap: () {
                Navigator.pushNamed(context, '/budget');
              },
            ),
            const SizedBox(height: 12),
            _buildMenuItem(
              icon: Icons.swap_horiz,
              title: 'Chuyển khoản giữa ví',
              iconColor: Colors.indigo,
              onTap: () {
                Navigator.pushNamed(context, '/transfer');
              },
            ),
            const SizedBox(height: 12),
            _buildMenuItem(
              icon: Icons.event_repeat,
              title: 'Giao dịch định kỳ',
              iconColor: Colors.deepPurple,
              onTap: () {
                Navigator.pushNamed(context, '/recurring');
              },
            ),
            const SizedBox(height: 12),
            _buildMenuItem(
              icon: Icons.file_download,
              title: 'Xuất CSV',
              iconColor: Colors.brown,
              onTap: () {
                Navigator.pushNamed(context, '/export');
              },
            ),
            const SizedBox(height: 12),
            _buildMenuItem(
              icon: Icons.fingerprint,
              title: 'Khóa sinh trắc học',
              iconColor: Colors.pink,
              onTap: () {
                Navigator.pushNamed(context, '/biometric');
              },
            ),
            const SizedBox(height: 12),
            _buildMenuItem(
              icon: Icons.savings,
              title: 'Mục tiêu tiết kiệm',
              iconColor: Colors.amber,
              onTap: () {
                Navigator.pushNamed(context, '/goals');
              },
            ),
            const SizedBox(height: 12),
            _buildMenuItem(
              icon: Icons.currency_exchange,
              title: 'Tỷ giá & Tiền tệ',
              iconColor: Colors.cyan,
              onTap: () {
                Navigator.pushNamed(context, '/currency');
              },
            ),
            const SizedBox(height: 12),
            _buildMenuItem(
              icon: Icons.document_scanner,
              title: 'Quét hóa đơn (OCR)',
              iconColor: Colors.blueGrey,
              onTap: () {
                Navigator.pushNamed(context, '/ocr');
              },
            ),
            const SizedBox(height: 12),
            _buildMenuItem(
              icon: Icons.history,
              title: 'Nhật ký hoạt động',
              iconColor: Colors.grey,
              onTap: () {
                Navigator.pushNamed(context, '/activityLog');
              },
            ),
            const SizedBox(height: 12),
            _buildMenuItem(
              icon: Icons.notifications,
              title: _localText(context, (l) => l.notification),
              iconColor: Colors.orange,
              hasNotification: true,
              onTap: () {
                Navigator.pushNamed(context, '/notificationSettings');
              },
            ),
            const SizedBox(height: 12),
            _buildMenuItem(
              icon: Icons.sync,
              title: _localText(context, (l) => l.dataSync),
              iconColor: Colors.blue,
              onTap: () {
                Navigator.pushNamed(context, '/dataSync');
              },
            ),
            const SizedBox(height: 12),
            _buildMenuItem(
              icon: Icons.smart_toy,
              title: 'AI Settings',
              iconColor: Colors.deepPurple,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildMenuItem(
              icon: Icons.logout,
              title: _localText(context, (l) => l.logout),
              iconColor: Colors.red,
              onTap: () => _logout(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showLoginPromptDialog(BuildContext context) {
    final appLocal = AppLocalizations.of(context);
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_person,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                appLocal?.signInRequired ?? 'Sign In Required',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                appLocal?.signInToManageProfile ??
                    'Sign in with Google to manage your profile and sync data across devices.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.hintColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: theme.dividerColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        appLocal?.cancel ?? 'Cancel',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: theme.hintColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        Navigator.pushNamed(context, '/dataSyncScreen');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        appLocal?.signIn ?? 'Sign In',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required Color iconColor,
    bool hasNotification = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
