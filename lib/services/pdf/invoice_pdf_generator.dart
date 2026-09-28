import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/company_settings.dart';
import '../../models/invoice.dart';

class InvoicePdfGenerator {
  static Future<Uint8List> generateInvoicePdf({
    required Invoice invoice,
    required CompanySettings settings,
  }) async {
    final pdf = pw.Document();

    // Load fonts safely with fallback for offline mode
    pw.Font fontRegular;
    pw.Font fontBold;
    bool isUnicode = true;
    try {
      fontRegular = await PdfGoogleFonts.interRegular();
      fontBold = await PdfGoogleFonts.interBold();
      if (fontRegular.fontName.toLowerCase().contains('helvetica')) {
        isUnicode = false;
      }
    } catch (_) {
      fontRegular = pw.Font.helvetica();
      fontBold = pw.Font.helveticaBold();
      isUnicode = false;
    }

    String fmtMoney(double amount) {
      final numStr = CurrencyFormatter.formatNumber(amount);
      return isUnicode ? '₹$numStr' : 'Rs. $numStr';
    }

    // Load logo image
    Uint8List? logoBytes;
    try {
      if (settings.customLogoPath != null &&
          settings.customLogoPath!.isNotEmpty &&
          File(settings.customLogoPath!).existsSync()) {
        logoBytes = await File(settings.customLogoPath!).readAsBytes();
      } else {
        final byteData = await rootBundle.load(AppConstants.defaultLogoAsset);
        logoBytes = byteData.buffer.asUint8List();
      }
    } catch (e) {
      logoBytes = null;
    }

    final pw.MemoryImage? logoImage = logoBytes != null ? pw.MemoryImage(logoBytes) : null;

    final theme = pw.ThemeData.withFont(
      base: fontRegular,
      bold: fontBold,
    );

    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      theme: theme,
      buildBackground: (pw.Context context) {
        return pw.FullPage(
          ignoreMargins: true,
          child: pw.Container(color: PdfColors.white),
        );
      },
    );

    pdf.addPage(
      pw.Page(
        pageTheme: pageTheme,
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              // 1. Explicit Solid White Background Layer
              pw.Positioned.fill(
                child: pw.Container(color: PdfColors.white),
              ),

              // 2. Watermark in the background (0.08 opacity for clear visibility on white)
              if (logoImage != null)
                pw.Positioned.fill(
                  child: pw.Center(
                    child: pw.Opacity(
                      opacity: 0.08,
                      child: pw.Image(logoImage, width: 340, height: 340),
                    ),
                  ),
                ),

              // 2. Invoice content
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  // Header section
                  _buildHeader(settings, logoImage),
                  pw.SizedBox(height: 12),

                  // Bill To and Bill Meta
                  _buildBillingInfo(invoice),
                  pw.SizedBox(height: 14),

                  // Items & Charges Table
                  _buildItemsTable(invoice, isUnicode, fmtMoney),
                  pw.SizedBox(height: 12),

                  // Summary / Total Section
                  _buildSummarySection(invoice, fmtMoney),
                  pw.Spacer(),

                  // Terms & Signature Footer
                  _buildFooter(invoice, settings),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(CompanySettings settings, pw.MemoryImage? logoImage) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 1.5)),
      ),
      child: pw.Column(
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              if (logoImage != null)
                pw.Container(
                  width: 58,
                  height: 58,
                  child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                )
              else
                pw.Container(
                  width: 50,
                  height: 50,
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#1E293B'),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    'M',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      settings.companyName.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#0F172A'),
                        letterSpacing: 1.5,
                      ),
                    ),
                    if (settings.companySubtitle.isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        settings.companySubtitle.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#D97706'),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                    pw.SizedBox(height: 4),
                    if (settings.address.isNotEmpty)
                      pw.Text(
                        settings.address,
                        style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
                        textAlign: pw.TextAlign.center,
                      ),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        if (settings.phone.isNotEmpty)
                          pw.Text(
                            'Mobile: ${settings.phone}',
                            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E293B')),
                          ),
                        if (settings.gstNumber.isNotEmpty) ...[
                          pw.Text('  |  ', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
                          pw.Text(
                            'GSTIN: ${settings.gstNumber}',
                            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 58), // Balance logo on right
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 3),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#1E293B'),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              'CASH BILL / TAX INVOICE',
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildBillingInfo(Invoice invoice) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F8FAFC'),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          // Customer details
          pw.Expanded(
            flex: 6,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'BILL TO:',
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  invoice.customerNameSnapshot,
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#0F172A'),
                  ),
                ),
                if (invoice.customerPhoneSnapshot.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Phone: ${invoice.customerPhoneSnapshot}',
                    style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey800),
                  ),
                ],
                if (invoice.customerAddressSnapshot.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    invoice.customerAddressSnapshot,
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                  ),
                ],
                if (invoice.customerGstNumberSnapshot != null &&
                    invoice.customerGstNumberSnapshot!.trim().isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'GSTIN: ${invoice.customerGstNumberSnapshot}',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#0F172A'),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Invoice metadata
          pw.Expanded(
            flex: 4,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Text('BILL NO:  ', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
                    pw.Text(
                      invoice.invoiceNumber,
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A')),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Text('DATE:  ', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
                    pw.Text(
                      DateFormatter.formatInvoiceDate(invoice.date),
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A')),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Text('STATUS:  ', style: pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600)),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: pw.BoxDecoration(
                        color: invoice.paymentStatus == PaymentStatus.paid
                            ? PdfColor.fromHex('#ECFDF5')
                            : (invoice.paymentStatus == PaymentStatus.partiallyPaid
                                ? PdfColor.fromHex('#FFFBEB')
                                : PdfColor.fromHex('#FEF2F2')),
                        borderRadius: pw.BorderRadius.circular(4),
                        border: pw.Border.all(
                          color: invoice.paymentStatus == PaymentStatus.paid
                              ? PdfColors.green300
                              : (invoice.paymentStatus == PaymentStatus.partiallyPaid
                                  ? PdfColors.amber300
                                  : PdfColors.red300),
                        ),
                      ),
                      child: pw.Text(
                        invoice.paymentStatus.label,
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: invoice.paymentStatus == PaymentStatus.paid
                              ? PdfColors.green800
                              : (invoice.paymentStatus == PaymentStatus.partiallyPaid
                                  ? PdfColors.amber800
                                  : PdfColors.red800),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildItemsTable(
    Invoice invoice,
    bool isUnicode,
    String Function(double) fmtMoney,
  ) {
    final currencySymbol = isUnicode ? '₹' : 'Rs.';
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.8),
      columnWidths: const {
        0: pw.FixedColumnWidth(28),
        1: pw.FlexColumnWidth(5),
        2: pw.FlexColumnWidth(2),
        3: pw.FlexColumnWidth(2.5),
        4: pw.FlexColumnWidth(2.5),
      },
      children: [
        // Table Header
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColor.fromHex('#1E293B')),
          children: [
            _tableHeaderCell('#', align: pw.TextAlign.center),
            _tableHeaderCell('ITEM DESCRIPTION'),
            _tableHeaderCell('QTY', align: pw.TextAlign.right),
            _tableHeaderCell('RATE ($currencySymbol)', align: pw.TextAlign.right),
            _tableHeaderCell('AMOUNT ($currencySymbol)', align: pw.TextAlign.right),
          ],
        ),

        // Product rows
        ...invoice.items.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final item = entry.value;
          final isEven = entry.key % 2 == 0;
          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: isEven ? PdfColors.white : PdfColor.fromHex('#F8FAFC'),
            ),
            children: [
              _tableDataCell(index.toString(), align: pw.TextAlign.center),
              _tableDataCell(
                item.productNameSnapshot,
                isBold: true,
              ),
              _tableDataCell(
                '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity} ${item.unit}',
                align: pw.TextAlign.right,
              ),
              _tableDataCell(
                CurrencyFormatter.formatNumber(item.rate),
                align: pw.TextAlign.right,
              ),
              _tableDataCell(
                CurrencyFormatter.formatNumber(item.amount),
                align: pw.TextAlign.right,
                isBold: true,
              ),
            ],
          );
        }),

        // Additional Charges rows
        ...invoice.additionalCharges.map((charge) {
          return pw.TableRow(
            decoration: pw.BoxDecoration(color: PdfColor.fromHex('#FFFBEB')),
            children: [
              _tableDataCell('', align: pw.TextAlign.center),
              _tableDataCell(charge.name, isItalic: true),
              _tableDataCell('-', align: pw.TextAlign.right),
              _tableDataCell('-', align: pw.TextAlign.right),
              _tableDataCell(
                CurrencyFormatter.formatNumber(charge.amount),
                align: pw.TextAlign.right,
                isBold: true,
              ),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _tableHeaderCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 8.5,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  static pw.Widget _tableDataCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
    bool isBold = false,
    bool isItalic = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 9,
          color: PdfColor.fromHex('#0F172A'),
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontStyle: isItalic ? pw.FontStyle.italic : pw.FontStyle.normal,
        ),
      ),
    );
  }

  static pw.Widget _buildSummarySection(
    Invoice invoice,
    String Function(double) fmtMoney,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Left notes section
        pw.Expanded(
          flex: 5,
          child: pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F8FAFC'),
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'NOTES / REMARKS:',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  invoice.notes.isNotEmpty ? invoice.notes : 'Thank you for your business!',
                  style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800),
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 16),

        // Right totals table
        pw.Expanded(
          flex: 5,
          child: pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              children: [
                _summaryRow('Subtotal', fmtMoney(invoice.subtotal)),
                if (invoice.additionalChargesTotal > 0) ...[
                  pw.SizedBox(height: 3),
                  _summaryRow('Additional Charges', fmtMoney(invoice.additionalChargesTotal)),
                ],
                pw.Divider(color: PdfColors.grey300, thickness: 0.8),
                _summaryRow(
                  'TOTAL AMOUNT',
                  fmtMoney(invoice.total),
                  isBold: true,
                  fontSize: 11,
                  color: PdfColor.fromHex('#0F172A'),
                ),
                pw.SizedBox(height: 4),
                _summaryRow(
                  'Paid Amount',
                  fmtMoney(invoice.paidAmount),
                  color: PdfColors.green800,
                  isBold: true,
                ),
                pw.Divider(color: PdfColors.grey300, thickness: 0.8),
                _summaryRow(
                  'BALANCE DUE',
                  fmtMoney(invoice.balanceDue),
                  isBold: true,
                  fontSize: 11,
                  color: invoice.balanceDue > 0 ? PdfColors.red800 : PdfColors.green800,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _summaryRow(
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 9,
    PdfColor? color,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color ?? PdfColors.grey800,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color ?? PdfColor.fromHex('#0F172A'),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildFooter(Invoice invoice, CompanySettings settings) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 1)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          // Terms & conditions
          pw.Expanded(
            flex: 6,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'TERMS & CONDITIONS:',
                  style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  settings.termsAndConditions,
                  style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600, lineSpacing: 1.5),
                ),
              ],
            ),
          ),

          // Authorized Signatory
          pw.Expanded(
            flex: 4,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'For ${settings.companyName.toUpperCase()}',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A')),
                ),
                pw.SizedBox(height: 28),
                pw.Container(
                  width: 120,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400, width: 0.8)),
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'Authorized Signatory',
                  style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
