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
import '../../../services/pdf/invoice_pdf_generator.dart';
import '../../../services/sharing/share_service.dart';

class InvoicePdfPreviewScreen extends ConsumerStatefulWidget {
  final Invoice invoice;

  const InvoicePdfPreviewScreen({super.key, required this.invoice});

  @override
  ConsumerState<InvoicePdfPreviewScreen> createState() => _InvoicePdfPreviewScreenState();
}

class _InvoicePdfPreviewScreenState extends ConsumerState<InvoicePdfPreviewScreen> {
  Uint8List? _pdfBytes;
  bool _isLoading = true;
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

  Future<void> _sharePdf(CompanySettings settings) async {
    if (_pdfBytes == null) return;
    try {
      await ShareService.shareInvoicePdf(
        pdfBytes: _pdfBytes!,
        invoice: widget.invoice,
        settings: settings,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share: $e')),
        );
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
      final filename = ShareService.getSanitizedFilename(widget.invoice, settings);
      Directory? directory;

      if (Platform.isAndroid) {
        // App-specific external storage directory requires zero runtime permissions
        // on Android 4.4 through Android 16 (API 36) and avoids Scoped Storage crashes.
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
              label: 'Share / Send',
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
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Print',
            onPressed: _pdfBytes != null ? _printPdf : null,
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share Bill',
            onPressed: _pdfBytes != null ? () => _sharePdf(settings) : null,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Generating PDF invoice...'),
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
                        const Icon(Icons.error_outline, size: 48, color: AppColors.unpaidRed),
                        const SizedBox(height: 16),
                        Text('Error generating PDF: $_errorMessage'),
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
                    // Action Buttons Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      color: AppColors.surfaceVariant,
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.save_alt, size: 18),
                              label: const Text('Save PDF'),
                              onPressed: () => _saveToDocuments(settings),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.print, size: 18),
                              label: const Text('Print'),
                              onPressed: _printPdf,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.share, size: 18),
                              label: const Text('Share Bill'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => _sharePdf(settings),
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
                        loadingWidget: const Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  ],
                ),
    );
  }
}
