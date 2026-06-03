import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

/// Loads DejaVuSans (Regular + Bold) from Flutter assets and returns a
/// [pw.ThemeData] that the PDF builders can use. DejaVuSans covers Latin,
/// Cyrillic, Greek, and most common scripts — good enough for report text.
///
/// Returns null if assets are unavailable (e.g., unit test environment without
/// asset binding), in which case builders fall back to built-in Helvetica.
Future<pw.ThemeData?> loadPdfTheme() async {
  try {
    final ByteData regular =
        await rootBundle.load('assets/fonts/DejaVuSans.ttf');
    final ByteData bold =
        await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf');
    return pw.ThemeData.withFont(
      base: pw.Font.ttf(regular),
      bold: pw.Font.ttf(bold),
      boldItalic: pw.Font.ttf(bold),
    );
  } catch (_) {
    return null;
  }
}
