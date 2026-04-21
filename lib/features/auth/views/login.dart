// ignore_for_file: use_build_context_synchronously

import 'package:financy_ui/app/services/Local/activity_logger.dart';
import 'package:financy_ui/features/auth/cubits/authCubit.dart';
import 'package:financy_ui/features/auth/views/nameInputDialog.dart';
import 'package:financy_ui/features/auth/cubits/authState.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:financy_ui/l10n/app_localizations.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  String? savedName;
  int? savedDay;
  int? savedMonth;
  int? savedYear;

  Future<void> _showInputDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => InputDialog(),
    );
  }

  void loginNoAccount() async {
    await ActivityLogger.log('login_guest_open');
    await _showInputDialog();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appLocal = AppLocalizations.of(context);
    return BlocListener<Authcubit, Authstate>(
      listener: (context, state) {
        // Avoid double navigation when a dialog (e.g., guest flow) is open
        if (Navigator.of(context).canPop()) {
          return;
        }
        if (state.authStatus == AuthStatus.authenticated) {
          ActivityLogger.log('login_success');
          Navigator.pushReplacementNamed(context, '/');
        } else if (state.authStatus == AuthStatus.error) {
          final message = state.errorMessage ?? 'Authentication failed';
          ActivityLogger.log('login_error', data: {'message': message});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: theme.primaryColor,
            ),
          );
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final dpr = MediaQuery.of(context).devicePixelRatio;
              final shortSide = constraints.maxWidth < constraints.maxHeight
                  ? constraints.maxWidth
                  : constraints.maxHeight;
              final logoSize = (shortSide * 0.35).clamp(120.0, 220.0);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 40,
                      maxWidth: 440,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 24),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.asset(
                              'assets/icon/rounded-in-photoretrica.png',
                              width: logoSize,
                              height: logoSize,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.high,
                              cacheWidth: (logoSize * dpr * 2).round(),
                              cacheHeight: (logoSize * dpr * 2).round(),
                            ),
                          ),
              const SizedBox(height: 20),
              Text(
                appLocal?.hello ?? 'Hello',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 44,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  appLocal?.loginToAccess ?? 'Login to access',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/emailLogin'),
                  icon: const Icon(Icons.email_outlined),
                  label: Text(
                    'Đăng nhập bằng Email',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    side: BorderSide(
                      color: theme.colorScheme.secondary,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: loginNoAccount,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    side: BorderSide(
                      color: theme.colorScheme.secondary,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        appLocal?.continue_without_account ??
                            'Continue without account',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Chưa có tài khoản? ',
                    style: TextStyle(color: Colors.grey),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/register'),
                    child: Text(
                      'Đăng ký ngay',
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  appLocal?.agree_terms ??
                      'I agree to the terms and conditions',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
