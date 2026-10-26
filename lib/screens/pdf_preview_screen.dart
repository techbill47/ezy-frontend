import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

class PdfPreviewScreen extends StatelessWidget {
  const PdfPreviewScreen({super.key, required this.title, required this.buildPdf});
  final String title;
  final Future<List<int>> Function() buildPdf;
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(title)), body: PdfPreview(build: (_) async => Uint8List.fromList(await buildPdf()), canChangeOrientation: false, canChangePageFormat: false, allowPrinting: true, allowSharing: true));
}
