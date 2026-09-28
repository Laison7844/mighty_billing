import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/invoice_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../models/company_settings.dart';
import '../../models/customer.dart';
import '../../models/product.dart';
import '../../models/invoice.dart';

// Repository Providers
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository();
});

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository();
});

final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) {
  return InvoiceRepository();
});

// Settings Notifier
class SettingsNotifier extends AsyncNotifier<CompanySettings> {
  @override
  Future<CompanySettings> build() async {
    final repo = ref.watch(settingsRepositoryProvider);
    return repo.loadSettings();
  }

  Future<void> updateSettings(CompanySettings newSettings) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.saveSettings(newSettings);
    state = AsyncData(newSettings);
  }
}

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, CompanySettings>(SettingsNotifier.new);

// Customer Search Notifier
class CustomerSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  @override
  set state(String value) => super.state = value;
}

final customerSearchQueryProvider = NotifierProvider<CustomerSearchQueryNotifier, String>(CustomerSearchQueryNotifier.new);

final customersProvider = FutureProvider<List<Customer>>((ref) async {
  final query = ref.watch(customerSearchQueryProvider);
  final repo = ref.watch(customerRepositoryProvider);
  return repo.getAllCustomers(searchQuery: query);
});

// Product Search Notifier
class ProductSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  @override
  set state(String value) => super.state = value;
}

final productSearchQueryProvider = NotifierProvider<ProductSearchQueryNotifier, String>(ProductSearchQueryNotifier.new);

final productsProvider = FutureProvider<List<Product>>((ref) async {
  final query = ref.watch(productSearchQueryProvider);
  final repo = ref.watch(productRepositoryProvider);
  return repo.getAllProducts(searchQuery: query);
});

// Invoice Filter & Sort Notifiers
class InvoiceSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  @override
  set state(String value) => super.state = value;
}

final invoiceSearchQueryProvider = NotifierProvider<InvoiceSearchQueryNotifier, String>(InvoiceSearchQueryNotifier.new);

class InvoiceStatusFilterNotifier extends Notifier<PaymentStatus?> {
  @override
  PaymentStatus? build() => null;
  @override
  set state(PaymentStatus? value) => super.state = value;
}

final invoiceStatusFilterProvider = NotifierProvider<InvoiceStatusFilterNotifier, PaymentStatus?>(InvoiceStatusFilterNotifier.new);

class InvoiceSortOptionNotifier extends Notifier<InvoiceSortOption> {
  @override
  InvoiceSortOption build() => InvoiceSortOption.newest;
  @override
  set state(InvoiceSortOption value) => super.state = value;
}

final invoiceSortOptionProvider = NotifierProvider<InvoiceSortOptionNotifier, InvoiceSortOption>(InvoiceSortOptionNotifier.new);

final invoicesProvider = FutureProvider<List<Invoice>>((ref) async {
  final query = ref.watch(invoiceSearchQueryProvider);
  final status = ref.watch(invoiceStatusFilterProvider);
  final sort = ref.watch(invoiceSortOptionProvider);
  final repo = ref.watch(invoiceRepositoryProvider);
  return repo.getAllInvoices(
    searchQuery: query,
    statusFilter: status,
    sortOption: sort,
  );
});

// Dashboard Metrics Provider
final dashboardMetricsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  // We watch invoicesProvider so whenever invoices change, dashboard updates automatically
  ref.watch(invoicesProvider);
  final repo = ref.watch(invoiceRepositoryProvider);
  return repo.getDashboardMetrics();
});
