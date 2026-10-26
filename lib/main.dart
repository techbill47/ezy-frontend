import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/session_service.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';

void main() => runApp(ChangeNotifierProvider(create: (_) => SessionService()..load(), child: const EzyApp()));

class EzyApp extends StatelessWidget {
  const EzyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'EZY',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1E5BD8),
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: Colors.white,
      useMaterial3: true,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {TargetPlatform.android: _NoTransitionsBuilder()}),
    ),
    home: Consumer<SessionService>(builder: (context, session, _) => !session.ready ? const Scaffold(body: Center(child: CircularProgressIndicator())) : session.token != null ? const HomeScreen() : const AuthScreen()),
  );
}

class _NoTransitionsBuilder extends PageTransitionsBuilder {
  const _NoTransitionsBuilder();
  @override
  Widget buildTransitions<T>(Route<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) => child;
}
