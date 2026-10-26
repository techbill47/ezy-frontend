import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/session_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import 'auth_screen.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

class EntrySplashScreen extends StatefulWidget {
  const EntrySplashScreen({super.key});
  @override
  State<EntrySplashScreen> createState() => _EntrySplashScreenState();
}

class _EntrySplashScreenState extends State<EntrySplashScreen> {
  int _page = 0;
  bool _visible = false;
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) => _runSequence()); }

  Future<void> _runSequence() async {
    if (!mounted) return;
    setState(() => _visible = true);
    await Future<void>.delayed(const Duration(milliseconds: 780));
    if (!mounted) return;
    setState(() => _visible = false);
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (!mounted) return;
    setState(() { _page = 1; _visible = true; });
    await Future<void>.delayed(const Duration(milliseconds: 780));
    if (!mounted) return;
    final session = context.read<SessionService>();
    if (!session.ready) await _waitForSession(session);
    if (!mounted) return;
    final preferences = await SharedPreferences.getInstance();
    final Widget destination;
    if (session.token != null) {
      destination = const HomeScreen();
    } else if (preferences.getBool(OnboardingScreen.completedPreferenceKey) != true) {
      destination = const OnboardingScreen();
    } else {
      destination = const AuthScreen();
    }
    setState(() => _visible = false);
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => destination));
      WidgetsBinding.instance.addPostFrameCallback((_) => NotificationService.instance.openPendingNotification());
    }
  }

  Future<void> _waitForSession(SessionService session) {
    if (session.ready) return Future<void>.value();
    final completer = Completer<void>();
    late VoidCallback listener;
    listener = () {
      if (session.ready && !completer.isCompleted) {
        session.removeListener(listener);
        completer.complete();
      }
    };
    session.addListener(listener);
    return completer.future;
  }

  @override
  Widget build(BuildContext context) => AppScaffold(body: Center(child: AnimatedOpacity(opacity: _visible ? 1 : 0, duration: const Duration(milliseconds: 420), child: _page == 0 ? _ezySplash(context) : _tekconSplash(context))));

  Widget _ezySplash(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [Text('EZY', style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 72, color: AppColors.darkPrimary, letterSpacing: 3)), const SizedBox(height: 10), Text('Smart Bluetooth Attendance', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.darkMuted), textAlign: TextAlign.center)]);
  Widget _tekconSplash(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [Container(width: 150, height: 150, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.darkPrimary.withValues(alpha: .09)), child: const Center(child: CustomPaint(size: Size(118, 118), painter: _TekconHubPainter()))), const SizedBox(height: 22), Text('TEKCON', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, letterSpacing: 8, fontWeight: FontWeight.w700)), const SizedBox(height: 6), Text('Technology Connected', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.darkPrimary, letterSpacing: 1.1))]);
}

class _TekconHubPainter extends CustomPainter {
  const _TekconHubPainter();
  static const _nodes = <Offset>[Offset(.5, .5), Offset(.5, .08), Offset(.88, .28), Offset(.82, .75), Offset(.5, .94), Offset(.16, .74), Offset(.11, .29), Offset(.28, .13), Offset(.77, .12), Offset(.93, .51), Offset(.3, .87), Offset(.08, .53)];
  static const _links = <(int, int)>[(0, 1), (0, 2), (0, 3), (0, 4), (0, 5), (0, 6), (0, 7), (0, 8), (0, 9), (0, 10), (0, 11), (1, 7), (1, 8), (2, 8), (2, 9), (3, 9), (3, 4), (4, 10), (5, 10), (5, 11), (6, 7), (6, 11)];
  @override
  void paint(Canvas canvas, Size size) {
    final points = _nodes.map((point) => Offset(point.dx * size.width, point.dy * size.height)).toList();
    final line = Paint()..color = AppColors.darkPrimary.withValues(alpha: .72)..strokeWidth = 1.7;
    final dot = Paint()..color = AppColors.darkPrimary;
    for (final (a, b) in _links) { canvas.drawLine(points[a], points[b], line); }
    for (var i = 1; i < points.length; i++) { canvas.drawCircle(points[i], i % 3 == 0 ? 4.5 : 3.1, dot); }
    canvas.drawCircle(points[0], 7, dot);
  }
  @override
  bool shouldRepaint(covariant _TekconHubPainter oldDelegate) => false;
}
