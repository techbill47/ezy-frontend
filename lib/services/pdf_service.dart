import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfService {
  static String attendanceFilename(String courseCode, DateTime date) => 'EZY-attendance-${_safe(courseCode)}-${DateFormat('yyyy-MM-dd').format(date)}.pdf';
  static String marksFilename(String courseCode, DateTime date) => 'EZY-marks-${_safe(courseCode)}-${DateFormat('yyyy-MM-dd').format(date)}.pdf';
  static String _safe(String value) => value.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '-');

  static Future<List<int>> attendanceSheet({required String courseCode, required String courseName, required String departmentName, required int year, required DateTime sessionDate, required List<Map<String, dynamic>> students}) async {
    final doc = pw.Document();
    final present = students.where((s) => s['present'] == true).length;
    final absent = students.length - present;
    doc.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.fromLTRB(32, 36, 32, 42), maxPages: 100,
      footer: (context) => pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 9))),
      build: (_) => [
        pw.Text('EZY Attendance Sheet', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Text('$courseCode — $courseName'),
        pw.Text('$departmentName — Year $year'),
        pw.Text('Session: ${DateFormat('yyyy-MM-dd  HH:mm').format(sessionDate.toLocal())}'),
        pw.SizedBox(height: 18),
        pw.TableHelper.fromTextArray(headers: const ['No.', 'Matricule', 'Full name', 'Present/Absent'], data: [for (var i = 0; i < students.length; i++) [i + 1, students[i]['matricule'] ?? '', students[i]['fullName'] ?? '', students[i]['present'] == true ? 'Present' : 'Absent']], headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white), headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800), rowDecoration: const pw.BoxDecoration(color: PdfColors.white), oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100), border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4), cellStyle: const pw.TextStyle(fontSize: 9), cellPadding: const pw.EdgeInsets.all(5), columnWidths: {0: const pw.FixedColumnWidth(28), 1: const pw.FlexColumnWidth(1.5), 2: const pw.FlexColumnWidth(3), 3: const pw.FlexColumnWidth(1.3)}),
        pw.SizedBox(height: 14), pw.Text('Present: $present    Absent: $absent    Total: ${students.length}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      ],
    ));
    return doc.save();
  }

  static Future<List<int>> marksSheet({required String courseCode, required String courseName, required String departmentName, required int year, required int maximum, required int totalSessions, required List<Map<String, dynamic>> students}) async {
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.fromLTRB(28, 36, 28, 42), maxPages: 100,
      footer: (context) => pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 9))),
      build: (_) => [
        pw.Text('EZY Attendance Marks Sheet', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8), pw.Text('$courseCode — $courseName'), pw.Text('$departmentName — Year $year'),
        pw.Text('Maximum: $maximum    Total sessions held: $totalSessions'), pw.SizedBox(height: 18),
        pw.TableHelper.fromTextArray(headers: const ['No.', 'Matricule', 'Full name', 'Attended/Total', '%', 'Marks /max'], data: [for (var i = 0; i < students.length; i++) [i + 1, students[i]['matricule'] ?? '', students[i]['fullName'] ?? '', '${students[i]['attended'] ?? 0}/$totalSessions', '${students[i]['percentage'] ?? 0}', '${students[i]['marks'] ?? 0}']], headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white), headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800), rowDecoration: const pw.BoxDecoration(color: PdfColors.white), oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100), border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4), cellStyle: const pw.TextStyle(fontSize: 8), cellPadding: const pw.EdgeInsets.all(4), columnWidths: {0: const pw.FixedColumnWidth(24), 1: const pw.FlexColumnWidth(1.3), 2: const pw.FlexColumnWidth(2.5), 3: const pw.FlexColumnWidth(1.4), 4: const pw.FlexColumnWidth(0.7), 5: const pw.FlexColumnWidth(1.1)}),
      ],
    ));
    return doc.save();
  }
}
