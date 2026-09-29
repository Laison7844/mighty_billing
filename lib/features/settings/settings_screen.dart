import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/financial_year_util.dart';
import '../../models/company_settings.dart';
import '../../services/migration/firebase_migration_service.dart';
import '../../widgets/logo_widget.dart';
import '../../widgets/primary_button.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _companyNameController;
  late TextEditingController _subtitleController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _emailController;
  late TextEditingController _gstController;
  late TextEditingController _websiteController;
  late TextEditingController _termsController;
  late TextEditingController _invoicePrefixController;
  late TextEditingController _startingSeqController;

  String? _customLogoPath;
  bool _isSaving = false;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _companyNameController = TextEditingController();
    _subtitleController = TextEditingController();
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
    _emailController = TextEditingController();
    _gstController = TextEditingController();
    _websiteController = TextEditingController();
    _termsController = TextEditingController();
    _invoicePrefixController = TextEditingController();
    _startingSeqController = TextEditingController();
  }

  void _populate(CompanySettings s) {
    if (_isLoaded) return;
    _companyNameController.text = s.companyName;
    _subtitleController.text = s.companySubtitle;
    _phoneController.text = s.phone;
    _addressController.text = s.address;
    _emailController.text = s.email;
    _gstController.text = s.gstNumber;
    _websiteController.text = s.website;
    _termsController.text = s.termsAndConditions;
    _invoicePrefixController.text = s.invoicePrefix;
    _startingSeqController.text = s.startingInvoiceNumber.toString();
    _customLogoPath = s.customLogoPath;
    _isLoaded = true;
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _subtitleController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _gstController.dispose();
    _websiteController.dispose();
    _termsController.dispose();
    _invoicePrefixController.dispose();
    _startingSeqController.dispose();
    super.dispose();
  }

  Future<void> _pickCustomLogo() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      );

      if (result.isNotEmpty && result.first.path != null) {
        setState(() {
          _customLogoPath = result.first.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not pick image: $e')));
      }
    }
  }

  void _resetToDefaultLogo() {
    setState(() {
      _customLogoPath = null;
    });
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final startingSeq = int.tryParse(_startingSeqController.text.trim()) ?? 1;
      final newSettings = CompanySettings(
        companyName: _companyNameController.text.trim(),
        companySubtitle: _subtitleController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        email: _emailController.text.trim(),
        gstNumber: _gstController.text.trim(),
        website: _websiteController.text.trim(),
        termsAndConditions: _termsController.text.trim(),
        invoicePrefix: _invoicePrefixController.text.trim().toUpperCase(),
        startingInvoiceNumber: startingSeq,
        financialYear:
            ref.read(settingsProvider).value?.financialYear ?? '26-27',
        customLogoPath: _customLogoPath,
      );

      await ref.read(settingsProvider.notifier).updateSettings(newSettings);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save settings: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Settings & Company Info'),
      ),
      body: SafeArea(
        top: false,
        child: settingsAsync.when(
          data: (settings) {
            _populate(settings);
            return Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Logo & Watermark Settings
                  _buildCard(
                    title: 'Company Logo & Watermark',
                    icon: Icons.image_outlined,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: LogoWidget(
                                size: 90,
                                customPath: _customLogoPath,
                              ),
                            ),

                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.upload_file, size: 16),
                                  label: const Text('Change Logo'),
                                  onPressed: _pickCustomLogo,
                                ),
                                if (_customLogoPath != null) ...[
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    icon: const Icon(
                                      Icons.restore,
                                      size: 16,
                                      color: AppColors.unpaidRed,
                                    ),
                                    label: const Text(
                                      'Reset Logo',
                                      style: TextStyle(
                                        color: AppColors.unpaidRed,
                                      ),
                                    ),
                                    onPressed: _resetToDefaultLogo,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'This logo is automatically placed in invoice headers and as a subtle watermark in bills & generated PDFs.',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Company Details
                  _buildCard(
                    title: 'Business Information',
                    icon: Icons.business_outlined,
                    children: [
                      TextFormField(
                        controller: _companyNameController,
                        decoration: const InputDecoration(
                          labelText: 'Business / Company Name *',
                          hintText: 'e.g. MIGHTY',
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Company name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _subtitleController,
                        decoration: const InputDecoration(
                          labelText: 'Subtitle / Tagline',
                          hintText: 'e.g. INTERLOCKS / HOLLOW BLOCKS',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Business Mobile Number *',
                          hintText: '+91 98765 43210',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Mobile number is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                          labelText: 'Factory / Yard Address',
                          hintText: 'Industrial Area, Bypass Road, Main Gate',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _gstController,
                              decoration: const InputDecoration(
                                labelText: 'GSTIN Number',
                                hintText: '32AAAAA0000A1Z5',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: 'Email Address',
                                hintText: 'contact@mighty.com',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Invoice Configuration
                  _buildCard(
                    title: 'Invoice & Numbering Settings',
                    icon: Icons.receipt_long_outlined,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _invoicePrefixController,
                              decoration: const InputDecoration(
                                labelText: 'Invoice Prefix',
                                hintText: 'INV',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _startingSeqController,
                              decoration: const InputDecoration(
                                labelText: 'Starting Number',
                                hintText: '1',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 18,
                              color: AppColors.accent,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Sample next invoice: ${_invoicePrefixController.text.trim().toUpperCase()}/${FinancialYearUtil.getFinancialYear()}/${(_startingSeqController.text.trim().padLeft(4, "0"))}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _termsController,
                        decoration: const InputDecoration(
                          labelText: 'Default Terms & Conditions',
                          hintText: 'Goods once sold will not be taken back.',
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  PrimaryButton(
                    label: 'Save Configuration',
                    icon: Icons.save_outlined,
                    isLoading: _isSaving,
                    onPressed: _saveSettings,
                  ),
                  const SizedBox(height: 24),

                  // Data Management (Production Readiness)
                  _buildCard(
                    title: 'Data & Maintenance',
                    icon: Icons.cleaning_services_outlined,
                    children: [
                      const Text(
                        'Prepare app for live production by clearing any initial test data or transactions.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(
                                Icons.receipt_long,
                                size: 16,
                                color: AppColors.unpaidRed,
                              ),
                              label: const Text(
                                'Clear Bills',
                                style: TextStyle(
                                  color: AppColors.unpaidRed,
                                  fontSize: 13,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: AppColors.unpaidRed.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                              ),
                              onPressed: _confirmClearInvoices,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(
                                Icons.people_outline,
                                size: 16,
                                color: AppColors.unpaidRed,
                              ),
                              label: const Text(
                                'Clear Customers',
                                style: TextStyle(
                                  color: AppColors.unpaidRed,
                                  fontSize: 13,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: AppColors.unpaidRed.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                              ),
                              onPressed: _confirmClearCustomers,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(
                                Icons.inventory_2_outlined,
                                size: 16,
                                color: AppColors.unpaidRed,
                              ),
                              label: const Text(
                                'Clear Products',
                                style: TextStyle(
                                  color: AppColors.unpaidRed,
                                  fontSize: 13,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: AppColors.unpaidRed.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                              ),
                              onPressed: _confirmClearProducts,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(
                                Icons.delete_sweep_outlined,
                                size: 16,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Purge Test Data',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.unpaidRed,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                              ),
                              onPressed: _confirmPurgeTestData,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClearInvoices() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Bills?'),
        content: const Text(
          'This will permanently remove all bills/draft bills and reset dashboard metrics to zero for production. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.unpaidRed,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Clear All Bills',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final invoiceRepo = ref.read(invoiceRepositoryProvider);
      await invoiceRepo.deleteAllInvoices();
      ref.invalidate(invoicesProvider);
      ref.invalidate(dashboardMetricsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'All bills cleared. Ready for fresh production entries!',
            ),
          ),
        );
      }
    }
  }

  Future<void> _confirmClearCustomers() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Customers?'),
        content: const Text(
          'This will remove all saved customer records from the directory. Invoices already created will keep their customer details snapshot.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.unpaidRed,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Clear Customers',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final customerRepo = ref.read(customerRepositoryProvider);
      await customerRepo.deleteAllCustomers();
      ref.invalidate(customersProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer directory cleared.')),
        );
      }
    }
  }

  Future<void> _confirmClearProducts() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Products?'),
        content: const Text(
          'This will permanently remove all product items from your catalog. Previously generated invoices will retain their product snapshot data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.unpaidRed,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Clear Products',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final productRepo = ref.read(productRepositoryProvider);
      await productRepo.deleteAllProducts();
      ref.invalidate(productsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product catalog cleared.')),
        );
      }
    }
  }

  Future<void> _confirmPurgeTestData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Purge All Test Data?'),
        content: const Text(
          'This will immediately remove demo masonry products and sample customer accounts from both local storage and cloud database.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.unpaidRed,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Purge Test Data',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await FirebaseMigrationService.purgeTestData();
      ref.invalidate(productsProvider);
      ref.invalidate(customersProvider);
      ref.invalidate(invoicesProvider);
      ref.invalidate(dashboardMetricsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Test data purged successfully. Ready for live business use!',
            ),
          ),
        );
      }
    }
  }
}
