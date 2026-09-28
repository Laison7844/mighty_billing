import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/company_settings.dart';
import '../../../models/invoice.dart';
import '../../../services/image/invoice_image_generator.dart';
import '../../../services/pdf/invoice_pdf_generator.dart';
import '../../../services/sharing/share_service.dart';

class InvoicePdfPreviewScreen extends ConsumerStatefulWidget {
  final Invoice invoice;

  const InvoicePdfPreviewScreen({super.key, required this.invoice});

  @override
  ConsumerState<InvoicePdfPreviewScreen> createState() =>
      _InvoicePdfPreviewScreenState();
}

class _InvoicePdfPreviewScreenState
    extends ConsumerState<InvoicePdfPreviewScreen> {
  Uint8List? _pdfBytes;
  Uint8List? _imageBytes;
  bool _isLoading = true;
  bool _isSharingImage = false;
  bool _isSharingPdf = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final settings = await ref.read(settingsProvider.future);
      final bytes = await InvoicePdfGenerator.generateInvoicePdf(
        invoice: widget.invoice,
        settings: settings,
      );
      if (mounted) {
        setState(() {
          _pdfBytes = bytes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _shareImage(CompanySettings settings) async {
    if (_pdfBytes == null && _imageBytes == null) return;
    setState(() => _isSharingImage = true);

    try {
      _imageBytes ??= await InvoiceImageGenerator.generateInvoiceImage(
        invoice: widget.invoice,
        settings: settings,
        prebuiltPdfBytes: _pdfBytes,
      );

      await ShareService.shareInvoiceImage(
        imageBytes: _imageBytes!,
        invoice: widget.invoice,
        settings: settings,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharingImage = false);
      }
    }
  }

  Future<void> _sharePdf(CompanySettings settings) async {
    if (_pdfBytes == null) return;
    setState(() => _isSharingPdf = true);

    try {
      await ShareService.shareInvoicePdf(
        pdfBytes: _pdfBytes!,
        invoice: widget.invoice,
        settings: settings,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share PDF: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharingPdf = false);
      }
    }
  }

  Future<void> _printPdf() async {
    if (_pdfBytes == null) return;
    try {
      await ShareService.printInvoicePdf(
        pdfBytes: _pdfBytes!,
        invoiceNumber: widget.invoice.invoiceNumber,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to print: $e')),
        );
      }
    }
  }

  Future<void> _saveToDocuments(CompanySettings settings) async {
    if (_pdfBytes == null) return;
    try {
      final filename =
          ShareService.getSanitizedFilename(widget.invoice, settings);
      Directory? directory;

      if (Platform.isAndroid) {
        try {
          directory = await getExternalStorageDirectory();
        } catch (_) {}
      }

      directory ??= await getApplicationDocumentsDirectory();

      final file = File('${directory.path}/$filename');
      await file.writeAsBytes(_pdfBytes!, flush: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved: $filename'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Share PDF',
              textColor: Colors.amberAccent,
              onPressed: () => _sharePdf(settings),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving PDF: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    final settings = settingsAsync.value ?? const CompanySettings();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.invoice.invoiceNumber),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_alt_outlined),
            tooltip: 'Save PDF',
            onPressed:
                _pdfBytes != null ? () => _saveToDocuments(settings) : null,
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Print',
            onPressed: _pdfBytes != null ? _printPdf : null,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Generating invoice preview...'),
                  ],
                ),
              )
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: AppColors.unpaidRed,
                          ),
                          const SizedBox(height: 16),
                          Text('Error generating invoice: $_errorMessage'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadPdf,
                            child: const Text('Try Again'),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: [
                      // Action Buttons Bar: [ Share as Image ]  [ Share as PDF ]  [ Print ]
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: const Border(
                            bottom: BorderSide(
                              color: AppColors.border,
                              width: 1,
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // 1. Share as Image
                            Expanded(
                              flex: 5,
                              child: ElevatedButton.icon(
                                icon: _isSharingImage
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.image_outlined,
                                        size: 18,
                                      ),
                                label: const Text(
                                  'Share as Image',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 11,
                                    horizontal: 8,
                                  ),
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: _isSharingImage || _isLoading
                                    ? null
                                    : () => _shareImage(settings),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // 2. Share as PDF
                            Expanded(
                              flex: 5,
                              child: ElevatedButton.icon(
                                icon: _isSharingPdf
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.picture_as_pdf_outlined,
                                        size: 18,
                                      ),
                                label: const Text(
                                  'Share as PDF',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 11,
                                    horizontal: 8,
                                  ),
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: _isSharingPdf || _isLoading
                                    ? null
                                    : () => _sharePdf(settings),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // 3. Print
                            Expanded(
                              flex: 4,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.print_outlined, size: 18),
                                label: const Text(
                                  'Print',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 11,
                                    horizontal: 8,
                                  ),
                                  side: const BorderSide(
                                    color: AppColors.primary,
                                    width: 1.2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: _isLoading ? null : _printPdf,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // PDF Preview View
                      Expanded(
                        child: PdfPreview(
                          build: (format) async => _pdfBytes!,
                          useActions: false, // We provide custom clean buttons above
                          canChangePageFormat: false,
                          canChangeOrientation: false,
                          initialPageFormat: PdfPageFormat.a4,
                          loadingWidget: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
