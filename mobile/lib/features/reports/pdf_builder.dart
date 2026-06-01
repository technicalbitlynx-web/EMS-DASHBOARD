import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/utils/fmt.dart';
import '../../domain/models/report.dart';

/// Builds a native PDF from the summary-json report (replaces the web jsPDF).
Future<Uint8List> buildSummaryPdf(SummaryReport report) async {
  final doc = pw.Document();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Header(
          level: 0,
          child: pw.Text('EMS — Server Room Report',
              style: pw.TextStyle(
                  fontSize: 20, fontWeight: pw.FontWeight.bold)),
        ),
        pw.Text('Generated: ${Fmt.ts(report.generatedAt)}'),
        pw.Text(
            'Period: ${Fmt.ts(report.from)}  →  ${Fmt.ts(report.to)}'),
        pw.SizedBox(height: 16),
        pw.Text('Readings summary',
            style: pw.TextStyle(
                fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        if (report.readingsSummary.isEmpty)
          pw.Text('No readings in range.')
        else
          pw.TableHelper.fromTextArray(
            headers: const ['Sensor', 'Type', 'Min', 'Max', 'Avg', 'Count'],
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerStyle: pw.TextStyle(
                fontSize: 9, fontWeight: pw.FontWeight.bold),
            data: report.readingsSummary
                .map((s) => [
                      s.name ?? s.sensorId,
                      s.sensorType,
                      Fmt.num(s.minVal),
                      Fmt.num(s.maxVal),
                      Fmt.num(s.avgVal),
                      '${s.readingCount ?? 0}',
                    ])
                .toList(),
          ),
        pw.SizedBox(height: 16),
        pw.Text('Alerts summary',
            style: pw.TextStyle(
                fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        if (report.alertsSummary.isEmpty)
          pw.Text('No alerts in range.')
        else
          pw.TableHelper.fromTextArray(
            headers: const ['Severity', 'Count'],
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerStyle: pw.TextStyle(
                fontSize: 9, fontWeight: pw.FontWeight.bold),
            data: report.alertsSummary
                .map((a) => [a.severity, '${a.count}'])
                .toList(),
          ),
      ],
    ),
  );

  return doc.save();
}
