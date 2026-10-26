import 'package:flutter/material.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({super.key, required this.body, this.appBar, this.floatingActionButton, this.bottomNavigationBar});
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton, bottomNavigationBar;
  @override
  Widget build(BuildContext context) => Scaffold(appBar: appBar, floatingActionButton: floatingActionButton, bottomNavigationBar: bottomNavigationBar, body: Stack(children: [Positioned.fill(child: CustomPaint(painter: _NetworkBackgroundPainter(Theme.of(context).colorScheme.primary))), body]));
}

class _NetworkBackgroundPainter extends CustomPainter {
  const _NetworkBackgroundPainter(this.accent);
  final Color accent;
  static const _points = <Offset>[Offset(.03, .13), Offset(.28, .08), Offset(.52, .19), Offset(.79, .07), Offset(.96, .24), Offset(.14, .39), Offset(.42, .44), Offset(.68, .37), Offset(.91, .51), Offset(.04, .68), Offset(.31, .73), Offset(.59, .65), Offset(.82, .78), Offset(.17, .94), Offset(.48, .88), Offset(.73, .97), Offset(.98, .9)];
  static const _edges = <(int, int)>[(0, 1), (1, 2), (2, 3), (3, 4), (0, 5), (1, 6), (2, 6), (2, 7), (3, 7), (4, 8), (5, 6), (6, 7), (7, 8), (5, 9), (5, 10), (6, 10), (6, 11), (7, 11), (8, 12), (9, 10), (10, 11), (11, 12), (9, 13), (10, 13), (10, 14), (11, 14), (11, 15), (12, 15), (12, 16), (13, 14), (14, 15), (15, 16)];
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()..color = accent.withValues(alpha: .055)..strokeWidth = 1;
    final dotPaint = Paint()..color = accent.withValues(alpha: .13);
    final points = _points.map((point) => Offset(point.dx * size.width, point.dy * size.height)).toList();
    for (final (a, b) in _edges) { canvas.drawLine(points[a], points[b], linePaint); }
    for (final point in points) { canvas.drawCircle(point, 1.6, dotPaint); }
  }
  @override
  bool shouldRepaint(covariant _NetworkBackgroundPainter oldDelegate) => oldDelegate.accent != accent;
}
