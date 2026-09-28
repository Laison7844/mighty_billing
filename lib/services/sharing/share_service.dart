import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/company_settings.dart';
import '../../models/invoice.dart';

class ShareService {
  static String formatShareMessage({
    required Invoice invoice,
    required CompanySettings settings,
    bool isImage = false,
  }) {
    final businessTitle = settings.companyName.toUpperCase() == 'MIGHTY'
        ? 'Mighty Hollow Blocks'
        : settings.companyName;

    final attachmentNote =
        isImage ? 'Invoice bill image attached.' : 'Invoice PDF attached.';

    return '''
$businessTitle

Invoice: ${invoice.invoiceNumber}
Customer: ${invoice.customerNameSnapshot}
Total: ${CurrencyFormatter.format(invoice.total)}
Paid: ${CurrencyFormatter.format(invoice.paidAmount)}
Balance Due: ${CurrencyFormatter.format(invoice.balanceDue)}

$attachmentNote
'''.trim();
  }

  static String getSanitizedFilename(
    Invoice invoice,
    CompanySettings settings, {
    String extension = 'pdf',
  }) {
    final prefix = settings.companyName
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9-]'), '_');
    final numberClean = invoice.invoiceNumber
        .trim()
        .replaceAll('/', '_')
        .replaceAll(RegExp(r'[^a-zA-Z0-9-]'), '_');
    final customerClean = invoice.customerNameSnapshot
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9-]'), '_');
    return '${prefix}_${numberClean}_$customerClean.$extension';
  }

  static Future<File> saveBytesToTempFile({
    required Uint8List bytes,
    required String filename,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<File> savePdfToTempFile({
    required Uint8List pdfBytes,
    required String filename,
  }) async {
    return saveBytesToTempFile(bytes: pdfBytes, filename: filename);
  }

  static Future<void> shareInvoicePdf({
    required Uint8List pdfBytes,
    required Invoice invoice,
    required CompanySettings settings,
  }) async {
    final filename = getSanitizedFilename(invoice, settings, extension: 'pdf');
    final file = await saveBytesToTempFile(bytes: pdfBytes, filename: filename);
    final message = formatShareMessage(
      invoice: invoice,
      settings: settings,
      isImage: false,
    );

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf', name: filename)],
        text: message,
        subject:
            'Invoice ${invoice.invoiceNumber} - ${invoice.customerNameSnapshot}',
      ),
    );
  }

  static Future<void> shareInvoiceImage({
    required Uint8List imageBytes,
    required Invoice invoice,
    required CompanySettings settings,
  }) async {
    final filename = getSanitizedFilename(invoice, settings, extension: 'png');
    final file =
        await saveBytesToTempFile(bytes: imageBytes, filename: filename);
    final message = formatShareMessage(
      invoice: invoice,
      settings: settings,
      isImage: true,
    );

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png', name: filename)],
        text: message,
        subject:
            'Invoice ${invoice.invoiceNumber} - ${invoice.customerNameSnapshot}',
      ),
    );
  }

  static Future<void> printInvoicePdf({
    required Uint8List pdfBytes,
    required String invoiceNumber,
  }) async {
    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: 'Invoice_$invoiceNumber',
    );
  }
}
