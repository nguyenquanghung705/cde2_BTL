// ignore_for_file: must_be_immutable
import 'package:financy_ui/app/cubit/themeCubit.dart';
import 'package:financy_ui/app/services/Local/notifications.dart';
import 'package:financy_ui/features/Account/models/money_source.dart';
import 'package:financy_ui/features/Account/screen/account_detail_screen.dart';
import 'package:financy_ui/features/Account/screen/add_money_source.dart';
import 'package:financy_ui/features/Account/screen/manageAccount.dart';
import 'package:financy_ui/features/Categories/cubit/CategoriesCubit.dart';
import 'package:financy_ui/features/Categories/models/categoriesModels.dart';
import 'package:financy_ui/features/Categories/view/edit_categories.dart';
import 'package:financy_ui/features/Sync/view/dataSyncScreen.dart';

import 'package:financy_ui/features/Users/Views/profile.dart';
import 'package:financy_ui/features/transactions/Cubit/transactionCubit.dart';
import 'package:financy_ui/features/transactions/view/add.dart';
import 'package:financy_ui/features/auth/cubits/authCubit.dart';
import 'package:financy_ui/features/Account/cubit/manageMoneyCubit.dart';
import 'package:financy_ui/features/Users/Cubit/userCubit.dart';
import 'package:financy_ui/features/Users/models/userModels.dart';
// ignore: unused_import
import 'package:financy_ui/features/transactions/models/transactionsModels.dart';
import 'package:financy_ui/features/notification/cubit/notificationCubit.dart';
import 'package:financy_ui/features/notification/models/notificationModel.dart';
import 'package:financy_ui/features/Budget/cubit/budget_cubit.dart';
import 'package:financy_ui/features/Budget/view/budget_screen.dart';
import 'package:financy_ui/features/Transfer/cubit/transfer_cubit.dart';
import 'package:financy_ui/features/Transfer/view/transfer_screen.dart';
import 'package:financy_ui/app/services/Local/transfers_db.dart';
import 'package:financy_ui/app/services/Local/recurring_db.dart';
import 'package:financy_ui/features/Recurring/cubit/recurring_cubit.dart';
import 'package:financy_ui/features/Recurring/view/recurring_screen.dart';
import 'package:financy_ui/app/services/Local/export_history_db.dart';
import 'package:financy_ui/features/Export/view/export_screen.dart';
import 'package:financy_ui/features/auth/biometric_gate.dart';
import 'package:financy_ui/features/Setting/biometric_settings_screen.dart';
import 'package:financy_ui/app/services/Local/savings_goals_db.dart';
import 'package:financy_ui/features/Goals/cubit/goals_cubit.dart';
import 'package:financy_ui/features/Goals/view/goals_screen.dart';
import 'package:financy_ui/app/services/Local/exchange_rates_db.dart';
import 'package:financy_ui/features/Currency/view/currency_screen.dart';
import 'package:financy_ui/features/Ocr/view/ocr_screen.dart';
import 'package:financy_ui/app/services/Local/activity_log_db.dart';
import 'package:financy_ui/app/services/Local/activity_logger.dart';
import 'package:financy_ui/features/Setting/activity_log_screen.dart';
import 'package:financy_ui/features/ai_assistant/cubit/ai_settings_cubit.dart';
import 'package:financy_ui/features/ai_assistant/models/AI_settings.dart';
import 'package:financy_ui/firebase_options.dart';
import 'package:financy_ui/features/Setting/interfaceSettings.dart';
import 'package:financy_ui/l10n/l10n.dart';
import 'package:financy_ui/features/Setting/languageSettings.dart';
import 'package:financy_ui/features/Categories/view/man_Categories_spend.dart';
import 'package:financy_ui/myApp.dart';
import 'package:financy_ui/features/notification/view/notificationSetting.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:financy_ui/app/services/Local/budget_db.dart';
import 'package:financy_ui/app/services/Local/sync_history_db.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'features/auth/views/login.dart';
import 'features/auth/views/emailLogin.dart';
import 'features/auth/views/register.dart';
import 'app/theme/app_theme.dart';
import 'core/constants/colors.dart';
import 'package:financy_ui/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:financy_ui/app/services/Local/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // initialize notification

  if (!kIsWeb) {
    NotiService().initNotification();
    await NotiService().requestNotificationPermission();
  }
  if (kIsWeb) {
    await Hive.initFlutter();
  } else {
    final appDocDir = await getApplicationDocumentsDirectory();
    Hive.init(appDocDir.path);
  }

  // Register Hive adapters
  Hive.registerAdapter(UserModelAdapter());
  Hive.registerAdapter(MoneySourceAdapter());
  Hive.registerAdapter(CurrencyTypeAdapter());
  Hive.registerAdapter(TypeMoneyAdapter());
  Hive.registerAdapter(TransactionTypeAdapter());
  Hive.registerAdapter(TransactionsmodelsAdapter());
  Hive.registerAdapter(CategoryAdapter());
  Hive.registerAdapter(NotificationModelAdapter());
  Hive.registerAdapter(AiSettingsAdapter());

  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {
    // .env missing — fall back to default baseUrl below.
  }
  await Hive.openBox('settings');
  await Hive.openBox('jwt');
  await Hive.openBox('authCredentials');
  await Hive.openBox('accountNumbers');
  await BudgetDb.instance.init();
  await SyncHistoryDb.instance.init();
  await TransfersDb.instance.init();
  await RecurringDb.instance.init();
  await ExportHistoryDb.instance.init();
  await SavingsGoalsDb.instance.init();
  await ExchangeRatesDb.instance.init();
  await ActivityLogDb.instance.init();
  await ActivityLogger.log('app_start');

  // Store baseUrl for isolate access
  final baseUrl = dotenv.env['URL_DB'] ?? 'http://10.0.2.2:2310/api';
  await Hive.box('settings').put('baseUrl', baseUrl);

  // Initialize local storage for MoneySource
  await Hive.openBox<MoneySource>('moneySourceBox');
  await Hive.openBox<UserModel>('userBox');
  await Hive.openBox<Category>('categoryBox');
  await Hive.openBox<Transactionsmodels>('transactionsBox');
  await Hive.openBox<NotificationModel>('notificationSettings');
  await Hive.openBox<AiSettings>('aiSettingsBox');

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Firebase not configured (stub options) — email/password login (local)
    // still works. Run `flutterfire configure` to enable Google Sign-In.
  }
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await NotiService().scheduleDailyNotifications(
          title:
              AppLocalizations.of(context)?.titleNotification ?? 'Thông báo',
          body:
              AppLocalizations.of(context)?.bodyNotification ??
              'Hôm nay bạn đã chi tiêu bao nhiêu?',
        );
        await NotiService().saveNotificationSettings();
      });
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ThemeCubit()),
        BlocProvider(create: (_) => Authcubit()),
        BlocProvider(create: (_) => ManageMoneyCubit()),
        BlocProvider(create: (_) => UserCubit()),
        BlocProvider(create: (_) => TransactionCubit()),
        BlocProvider(create: (_) => Categoriescubit()),
        BlocProvider(create: (_) => NotificationCubit()),
        BlocProvider(create: (_) => AiSettingsCubit()..loadSettings()),
        BlocProvider(create: (_) => BudgetCubit()),
        BlocProvider(create: (_) => TransferCubit()),
        BlocProvider(create: (_) => RecurringCubit()..runNow()),
        BlocProvider(create: (_) => GoalsCubit()),
      ],
      child: BlocBuilder<ThemeCubit, ThemeState>(
        builder: (context, state) {
          return MaterialApp(
            navigatorObservers: [ActivityNavigatorObserver()],
            builder: (context, child) =>
                BiometricGate(child: child ?? const SizedBox.shrink()),
            title: 'Expense Tracker',
            supportedLocales: L10n.all,
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],

            /// 👇 Always fallback to Vietnamese if locale doesn't match
            localeResolutionCallback: (locale, supportedLocales) {
              for (var supportedLocale in supportedLocales) {
                if (supportedLocale.languageCode == locale?.languageCode) {
                  return supportedLocale;
                }
              }
              return const Locale('vi'); // default fallback
            },
            locale: state.lang,
            theme: AppTheme.lightTheme(
              primaryColor: state.color ?? Colors.blue,
              backgroundColor: AppColors.backgroundLight,
              selectedItemColor: state.color ?? Colors.blue,
              fontFamily: state.fontFamily ?? 'Roboto',
              fontSize: state.fontSize ?? 14.0,
            ),
            darkTheme: AppTheme.darkTheme(
              primaryColor: state.color ?? Colors.blue,
              backgroundColor: AppColors.backgroundDark,
              selectedItemColor: state.color ?? Colors.blue,
              fontFamily: state.fontFamily ?? 'Roboto',
              fontSize: state.fontSize ?? 14.0,
            ),
            themeMode: state.themeMode,
            initialRoute: '/',
            routes: {
              '/': (context) => const MainApp(),
              '/addMoneySource': (context) => const AddMoneySourceScreen(),
              '/add': (context) => const AddTransactionScreen(),
              '/login': (context) => Login(),
              '/emailLogin': (context) => const EmailLogin(),
              '/register': (context) => const Register(),
              '/expenseTracker': (context) => ExpenseTrackerScreen(),
              '/manageAccount': (context) => AccountMoneyScreen(),
              '/interfaceSettings': (context) => InterfaceSettings(),
              '/manageCategory': (context) => ExpenseCategoriesScreen(),
              '/languageSelection': (context) => LanguageSelectionScreen(),
              '/editCategory': (context) => AddEditCategoryScreen(),
              '/notificationSettings':
                  (context) => NotificationSettingsScreen(),
              '/dataSync': (context) => DataSyncScreen(),
              '/budget': (context) => const BudgetScreen(),
              '/transfer': (context) => const TransferScreen(),
              '/recurring': (context) => const RecurringScreen(),
              '/export': (context) => const ExportScreen(),
              '/biometric': (context) => const BiometricSettingsScreen(),
              '/goals': (context) => const GoalsScreen(),
              '/currency': (context) => const CurrencyScreen(),
              '/ocr': (context) => const OcrScreen(),
              '/activityLog': (context) => const ActivityLogScreen(),

              // Add other routes here
            },
            onGenerateRoute: (settings) {
              if (settings.name == '/accountDetail') {
                final args = settings.arguments as MoneySource?;
                return MaterialPageRoute(
                  builder: (context) => AccountDetailScreen(account: args),
                );
              }
              if (settings.name == '/profile') {
                final args = settings.arguments as UserModel?;
                return MaterialPageRoute(
                  builder: (context) => UserProfileScreen(user: args),
                );
              }
              return null; // Return null if no matching route found
            },
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}

// MainApp to route

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late bool appState;
  @override
  void initState() {
    appState = SettingsService.getAppState();
    // Show one-time logout snackbar if applicable
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (SettingsService.getJustLoggedOut()) {
        final ctx = context;
        final appLocal = AppLocalizations.of(ctx);
        final theme = Theme.of(ctx);
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(appLocal?.loggedOut ?? 'Logged out'),
            backgroundColor: theme.primaryColor,
          ),
        );
        await SettingsService.setJustLoggedOut(false);
      }
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return !appState ? Login() : ExpenseTrackerScreen();
  }
}
