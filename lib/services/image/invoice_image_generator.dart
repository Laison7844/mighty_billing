import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:printing/printing.dart';
import '../../models/company_settings.dart';
import '../../models/invoice.dart';
import '../pdf/invoice_pdf_generator.dart';

/// Service responsible for rendering high-resolution invoice images (PNG)
/// with a guaranteed 100% solid, opaque white background suitable for sharing
/// via WhatsApp, Telegram, Gmail, Android Gallery, and all external viewers.
class InvoiceImageGenerator {
  /// Default DPI for rendering high-resolution invoice PNG.
  /// 200 DPI yields ~1654 x 2338 px on A4, providing razor-sharp typography,
  /// perfect legibility for WhatsApp previewing and zooming, while keeping performance optimal.
  static const double defaultDpi = 200.0;

  /// Generates a high-quality PNG image representing the complete invoice bill.
  /// Guarantees an explicit solid white background, subtle Mighty watermark,
  /// and identical layout across all platforms and themes.
  static Future<Uint8List> generateInvoiceImage({
    required Invoice invoice,
    required CompanySettings settings,
    Uint8List? prebuiltPdfBytes,
    double dpi = defaultDpi,
  }) async {
    final pdfBytes = prebuiltPdfBytes ??
        await InvoicePdfGenerator.generateInvoicePdf(
          invoice: invoice,
          settings: settings,
        );

    return rasterizePdfToPng(pdfBytes, dpi: dpi);
  }

  /// Converts pre-generated invoice PDF bytes into a high-resolution PNG image.
  /// Composites the rendered page onto an explicit solid white canvas so that
  /// no transparent pixels exist in the final PNG file.
  static Future<Uint8List> rasterizePdfToPng(
    Uint8List pdfBytes, {
    double dpi = defaultDpi,
  }) async {
    await for (final page in Printing.raster(pdfBytes, pages: [0], dpi: dpi)) {
      final ui.Image pageImage = await page.toImage();
      final int width = pageImage.width;
      final int height = pageImage.height;

      // Create an explicit, 100% opaque solid white canvas
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      // 1. Paint 100% solid white across the entire rectangular canvas
      final whitePaint = ui.Paint()
        ..color = const ui.Color(0xFFFFFFFF)
        ..style = ui.PaintingStyle.fill
        ..isAntiAlias = false;

      canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        whitePaint,
      );

      // 2. Draw the rendered invoice document on top of the solid white background
      canvas.drawImage(pageImage, ui.Offset.zero, ui.Paint());

      final picture = recorder.endRecording();
      final finalImage = await picture.toImage(width, height);
      final byteData =
          await finalImage.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('Failed to encode composite invoice to PNG');
      }

      return byteData.buffer.asUint8List();
    }
    throw Exception('Unable to rasterize invoice PDF to image');
  }
}
