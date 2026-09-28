import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../models/customer.dart';
import '../../widgets/empty_state_view.dart';
import 'customer_detail_screen.dart';
import 'customer_form_dialog.dart';

class CustomerListScreen extends ConsumerWidget {
  const CustomerListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(customersProvider);
    final searchQuery = ref.watch(customerSearchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_customer_list',
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1),
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
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Customer ${newCustomer.name} added')),
              );
            }
          }
        },
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search customers by name, phone, site...',
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          ref.read(customerSearchQueryProvider.notifier).state = '';
                        },
                      )
                    : null,
              ),
              onChanged: (val) {
                ref.read(customerSearchQueryProvider.notifier).state = val;
              },
            ),
          ),

          // List
          Expanded(
            child: customersAsync.when(
              data: (customers) {
                if (customers.isEmpty) {
                  return EmptyStateView(
                    icon: Icons.people_outline,
                    title: searchQuery.isNotEmpty ? 'No customers found' : 'No customers yet',
                    message: searchQuery.isNotEmpty
                        ? 'Try searching with a different name or phone number.'
                        : 'Add your first customer to get started with billing.',
                    buttonLabel: searchQuery.isEmpty ? 'Add Customer' : null,
                    onButtonPressed: searchQuery.isEmpty
                        ? () async {
                            final newCustomer = await showDialog<Customer>(
                              context: context,
                              builder: (context) => const CustomerFormDialog(),
                            );
                            if (newCustomer != null) {
                              final repo = ref.read(customerRepositoryProvider);
                              await repo.saveCustomer(newCustomer);
                              ref.invalidate(customersProvider);
                            }
                          }
                        : null,
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: customers.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final customer = customers[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.accentContainer,
                          child: Text(
                            customer.name.isNotEmpty ? customer.name[0].toUpperCase() : 'C',
                            style: const TextStyle(
                              color: AppColors.onAccentContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          customer.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (customer.phone.isNotEmpty)
                              Text(customer.phone, style: const TextStyle(fontSize: 12)),
                            if (customer.address.isNotEmpty)
                              Text(
                                customer.address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => CustomerDetailScreen(customer: customer),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }
}
