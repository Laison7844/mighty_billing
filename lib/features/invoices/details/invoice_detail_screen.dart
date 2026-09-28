import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/company_settings.dart';
import '../../../models/invoice.dart';
import '../../../services/image/invoice_image_generator.dart';
import '../../../services/pdf/invoice_pdf_generator.dart';
import '../../../services/sharing/share_service.dart';
import '../../../widgets/invoice_bill_card.dart';
import '../create/create_invoice_screen.dart';
import '../preview/invoice_pdf_preview_screen.dart';

class InvoiceDetailScreen extends ConsumerStatefulWidget {
  final String invoiceId;

  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  ConsumerState<InvoiceDetailScreen> createState() =>
      _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends ConsumerState<InvoiceDetailScreen> {
  Invoice? _invoice;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInvoice();
  }

  Future<void> _loadInvoice() async {
    setState(() => _isLoading = true);
    final repo = ref.read(invoiceRepositoryProvider);
    final inv = await repo.getInvoiceById(widget.invoiceId);
    if (mounted) {
      setState(() {
        _invoice = inv;
        _isLoading = false;
      });
    }
  }

  Future<void> _sharePdf(CompanySettings settings) async {
    if (_invoice == null) return;
    try {
      final bytes = await InvoicePdfGenerator.generateInvoicePdf(
        invoice: _invoice!,
        settings: settings,
      );
      await ShareService.shareInvoicePdf(
        pdfBytes: bytes,
        invoice: _invoice!,
        settings: settings,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to share: $e')));
      }
    }
  }

  Future<void> _shareImage(CompanySettings settings) async {
    if (_invoice == null) return;
    try {
      final imageBytes = await InvoiceImageGenerator.generateInvoiceImage(
        invoice: _invoice!,
        settings: settings,
      );
      await ShareService.shareInvoiceImage(
        imageBytes: imageBytes,
        invoice: _invoice!,
        settings: settings,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to share image: $e')));
      }
    }
  }

  Future<void> _showShareOptions(CompanySettings settings) async {
    if (_invoice == null) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Share Invoice',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                '${_invoice!.invoiceNumber} • ${_invoice!.customerNameSnapshot}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.image_outlined,
                    color: AppColors.accent,
                  ),
                ),
                title: const Text(
                  'Share as Image',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('High-resolution PNG • Ideal for WhatsApp'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _shareImage(settings);
                },
              ),
              const Divider(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf_outlined,
                    color: AppColors.primary,
                  ),
                ),
                title: const Text(
                  'Share as PDF',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Full document PDF for printing and records',
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _sharePdf(settings);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _printPdf(CompanySettings settings) async {
    if (_invoice == null) return;
    try {
      final bytes = await InvoicePdfGenerator.generateInvoicePdf(
        invoice: _invoice!,
        settings: settings,
      );
      await ShareService.printInvoicePdf(
        pdfBytes: bytes,
        invoiceNumber: _invoice!.invoiceNumber,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to print: $e')));
      }
    }
  }

  Future<void> _editInvoice() async {
    if (_invoice == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreateInvoiceScreen(existingInvoice: _invoice),
      ),
    );
    _loadInvoice();
  }

  Future<void> _deleteInvoice() async {
    if (_invoice == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Invoice?'),
        content: Text(
          'Are you sure you want to delete invoice ${_invoice!.invoiceNumber}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.unpaidRed,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final repo = ref.read(invoiceRepositoryProvider);
      await repo.deleteInvoice(_invoice!.id);
      ref.invalidate(invoicesProvider);
      ref.invalidate(dashboardMetricsProvider);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invoice deleted')));
      }
    }
  }

  Future<void> _updatePaymentDialog() async {
    if (_invoice == null) return;
    final paidController = TextEditingController(
      text: _invoice!.paidAmount.toStringAsFixed(2),
    );

    final updatedPaid = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Invoice Total: ₹${_invoice!.total.toStringAsFixed(2)}'),
            const SizedBox(height: 12),
            TextField(
              controller: paidController,
              decoration: const InputDecoration(
                labelText: 'Paid Amount (₹)',
                prefixText: '₹ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton(
                  onPressed: () =>
                      paidController.text = _invoice!.total.toStringAsFixed(2),
                  child: const Text('Mark Full Paid'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => paidController.text = '0.00',
                  child: const Text('Unpaid'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(paidController.text.trim());
              if (val != null && val >= 0) {
                Navigator.of(context).pop(val);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (updatedPaid != null && mounted) {
      final repo = ref.read(invoiceRepositoryProvider);
      final newBal = _invoice!.total - updatedPaid;
      final updatedInv = _invoice!.copyWith(
        paidAmount: updatedPaid,
        balanceDue: newBal < 0 ? 0 : newBal,
        updatedAt: DateTime.now(),
      );
      await repo.updateInvoice(updatedInv);
      ref.invalidate(invoicesProvider);
      ref.invalidate(dashboardMetricsProvider);
      setState(() => _invoice = updatedInv);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Payment updated')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    final settings = settingsAsync.value ?? const CompanySettings();

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading Invoice...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_invoice == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Not Found')),
        body: const Center(child: Text('Invoice not found or deleted.')),
      );
    }

    final invoice = _invoice!;

    return Scaffold(
      appBar: AppBar(
        title: Text(invoice.invoiceNumber),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Print Bill',
            onPressed: () => _printPdf(settings),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Invoice',
            onPressed: _editInvoice,
          ),
          IconButton(
            icon: const Icon(Icons.payment),
            tooltip: 'Update Payment',
            onPressed: _updatePaymentDialog,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete Invoice',
            onPressed: _deleteInvoice,
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf, size: 18),
                    label: const Text('PDF Preview'),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              InvoicePdfPreviewScreen(invoice: invoice),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Share Bill'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _showShareOptions(settings),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            children: [InvoiceBillCard(invoice: invoice, settings: settings)],
          ),
        ),
      ),
    );
  }
}
