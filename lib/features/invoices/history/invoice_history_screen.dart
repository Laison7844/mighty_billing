import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/repositories/invoice_repository.dart';
import '../../../models/invoice.dart';
import '../../../widgets/empty_state_view.dart';
import '../../../widgets/money_text.dart';
import '../../../widgets/status_badge.dart';
import '../create/create_invoice_screen.dart';
import '../details/invoice_detail_screen.dart';

class InvoiceHistoryScreen extends ConsumerWidget {
  const InvoiceHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(invoicesProvider);
    final searchQuery = ref.watch(invoiceSearchQueryProvider);
    final currentStatus = ref.watch(invoiceStatusFilterProvider);
    final currentSort = ref.watch(invoiceSortOptionProvider);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Invoice History'),
        actions: [
          PopupMenuButton<InvoiceSortOption>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort By',
            initialValue: currentSort,
            onSelected: (sort) {
              ref.read(invoiceSortOptionProvider.notifier).state = sort;
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: InvoiceSortOption.newest,
                child: Text('Newest First'),
              ),
              const PopupMenuItem(
                value: InvoiceSortOption.oldest,
                child: Text('Oldest First'),
              ),
              const PopupMenuItem(
                value: InvoiceSortOption.highestAmount,
                child: Text('Highest Amount'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_invoice_history',
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Bill'),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const CreateInvoiceScreen(),
            ),
          );
        },
      ),
      body: SafeArea(
        top: false,
        child: Column(
        children: [
          // Search Field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by bill no, customer, phone...',
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          ref.read(invoiceSearchQueryProvider.notifier).state = '';
                        },
                      )
                    : null,
              ),
              onChanged: (val) {
                ref.read(invoiceSearchQueryProvider.notifier).state = val;
              },
            ),
          ),

          // Status Filter Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _filterChip(
                  label: 'All Bills',
                  isSelected: currentStatus == null,
                  onSelected: () => ref.read(invoiceStatusFilterProvider.notifier).state = null,
                ),
                const SizedBox(width: 8),
                _filterChip(
                  label: 'Paid',
                  isSelected: currentStatus == PaymentStatus.paid,
                  color: AppColors.paidGreen,
                  onSelected: () => ref.read(invoiceStatusFilterProvider.notifier).state = PaymentStatus.paid,
                ),
                const SizedBox(width: 8),
                _filterChip(
                  label: 'Partially Paid',
                  isSelected: currentStatus == PaymentStatus.partiallyPaid,
                  color: AppColors.partialOrange,
                  onSelected: () => ref.read(invoiceStatusFilterProvider.notifier).state = PaymentStatus.partiallyPaid,
                ),
                const SizedBox(width: 8),
                _filterChip(
                  label: 'Unpaid',
                  isSelected: currentStatus == PaymentStatus.unpaid,
                  color: AppColors.unpaidRed,
                  onSelected: () => ref.read(invoiceStatusFilterProvider.notifier).state = PaymentStatus.unpaid,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Invoice List
          Expanded(
            child: invoicesAsync.when(
              data: (invoices) {
                if (invoices.isEmpty) {
                  return EmptyStateView(
                    icon: Icons.receipt_long_outlined,
                    title: searchQuery.isNotEmpty || currentStatus != null
                        ? 'No invoices match filters'
                        : 'No invoices created yet',
                    message: searchQuery.isNotEmpty || currentStatus != null
                        ? 'Try clearing search or changing status filter.'
                        : 'Create your first invoice for Mighty Hollow Blocks.',
                  
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: invoices.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final inv = invoices[index];
                    return _invoiceCard(context, inv);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error loading invoices: $err')),
            ),
          ),
        ],
      ),
    ),
  );
  }

  Widget _filterChip({
    required String label,
    required bool isSelected,
    Color? color,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: color?.withValues(alpha: 0.15) ?? AppColors.primary.withValues(alpha: 0.12),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? (color ?? AppColors.primary) : AppColors.textSecondary,
      ),
    );
  }

  Widget _invoiceCard(BuildContext context, Invoice inv) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => InvoiceDetailScreen(invoiceId: inv.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header: Invoice No + Date + Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          inv.invoiceNumber,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        StatusBadge(status: inv.paymentStatus),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormatter.formatInvoiceDate(inv.date),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),

              // Customer & Financials Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          inv.customerNameSnapshot,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (inv.customerPhoneSnapshot.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            inv.customerPhoneSnapshot,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                        const SizedBox(height: 2),
                        Text(
                          '${inv.items.length} ${inv.items.length == 1 ? "item" : "items"}${inv.additionalCharges.isNotEmpty ? " + charges" : ""}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),

                  // Amount details
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      MoneyText(
                        amount: inv.total,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                      const SizedBox(height: 2),
                      if (inv.balanceDue > 0)
                        Text(
                          'Bal: ${CurrencyFormatter.format(inv.balanceDue)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.unpaidRed,
                          ),
                        )
                      else
                        const Text(
                          'Paid in Full',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.paidGreen,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
