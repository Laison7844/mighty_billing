import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/date_formatter.dart';
import '../models/company_settings.dart';
import '../models/invoice.dart';
import 'logo_widget.dart';
import 'money_text.dart';
import 'status_badge.dart';

class InvoiceBillCard extends StatelessWidget {
  final Invoice invoice;
  final CompanySettings settings;

  const InvoiceBillCard({
    super.key,
    required this.invoice,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 1.2),
      ),
      child: Stack(
        children: [
          // Background Watermark
          Positioned.fill(
            child: Center(
              child: LogoWidget(
                size: 260,
                customPath: settings.customLogoPath,
                isWatermark: true,
                opacity: 0.05,
              ),
            ),
          ),

          // Invoice Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Company Header
                _buildCompanyHeader(),
                const SizedBox(height: 16),

                // 2. Bill Meta
                _buildBillMeta(),
                const SizedBox(height: 16),

                // 3. Items & Charges Table
                _buildTable(),
                const SizedBox(height: 16),

                // 4. Totals Summary
                _buildTotals(),
                const SizedBox(height: 20),

                // 5. Notes if present
                if (invoice.notes.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.note_alt_outlined, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            invoice.notes,
                            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 6. Terms & Signature
                _buildFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyHeader() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LogoWidget(
              size: 46,
              customPath: settings.customLogoPath,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  settings.companyName.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                    letterSpacing: 1.2,
                  ),
                ),
                if (settings.companySubtitle.isNotEmpty)
                  Text(
                    settings.companySubtitle.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accent,
                      letterSpacing: 1.0,
                    ),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (settings.address.isNotEmpty)
          Text(
            settings.address,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 2),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          children: [
            if (settings.phone.isNotEmpty)
              Text(
                'Mobile: ${settings.phone}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
              ),
            if (settings.gstNumber.isNotEmpty)
              Text(
                'GSTIN: ${settings.gstNumber}',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'CASH BILL',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Divider(),
      ],
    );
  }

  Widget _buildBillMeta() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Customer snapshot
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BILL TO',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  invoice.customerNameSnapshot,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                if (invoice.customerPhoneSnapshot.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Phone: ${invoice.customerPhoneSnapshot}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
                if (invoice.customerAddressSnapshot.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    invoice.customerAddressSnapshot,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),

          // Invoice Details
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('BILL NO: ', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                  Text(
                    invoice.invoiceNumber,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('DATE: ', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                  Text(
                    DateFormatter.formatInvoiceDate(invoice.date),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              StatusBadge(status: invoice.paymentStatus),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Table Header
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: const Row(
              children: [
                SizedBox(width: 24, child: Text('#', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                Expanded(flex: 4, child: Text('ITEM', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('QTY', textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('RATE', textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                Expanded(flex: 3, child: Text('AMOUNT', textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
              ],
            ),
          ),

          // Items
          ...invoice.items.asMap().entries.map((entry) {
            final index = entry.key + 1;
            final item = entry.value;
            final isEven = entry.key % 2 == 0;
            return Container(
              color: isEven ? Colors.white : AppColors.surfaceVariant.withValues(alpha: 0.4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  SizedBox(width: 24, child: Text('$index', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))),
                  Expanded(
                    flex: 4,
                    child: Text(
                      item.productNameSnapshot,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity} ${item.unit}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: MoneyText(
                      amount: item.rate,
                      textAlign: TextAlign.right,
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: MoneyText(
                      amount: item.amount,
                      textAlign: TextAlign.right,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            );
          }),

          // Additional Charges
          ...invoice.additionalCharges.map((charge) {
            return Container(
              color: AppColors.accentContainer.withValues(alpha: 0.3),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 8,
                    child: Text(
                      charge.name,
                      style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.onAccentContainer),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: MoneyText(
                      amount: charge.amount,
                      textAlign: TextAlign.right,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onAccentContainer,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTotals() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _totalRow('Subtotal', invoice.subtotal),
          if (invoice.additionalChargesTotal > 0) ...[
            const SizedBox(height: 4),
            _totalRow('Additional Charges', invoice.additionalChargesTotal),
          ],
          const Divider(height: 16),
          _totalRow(
            'TOTAL AMOUNT',
            invoice.total,
            isBold: true,
            fontSize: 15,
            color: AppColors.primary,
          ),
          const SizedBox(height: 6),
          _totalRow(
            'Paid Amount',
            invoice.paidAmount,
            color: AppColors.paidGreen,
            isBold: true,
          ),
          const Divider(height: 16),
          _totalRow(
            'BALANCE DUE',
            invoice.balanceDue,
            isBold: true,
            fontSize: 15,
            color: invoice.balanceDue > 0 ? AppColors.unpaidRed : AppColors.paidGreen,
          ),
        ],
      ),
    );
  }

  Widget _totalRow(
    String label,
    double amount, {
    bool isBold = false,
    double fontSize = 12,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.normal,
            color: color ?? AppColors.textSecondary,
          ),
        ),
        MoneyText(
          amount: amount,
          fontSize: fontSize,
          fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
          color: color ?? AppColors.textPrimary,
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Terms:',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                settings.termsAndConditions,
                style: const TextStyle(fontSize: 9, color: AppColors.textMuted, height: 1.3),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'For ${settings.companyName.toUpperCase()}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
            const SizedBox(height: 28),
            Container(
              width: 110,
              height: 1,
              color: AppColors.border,
            ),
            const SizedBox(height: 3),
            const Text(
              'Authorized Signatory',
              style: TextStyle(fontSize: 9, color: AppColors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}
