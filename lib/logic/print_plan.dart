import 'dart:math';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/classroom.dart';
import '../models/seating_layout.dart';
import '../theme/app_theme.dart';

/// Erzeugt einen Sitzplan als PDF im **A4-Querformat** und öffnet den
/// System-Druck-/Teilen-Dialog.
Future<void> printSeatingPlan(Classroom classroom) async {
  await Printing.layoutPdf(
    name: 'Sitzplan ${classroom.displayName(0)}',
    format: PdfPageFormat.a4.landscape,
    onLayout: (format) async => _buildPdf(classroom, format),
  );
}

Future<Uint8List> _buildPdf(Classroom c, PdfPageFormat format) async {
  final doc = pw.Document();
  final layout = c.layout;
  final seats = layout.seats;

  final maxX =
      seats.isEmpty ? 0.0 : seats.map((s) => s.x).reduce((a, b) => a > b ? a : b);
  final maxY =
      seats.isEmpty ? 0.0 : seats.map((s) => s.y).reduce((a, b) => a > b ? a : b);
  final cols = maxX + 1;
  final rows = maxY + 1;

  doc.addPage(
    pw.Page(
      pageFormat: format.copyWith(
        marginLeft: 24,
        marginRight: 24,
        marginTop: 20,
        marginBottom: 20,
      ),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  classroom_name(c),
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text('${c.students.length} Schüler',
                    style: const pw.TextStyle(
                        fontSize: 11, color: PdfColors.grey700)),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Expanded(
              child: pw.LayoutBuilder(
                builder: (ctx, constraints) => _planStack(
                  c,
                  constraints!.maxWidth,
                  constraints.maxHeight,
                  cols,
                  rows,
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  return doc.save();
}

String classroom_name(Classroom c) => c.displayName(0);

pw.Widget _planStack(
    Classroom c, double availW, double availH, double cols, double rows) {
  const frame = 34.0; // Rand für Tafel/Fenster/Ausgang-Beschriftung
  final innerW = availW - frame * 2;
  final innerH = availH - frame * 2;

  // rechteckige Tische: Breite ≈ 1,5 × Höhe
  const aspect = 1.5;
  final cellH = min(innerH / rows, innerW / (cols * aspect));
  final cellW = cellH * aspect;
  final planW = cols * cellW;
  final planH = rows * cellH;
  final offsetX = frame + (innerW - planW) / 2;
  final offsetY = frame + (innerH - planH) / 2;

  final children = <pw.Widget>[
    // Raum-Rahmen
    pw.Positioned(
      left: offsetX - frame * 0.6,
      top: offsetY - frame * 0.6,
      child: pw.Container(
        width: planW + frame * 1.2,
        height: planH + frame * 1.2,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400, width: 1),
          borderRadius: pw.BorderRadius.circular(10),
        ),
      ),
    ),
  ];

  // Sitzplätze
  for (final seat in c.layout.seats) {
    final student = c.studentById(seat.studentId);
    final idx = student == null ? 0 : c.students.indexOf(student);
    final color = student == null
        ? PdfColors.grey200
        : PdfColor.fromInt(AppTheme.avatarColor(student.id).toARGB32());
    final txtColor = student == null
        ? PdfColors.grey
        : PdfColor.fromInt(AppTheme.avatarTextColor(student.id).toARGB32());
    children.add(
      pw.Positioned(
        left: offsetX + seat.x * cellW,
        top: offsetY + seat.y * cellH,
        child: pw.Container(
          width: cellW * 0.9,
          height: cellH * 0.82,
          padding: const pw.EdgeInsets.all(2),
          decoration: pw.BoxDecoration(
            color: color,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          alignment: pw.Alignment.center,
          child: pw.Text(
            student?.displayName(idx) ?? '',
            textAlign: pw.TextAlign.center,
            maxLines: 2,
            style: pw.TextStyle(
              color: txtColor,
              fontSize: max(6, cellH * 0.22),
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // Beschriftungen an den Seiten
  children.addAll(_sideLabels(c.layout, availW, availH));

  return pw.SizedBox(
    width: availW,
    height: availH,
    child: pw.Stack(children: children),
  );
}

List<pw.Widget> _sideLabels(SeatingLayout l, double w, double h) {
  String? textFor(RoomSide side) {
    final parts = <String>[];
    if (l.boardSide == side) parts.add('Tafel');
    if (l.windowSide == side) parts.add('Fenster');
    if (l.exitSide == side) parts.add('Ausgang');
    return parts.isEmpty ? null : parts.join('  ·  ');
  }

  pw.Widget chip(String text) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Text(text,
            style: pw.TextStyle(
                fontSize: 9, fontWeight: pw.FontWeight.bold)),
      );

  final widgets = <pw.Widget>[];
  final top = textFor(RoomSide.top);
  final bottom = textFor(RoomSide.bottom);
  final left = textFor(RoomSide.left);
  final right = textFor(RoomSide.right);

  if (top != null) {
    widgets.add(pw.Positioned(
        top: 0, left: 0, right: 0, child: pw.Center(child: chip(top))));
  }
  if (bottom != null) {
    widgets.add(pw.Positioned(
        bottom: 0, left: 0, right: 0, child: pw.Center(child: chip(bottom))));
  }
  if (left != null) {
    widgets.add(pw.Positioned(
      left: 0,
      top: h / 2 - 8,
      child: pw.Transform.rotate(angle: pi / 2, child: chip(left)),
    ));
  }
  if (right != null) {
    widgets.add(pw.Positioned(
      right: 0,
      top: h / 2 - 8,
      child: pw.Transform.rotate(angle: -pi / 2, child: chip(right)),
    ));
  }
  return widgets;
}
