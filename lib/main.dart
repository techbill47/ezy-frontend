import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/live_session_screen.dart';
import 'screens/my_attendance_screen.dart';
import 'screens/notification_settings_screen.dart';
import 'services/session_service.dart';
import 'services/queue_service.dart';
import 'services/notification_service.dart';
import 'screens/entry_splash_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  runApp(MultiProvider(providers: [ChangeNotifierProvider(create: (_) => SessionService()..load()), ChangeNotifierProvider(create: (_) => QueueService())], child: const EzyApp()));
}

class EzyApp extends StatefulWidget {
  const EzyApp({super.key});
  @override
  State<EzyApp> createState() => _EzyAppState();
}

class _EzyAppState extends State<EzyApp> {
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) => context.read<QueueService>().initialize(context.read<SessionService>())); }
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'EZY',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: ThemeMode.dark,
    navigatorKey: NotificationService.navigatorKey,
    routes: {
      '/login': (_) => const AuthScreen(),
      '/home': (_) => const HomeScreen(),
      '/settings': (_) => const NotificationSettingsScreen(),
      '/my-attendance': (context) {
        final user = context.read<SessionService>().user;
        return user == null ? const AuthScreen() : MyAttendanceScreen(user: user);
      },
      '/notification-live-session': (context) {
        final args = ModalRoute.of(context)?.settings.arguments;
        final user = context.read<SessionService>().user;
        if (args is Map && args['session'] is Map && args['course'] is Map && user != null) {
          return LiveSessionScreen(session: Map<String, dynamic>.from(args['session'] as Map), course: Map<String, dynamic>.from(args['course'] as Map), user: user, resumed: true);
        }
        return user == null ? const AuthScreen() : const HomeScreen();
      },
    },
    home: const EntrySplashScreen(),
  );
}

