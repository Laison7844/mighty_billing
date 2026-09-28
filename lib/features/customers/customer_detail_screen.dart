import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/customer.dart';
import '../../models/invoice.dart';
import '../../widgets/money_text.dart';
import '../../widgets/status_badge.dart';
import '../invoices/details/invoice_detail_screen.dart';
import 'customer_form_dialog.dart';

class CustomerDetailScreen extends ConsumerStatefulWidget {
  final Customer customer;

  const CustomerDetailScreen({super.key, required this.customer});

  @override
  ConsumerState<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen> {
  late Customer _currentCustomer;

  @override
  void initState() {
    super.initState();
    _currentCustomer = widget.customer;
  }

  Future<void> _editCustomer() async {
    final updated = await showDialog<Customer>(
      context: context,
      builder: (context) => CustomerFormDialog(customer: _currentCustomer),
    );

    if (updated != null && mounted) {
      final repo = ref.read(customerRepositoryProvider);
      await repo.updateCustomer(updated);
      ref.invalidate(customersProvider);
      setState(() {
        _currentCustomer = updated;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer updated successfully')),
        );
      }
    }
  }

  Future<void> _deleteCustomer() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Customer?'),
        content: Text('Are you sure you want to delete ${_currentCustomer.name}? Existing past invoices will retain their customer snapshot.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.unpaidRed),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final repo = ref.read(customerRepositoryProvider);
      await repo.deleteCustomer(_currentCustomer.id);
      ref.invalidate(customersProvider);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer deleted')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoiceRepo = ref.watch(invoiceRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentCustomer.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Customer',
            onPressed: _editCustomer,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete Customer',
            onPressed: _deleteCustomer,
          ),
        ],
      ),
      body: FutureBuilder<List<Invoice>>(
        future: invoiceRepo.getInvoicesByCustomerId(_currentCustomer.id),
        builder: (context, snapshot) {
          final invoices = snapshot.data ?? [];
          final isLoading = snapshot.connectionState == ConnectionState.waiting;

          double totalBilled = 0;
          double totalPaid = 0;
          double totalOutstanding = 0;

          for (final inv in invoices) {
            totalBilled += inv.total;
            totalPaid += inv.paidAmount;
            totalOutstanding += inv.balanceDue;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: AppColors.accentContainer,
                              child: Text(
                                _currentCustomer.name.isNotEmpty
                                    ? _currentCustomer.name[0].toUpperCase()
                                    : 'C',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.onAccentContainer,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _currentCustomer.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  if (_currentCustomer.phone.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      _currentCustomer.phone,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_currentCustomer.address.isNotEmpty) ...[
                          const Divider(height: 24),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.location_on_outlined, size: 18, color: AppColors.textSecondary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _currentCustomer.address,
                                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Financial Summary Cards
                Row(
                  children: [
                    Expanded(
                      child: _statCard('Total Billed', totalBilled, AppColors.primary),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _statCard('Total Paid', totalPaid, AppColors.paidGreen),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _statCard('Outstanding', totalOutstanding, totalOutstanding > 0 ? AppColors.unpaidRed : AppColors.paidGreen),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Invoices Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Customer Invoices',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${invoices.length} Bills',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (isLoading)
                  const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                else if (invoices.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'No invoices yet for this customer.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                else
                  ...invoices.map((inv) => _invoiceItemCard(inv)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statCard(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          MoneyText(
            amount: amount,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
            showDecimals: false,
          ),
        ],
      ),
    );
  }

  Widget _invoiceItemCard(Invoice inv) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => InvoiceDetailScreen(invoiceId: inv.id),
            ),
          );
          setState(() {}); // Refresh on return
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          inv.invoiceNumber,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                        ),
                        StatusBadge(status: inv.paymentStatus),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormatter.formatInvoiceDate(inv.date),
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  MoneyText(
                    amount: inv.total,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                  if (inv.balanceDue > 0)
                    Text(
                      'Bal: ${CurrencyFormatter.format(inv.balanceDue)}',
                      style: const TextStyle(fontSize: 11, color: AppColors.unpaidRed, fontWeight: FontWeight.w600),
                    )
                  else
                    const Text(
                      'Fully Paid',
                      style: TextStyle(fontSize: 11, color: AppColors.paidGreen, fontWeight: FontWeight.w600),
                    ),
                ],
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
