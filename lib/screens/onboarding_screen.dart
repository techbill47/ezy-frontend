import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/buttons.dart';
import 'auth_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  static const completedPreferenceKey = 'ezy_onboarding_completed';
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  bool _saving = false;
  static const _pages = <(String, String)>[
    ('Mark attendance by proximity', 'Be in the room. Your phone finds the session signal for your class.'),
    ('Works offline, syncs later', 'Attendance marks stay on your phone and sync when your connection returns.'),
    ('Your proof of attendance', 'A session code records your presence for the right class and time.'),
  ];
  Future<void> _finish({required bool register}) async {
    if (_saving) return;
    setState(() => _saving = true);
    await (await SharedPreferences.getInstance()).setBool(OnboardingScreen.completedPreferenceKey, true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => AuthScreen(startAtRegistration: register)));
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AppScaffold(body: SafeArea(child: Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 0), child: Row(children: [Text('EZY', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.darkPrimary, letterSpacing: 2)), const Spacer(), TextButton(onPressed: _saving ? null : () => _finish(register: false), child: const Text('Skip'))])),
    Expanded(child: PageView.builder(controller: _controller, itemCount: _pages.length, onPageChanged: (index) => setState(() => _page = index), itemBuilder: (context, index) => _OnboardingPage(index: index, title: _pages[index].$1, description: _pages[index].$2))),
    Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (var i = 0; i < _pages.length; i++) Container(width: i == _page ? 24 : 8, height: 8, margin: const EdgeInsets.symmetric(horizontal: 4), decoration: BoxDecoration(color: i == _page ? AppColors.darkPrimary : AppColors.darkMuted.withValues(alpha: .35), borderRadius: BorderRadius.circular(8)))])),
    if (_page == 2) Padding(padding: const EdgeInsets.fromLTRB(24, 8, 24, 28), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [PrimaryButton(label: 'Get Started', loading: _saving, onPressed: _saving ? null : () => _finish(register: true)), const SizedBox(height: 10), SecondaryButton(label: 'Sign in to your account', onPressed: _saving ? null : () => _finish(register: false))])) else const SizedBox(height: 22),
  ])));
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.index, required this.title, required this.description});
  final int index;
  final String title, description;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(horizontal: 30), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CustomPaint(size: const Size(216, 200), painter: _OnboardingIllustration(index)), const SizedBox(height: 30), Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 12), Text(description, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.darkMuted))]));
}

class _OnboardingIllustration extends CustomPainter {
  const _OnboardingIllustration(this.index);
  final int index;
  @override
  void paint(Canvas canvas, Size size) {
    final green = Paint()..color = AppColors.darkPrimary..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round;
    final soft = Paint()..color = AppColors.darkPrimary.withValues(alpha: .13);
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, 82, soft);
    if (index == 0) {
      final phone = RRect.fromRectAndRadius(Rect.fromCenter(center: center, width: 64, height: 112), const Radius.circular(12));
      canvas.drawRRect(phone, green);
      canvas.drawLine(Offset(center.dx - 13, center.dy + 41), Offset(center.dx + 13, center.dy + 41), green);
      for (final radius in [30.0, 48.0]) { final path = Path()..addArc(Rect.fromCircle(center: Offset(center.dx + 56, center.dy), radius: radius), -.9, 1.8); canvas.drawPath(path, green); }
      canvas.drawCircle(Offset(center.dx + 67, center.dy), 5, Paint()..color = AppColors.darkPrimary);
    } else if (index == 1) {
      final cloud = Path()..moveTo(center.dx - 55, center.dy + 15)..cubicTo(center.dx - 72, center.dy + 15, center.dx - 72, center.dy - 12, center.dx - 54, center.dy - 18)..cubicTo(center.dx - 49, center.dy - 49, center.dx - 5, center.dy - 54, center.dx + 8, center.dy - 27)..cubicTo(center.dx + 42, center.dy - 47, center.dx + 70, center.dy - 24, center.dx + 59, center.dy + 2)..cubicTo(center.dx + 82, center.dy + 8, center.dx + 69, center.dy + 33, center.dx + 49, center.dy + 32)..lineTo(center.dx - 49, center.dy + 32)..close();
      canvas.drawPath(cloud, green);
      final check = Path()..moveTo(center.dx - 18, center.dy + 5)..lineTo(center.dx - 4, center.dy + 19)..lineTo(center.dx + 25, center.dy - 13);
      canvas.drawPath(check, green..strokeWidth = 5);
      canvas.drawLine(Offset(center.dx, center.dy + 37), Offset(center.dx, center.dy + 62), green);
      canvas.drawLine(Offset(center.dx - 28, center.dy + 62), Offset(center.dx + 28, center.dy + 62), green);
    } else {
      final ticket = RRect.fromRectAndRadius(Rect.fromCenter(center: center, width: 126, height: 82), const Radius.circular(14));
      canvas.drawRRect(ticket, green);
      canvas.drawCircle(Offset(center.dx - 27, center.dy), 15, green);
      final check = Path()..moveTo(center.dx - 34, center.dy)..lineTo(center.dx - 28, center.dy + 6)..lineTo(center.dx - 18, center.dy - 7);
      canvas.drawPath(check, green..strokeWidth = 3);
      canvas.drawLine(Offset(center.dx + 1, center.dy - 12), Offset(center.dx + 43, center.dy - 12), green);
      canvas.drawLine(Offset(center.dx + 1, center.dy + 1), Offset(center.dx + 35, center.dy + 1), green);
      canvas.drawLine(Offset(center.dx + 1, center.dy + 14), Offset(center.dx + 27, center.dy + 14), green);
    }
  }
  @override
  bool shouldRepaint(covariant _OnboardingIllustration oldDelegate) => oldDelegate.index != index;
}
