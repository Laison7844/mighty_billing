import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/additional_charge.dart';
import '../../../models/customer.dart';
import '../../../models/invoice.dart';
import '../../../models/invoice_item.dart';
import '../../../models/product.dart';
import '../../../widgets/money_text.dart';
import '../../../widgets/primary_button.dart';
import '../../customers/customer_form_dialog.dart';
import '../details/invoice_detail_screen.dart';

class CreateInvoiceScreen extends ConsumerStatefulWidget {
  final Invoice? existingInvoice;

  const CreateInvoiceScreen({super.key, this.existingInvoice});

  @override
  ConsumerState<CreateInvoiceScreen> createState() =>
      _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends ConsumerState<CreateInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();

  // Customer state
  String? _selectedCustomerId;
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerPhoneController =
      TextEditingController();
  final TextEditingController _customerAddressController =
      TextEditingController();
  final TextEditingController _customerGstController = TextEditingController();

  // Date
  DateTime _invoiceDate = DateTime.now();

  // Invoice Items
  final List<_ItemEntry> _items = [];

  // Additional Charges
  final List<_ChargeEntry> _charges = [];

  // Payment
  final TextEditingController _paidAmountController = TextEditingController(
    text: '0',
  );
  final TextEditingController _notesController = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingInvoice;
    if (existing != null) {
      _selectedCustomerId = existing.customerId;
      _customerNameController.text = existing.customerNameSnapshot;
      _customerPhoneController.text = existing.customerPhoneSnapshot;
      _customerAddressController.text = existing.customerAddressSnapshot;
      _customerGstController.text = existing.customerGstNumberSnapshot ?? '';
      _invoiceDate = existing.date;
      _notesController.text = existing.notes;
      _paidAmountController.text = existing.paidAmount.toStringAsFixed(2);

      for (final item in existing.items) {
        _items.add(
          _ItemEntry(
            productId: item.productId,
            nameController: TextEditingController(
              text: item.productNameSnapshot,
            ),
            quantityController: TextEditingController(
              text: item.quantity % 1 == 0
                  ? item.quantity.toInt().toString()
                  : item.quantity.toString(),
            ),
            rateController: TextEditingController(
              text: item.rate.toStringAsFixed(2),
            ),
            unit: item.unit,
          ),
        );
      }

      for (final ch in existing.additionalCharges) {
        _charges.add(
          _ChargeEntry(
            nameController: TextEditingController(text: ch.name),
            amountController: TextEditingController(
              text: ch.amount.toStringAsFixed(2),
            ),
          ),
        );
      }
    } else {
      // Add one empty item by default
      _addNewItem();
    }
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerAddressController.dispose();
    _customerGstController.dispose();
    _paidAmountController.dispose();
    _notesController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    for (final ch in _charges) {
      ch.dispose();
    }
    super.dispose();
  }

  void _addNewItem([Product? product]) {
    setState(() {
      _items.add(
        _ItemEntry(
          productId: product?.id,
          nameController: TextEditingController(text: product?.name ?? ''),
          quantityController: TextEditingController(text: '100'),
          rateController: TextEditingController(
            text: product != null
                ? product.defaultRate.toStringAsFixed(2)
                : '34.00',
          ),
          unit: product?.unit ?? 'Nos',
        ),
      );
    });
  }

  void _removeItem(int index) {
    if (_items.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least one item is required in the bill'),
        ),
      );
      return;
    }
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  void _addCharge([String name = 'Vehicle Charge', double defaultAmt = 0.0]) {
    setState(() {
      _charges.add(
        _ChargeEntry(
          nameController: TextEditingController(text: name),
          amountController: TextEditingController(
            text: defaultAmt > 0 ? defaultAmt.toStringAsFixed(2) : '',
          ),
        ),
      );
    });
  }

  void _removeCharge(int index) {
    setState(() {
      _charges[index].dispose();
      _charges.removeAt(index);
    });
  }

  double get _subtotal {
    double sum = 0.0;
    for (final item in _items) {
      final qty = double.tryParse(item.quantityController.text.trim()) ?? 0.0;
      final rate = double.tryParse(item.rateController.text.trim()) ?? 0.0;
      sum += (qty * rate);
    }
    return sum;
  }

  double get _additionalChargesTotal {
    double sum = 0.0;
    for (final ch in _charges) {
      final amt = double.tryParse(ch.amountController.text.trim()) ?? 0.0;
      sum += amt;
    }
    return sum;
  }

  double get _total => _subtotal + _additionalChargesTotal;

  double get _paidAmount =>
      double.tryParse(_paidAmountController.text.trim()) ?? 0.0;

  double get _balanceDue {
    final bal = _total - _paidAmount;
    return bal < 0 ? 0 : bal;
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _invoiceDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _invoiceDate = picked;
      });
    }
  }

  Future<void> _saveInvoice() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please correct the errors in the form')),
      );
      return;
    }

    if (_customerNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or enter customer name')),
      );
      return;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final invoiceRepo = ref.read(invoiceRepositoryProvider);
      final settings = await ref.read(settingsProvider.future);

      final List<InvoiceItem> finalItems = [];
      for (final item in _items) {
        final name = item.nameController.text.trim();
        final qty = double.tryParse(item.quantityController.text.trim()) ?? 0.0;
        final rate = double.tryParse(item.rateController.text.trim()) ?? 0.0;
        final amount = qty * rate;

        finalItems.add(
          InvoiceItem(
            productId: item.productId,
            productNameSnapshot: name.isNotEmpty ? name : 'Concrete Block',
            quantity: qty,
            unit: item.unit,
            rate: rate,
            amount: amount,
          ),
        );
      }

      final List<AdditionalCharge> finalCharges = [];
      for (final ch in _charges) {
        final name = ch.nameController.text.trim();
        final amt = double.tryParse(ch.amountController.text.trim()) ?? 0.0;
        if (name.isNotEmpty && amt > 0) {
          finalCharges.add(AdditionalCharge(name: name, amount: amt));
        }
      }

      final now = DateTime.now();
      String invoiceNumber;
      final existing = widget.existingInvoice;

      if (existing != null) {
        invoiceNumber = existing.invoiceNumber;
      } else {
        invoiceNumber = await invoiceRepo.getNextInvoiceNumber(
          prefix: settings.invoicePrefix,
          startingSequence: settings.startingInvoiceNumber,
        );
      }

      final invoice = Invoice(
        id: existing?.id ?? const Uuid().v4(),
        invoiceNumber: invoiceNumber,
        customerId: _selectedCustomerId,
        customerNameSnapshot: _customerNameController.text.trim(),
        customerPhoneSnapshot: _customerPhoneController.text.trim(),
        customerAddressSnapshot: _customerAddressController.text.trim(),
        customerGstNumberSnapshot: _customerGstController.text.trim().isNotEmpty
            ? _customerGstController.text.trim().toUpperCase()
            : null,
        date: _invoiceDate,
        items: finalItems,
        additionalCharges: finalCharges,
        subtotal: _subtotal,
        total: _total,
        paidAmount: _paidAmount,
        balanceDue: _balanceDue,
        notes: _notesController.text.trim(),
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );

      if (existing != null) {
        await invoiceRepo.updateInvoice(invoice);
      } else {
        await invoiceRepo.saveInvoice(invoice);
      }

      ref.invalidate(invoicesProvider);
      ref.invalidate(dashboardMetricsProvider);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bill $invoiceNumber saved successfully!')),
      );

      // Navigate to details screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => InvoiceDetailScreen(invoiceId: invoice.id),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving invoice: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersProvider);
    final productsAsync = ref.watch(productsProvider);
    final isEditing = widget.existingInvoice != null;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          isEditing
              ? 'Edit Bill (${widget.existingInvoice!.invoiceNumber})'
              : 'Create New Bill',
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.check, color: Colors.white),
            label: Text(
              isEditing ? 'Update' : 'Save',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: _isSaving ? null : _saveInvoice,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            children: [
              // Section 1: Customer & Date
              _buildSectionCard(
                title: 'Customer Details',
                icon: Icons.person_outline,
                trailing: TextButton.icon(
                  icon: const Icon(Icons.person_add_alt, size: 16),
                  label: const Text('New Customer'),
                  onPressed: () async {
                    final newCustomer = await showDialog<Customer>(
                      context: context,
                      builder: (context) => const CustomerFormDialog(),
                    );
                    if (newCustomer != null) {
                      final repo = ref.read(customerRepositoryProvider);
                      await repo.saveCustomer(newCustomer);
                      ref.invalidate(customersProvider);
                      setState(() {
                        _selectedCustomerId = newCustomer.id;
                        _customerNameController.text = newCustomer.name;
                        _customerPhoneController.text = newCustomer.phone;
                        _customerAddressController.text = newCustomer.address;
                        _customerGstController.text =
                            newCustomer.gstNumber ?? '';
                      });
                    }
                  },
                ),
                children: [
                  // Quick Select Dropdown
                  customersAsync.when(
                    data: (customers) {
                      if (customers.isEmpty && _selectedCustomerId == null) {
                        return const SizedBox.shrink();
                      }

                      final menuItems = customers.map((c) {
                        return DropdownMenuItem(
                          value: c.id,
                          child: Text(
                            '${c.name} ${c.phone.isNotEmpty ? "(${c.phone})" : ""}',
                          ),
                        );
                      }).toList();

                      // If a newly created customer isn't in the async list yet,
                      // add it to menuItems to prevent dropdown assertion failure
                      if (_selectedCustomerId != null &&
                          !customers.any((c) => c.id == _selectedCustomerId)) {
                        menuItems.insert(
                          0,
                          DropdownMenuItem(
                            value: _selectedCustomerId,
                            child: Text(
                              '${_customerNameController.text} ${_customerPhoneController.text.isNotEmpty ? "(${_customerPhoneController.text})" : ""}',
                            ),
                          ),
                        );
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: DropdownButtonFormField<String>(
                          key: ValueKey(_selectedCustomerId),
                          initialValue: _selectedCustomerId,
                          decoration: const InputDecoration(
                            labelText: 'Select Existing Customer',
                            prefixIcon: Icon(Icons.people_alt_outlined),
                          ),
                          hint: const Text('Choose a customer...'),
                          items: menuItems,
                          onChanged: (customerId) {
                            if (customerId != null) {
                              final match = customers.where(
                                (c) => c.id == customerId,
                              );
                              if (match.isNotEmpty) {
                                final c = match.first;
                                setState(() {
                                  _selectedCustomerId = c.id;
                                  _customerNameController.text = c.name;
                                  _customerPhoneController.text = c.phone;
                                  _customerAddressController.text = c.address;
                                  _customerGstController.text =
                                      c.gstNumber ?? '';
                                });
                              }
                            }
                          },
                        ),
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (e, s) => const SizedBox.shrink(),
                  ),

                  TextFormField(
                    controller: _customerNameController,
                    decoration: const InputDecoration(
                      labelText: 'Customer Name *',
                      hintText: 'e.g.John',
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Customer name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _customerPhoneController,
                          decoration: const InputDecoration(
                            labelText: 'Phone',
                            hintText: '98470 12345',
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: _selectDate,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Bill Date',
                              suffixIcon: Icon(Icons.calendar_month, size: 20),
                            ),
                            child: Text(
                              DateFormatter.formatShortDate(_invoiceDate),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _customerAddressController,
                    decoration: const InputDecoration(
                      labelText: 'Site / Delivery Address',
                      hintText: 'e.g. Green Valley Site, Plot #12',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _customerGstController,
                    decoration: const InputDecoration(
                      labelText: 'Customer GSTIN (Optional)',
                      hintText: 'e.g. 32AAAAA0000A1Z5',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Section 2: Items
              _buildSectionCard(
                title: 'Items',
                icon: Icons.view_in_ar_rounded,
                trailing: ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Item'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _addNewItem(),
                ),
                children: [
                  // Quick add product chips from database
                  productsAsync.when(
                    data: (products) {
                      if (products.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Quick Add Product:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: products.map((p) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: ActionChip(
                                      avatar: const Icon(
                                        Icons.add,
                                        size: 14,
                                        color: AppColors.accent,
                                      ),
                                      label: Text(p.name),
                                      backgroundColor: AppColors.surfaceVariant,
                                      labelStyle: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      onPressed: () => _addNewItem(p),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (e, s) => const SizedBox.shrink(),
                  ),

                  // Item Rows
                  ..._items.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return _buildItemRow(
                      index,
                      item,
                      productsAsync.value ?? [],
                    );
                  }),
                ],
              ),
              const SizedBox(height: 16),

              // Section 3: Additional Charges
              _buildSectionCard(
                title: 'Additional Charges',
                icon: Icons.local_shipping_outlined,
                trailing: ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Charge'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _addCharge(),
                ),
                children: [
                  // Quick suggested charges chips
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.add, size: 14),
                          label: const Text('Vehicle Charge'),
                          onPressed: () => _addCharge('Vehicle Charge', 300),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.add, size: 14),
                          label: const Text('Loading Charge'),
                          onPressed: () => _addCharge('Loading Charge', 200),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.add, size: 14),
                          label: const Text('Unloading Charge'),
                          onPressed: () => _addCharge('Unloading Charge', 200),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.add, size: 14),
                          label: const Text(' Other Charges'),
                          onPressed: () => _addCharge('Other Charges', 100),
                        ),
                      ],
                    ),
                  ),

                  if (_charges.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No additional charges added (Vehicle, Loading, etc.)',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  else
                    ..._charges.asMap().entries.map((entry) {
                      final index = entry.key;
                      final charge = entry.value;
                      return _buildChargeRow(index, charge);
                    }),
                ],
              ),
              const SizedBox(height: 16),

              // Section 4: Payment & Summary
              _buildSectionCard(
                title: 'Payment & Total',
                icon: Icons.payments_outlined,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        _summaryLine('Subtotal (Items)', _subtotal),
                        if (_additionalChargesTotal > 0) ...[
                          const SizedBox(height: 6),
                          _summaryLine(
                            'Additional Charges',
                            _additionalChargesTotal,
                          ),
                        ],
                        const Divider(height: 18),
                        _summaryLine(
                          'TOTAL AMOUNT',
                          _total,
                          isBold: true,
                          fontSize: 17,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Paid Amount Field & Shortcut Buttons
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 6,
                        child: TextFormField(
                          controller: _paidAmountController,
                          decoration: const InputDecoration(
                            labelText: 'Paid Amount (₹)',
                            prefixText: '₹ ',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (val) {
                            setState(() {}); // Recalculate balance
                          },
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return null;
                            final parsed = double.tryParse(val.trim());
                            if (parsed == null || parsed < 0) {
                              return 'Invalid paid amount';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 4,
                        child: Column(
                          children: [
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 12,
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  _paidAmountController.text = _total
                                      .toStringAsFixed(2);
                                });
                              },
                              child: const Text(
                                'Paid Full',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  _paidAmountController.text = '0.00';
                                });
                              },
                              child: const Text(
                                'Unpaid (₹0)',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Balance Due Banner
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _balanceDue > 0
                          ? AppColors.unpaidContainer
                          : AppColors.paidContainer,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _balanceDue > 0
                            ? const Color(0xFFFECACA)
                            : const Color(0xFFA7F3D0),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'BALANCE DUE',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _balanceDue > 0
                                ? AppColors.unpaidRed
                                : AppColors.paidGreen,
                          ),
                        ),
                        MoneyText(
                          amount: _balanceDue,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _balanceDue > 0
                              ? AppColors.unpaidRed
                              : AppColors.paidGreen,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes / Remarks (Optional)',
                      hintText:
                          'e.g. Delivery by evening, site supervisor John',
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Submit Button
              PrimaryButton(
                label: isEditing ? 'Update Invoice' : 'Save & Generate Bill',
                icon: Icons.receipt_long,
                isLoading: _isSaving,
                onPressed: _saveInvoice,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    Widget? trailing,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                ?trailing,
              ],
            ),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(
    int index,
    _ItemEntry item,
    List<Product> availableProducts,
  ) {
    final qty = double.tryParse(item.quantityController.text.trim()) ?? 0.0;
    final rate = double.tryParse(item.rateController.text.trim()) ?? 0.0;
    final amount = qty * rate;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: AppColors.primary,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: item.nameController,
                  decoration: const InputDecoration(
                    labelText: 'Product / Item Name *',
                    hintText: 'e.g. 4 inch Block',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  onChanged: (val) => setState(() {}),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Item name required';
                    }
                    return null;
                  },
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppColors.unpaidRed,
                  size: 20,
                ),
                onPressed: () => _removeItem(index),
                tooltip: 'Remove Item',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Quantity
              Expanded(
                flex: 4,
                child: TextFormField(
                  controller: item.quantityController,
                  decoration: InputDecoration(
                    labelText: 'Qty (${item.unit})',
                    hintText: '100',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (val) => setState(() {}),
                  validator: (val) {
                    final q = double.tryParse(val ?? '');
                    if (q == null || q <= 0) return 'Invalid';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Rate
              Expanded(
                flex: 4,
                child: TextFormField(
                  controller: item.rateController,
                  decoration: const InputDecoration(
                    labelText: 'Rate (₹)',
                    hintText: '',
                    prefixText: '₹',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (val) => setState(() {}),
                  validator: (val) {
                    final r = double.tryParse(val ?? '');
                    if (r == null || r < 0) return 'Invalid';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Item Amount
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Amount',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textMuted,
                        ),
                      ),
                      MoneyText(
                        amount: amount,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChargeRow(int index, _ChargeEntry charge) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.accentContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 6,
            child: TextFormField(
              controller: charge.nameController,
              decoration: const InputDecoration(
                labelText: 'Charge Name',
                hintText: 'e.g. Vehicle Charge',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: TextFormField(
              controller: charge.amountController,
              decoration: const InputDecoration(
                labelText: 'Amount (₹)',
                hintText: '200',
                prefixText: '₹',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (val) => setState(() {}),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.remove_circle_outline,
              color: AppColors.unpaidRed,
              size: 20,
            ),
            onPressed: () => _removeCharge(index),
            tooltip: 'Remove Charge',
          ),
        ],
      ),
    );
  }

  Widget _summaryLine(
    String label,
    double amount, {
    bool isBold = false,
    double fontSize = 13,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
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
}

class _ItemEntry {
  final String? productId;
  final TextEditingController nameController;
  final TextEditingController quantityController;
  final TextEditingController rateController;
  String unit;

  _ItemEntry({
    this.productId,
    required this.nameController,
    required this.quantityController,
    required this.rateController,
    this.unit = 'Nos',
  });

  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    rateController.dispose();
  }
}

class _ChargeEntry {
  final TextEditingController nameController;
  final TextEditingController amountController;

  _ChargeEntry({required this.nameController, required this.amountController});

  void dispose() {
    nameController.dispose();
    amountController.dispose();
  }
}
