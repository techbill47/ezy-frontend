import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/session_service.dart';
import 'services/queue_service.dart';
import 'screens/entry_splash_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() => runApp(MultiProvider(providers: [ChangeNotifierProvider(create: (_) => SessionService()..load()), ChangeNotifierProvider(create: (_) => QueueService())], child: const EzyApp()));

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
    routes: {'/login': (_) => const AuthScreen(), '/home': (_) => const HomeScreen()},
    home: const EntrySplashScreen(),
  );
}

