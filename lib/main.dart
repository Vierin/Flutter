import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'firebase_options.dart';
import 'l10n/app_locales.dart';
import 'l10n/locale_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'services/auth_service.dart';
import 'services/cache/bookings_cache.dart';
import 'services/cache/salon_cache.dart';
import 'services/cache/services_staff_cache.dart';
import 'services/push_notification_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: 'assets/.env');
  } catch (_) {
    await dotenv.load(fileName: 'assets/.env.example');
  }
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await PushNotificationService.initialize();
  } catch (e) {
    assert(() {
      // ignore: avoid_print
      print('Firebase init skipped: $e');
      return true;
    }());
  }
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => SalonCache()),
        ChangeNotifierProvider(create: (_) => BookingsCache()),
        ChangeNotifierProvider(create: (_) => ServicesStaffCache()),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, locale, _) {
          if (!locale.isLoaded) {
            return MaterialApp(
              title: 'Henzo',
              theme: AppTheme.light,
              home: const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
            );
          }
          return MaterialApp(
            title: 'Henzo',
            theme: AppTheme.light,
            darkTheme: AppTheme.light,
            themeMode: ThemeMode.light,
            locale: Locale(locale.languageTag),
            supportedLocales: supportedLocaleCodes
                .map((code) => Locale(code == 'vi' ? 'vi' : code == 'ru' ? 'ru' : 'en'))
                .toSet()
                .toList(),
            home: const AuthWrapper(),
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, auth, _) {
        if (auth.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (auth.isAuthenticated) {
          return const MainShell();
        }
        return const LoginScreen();
      },
    );
  }
}
