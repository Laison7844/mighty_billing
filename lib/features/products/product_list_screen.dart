import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../models/product.dart';
import '../../widgets/empty_state_view.dart';
import '../../widgets/money_text.dart';
import 'product_form_dialog.dart';

class ProductListScreen extends ConsumerWidget {
  const ProductListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);
    final searchQuery = ref.watch(productSearchQueryProvider);

    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const Text('Products & Rates')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_product_list',
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Product'),
        onPressed: () async {
          final newProduct = await showDialog<Product>(
            context: context,
            builder: (context) => const ProductFormDialog(),
          );
          if (newProduct != null) {
            final repo = ref.read(productRepositoryProvider);
            await repo.saveProduct(newProduct);
            ref.invalidate(productsProvider);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Product ${newProduct.name} added')),
              );
            }
          }
        },
      ),
      body: SafeArea(
        top: false,
        child: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search products by name or unit...',
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.textSecondary,
                ),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          ref.read(productSearchQueryProvider.notifier).state =
                              '';
                        },
                      )
                    : null,
              ),
              onChanged: (val) {
                ref.read(productSearchQueryProvider.notifier).state = val;
              },
            ),
          ),

          // List
          Expanded(
            child: productsAsync.when(
              data: (products) {
                if (products.isEmpty) {
                  return EmptyStateView(
                    icon: Icons.inventory_2_outlined,
                    title: searchQuery.isNotEmpty
                        ? 'No products found'
                        : 'No products yet',
                    message: searchQuery.isNotEmpty
                        ? 'Try searching with a different product name.'
                        : 'Add hollow blocks, interlocks, or custom materials.',
                    buttonLabel: searchQuery.isEmpty ? 'Add Product' : null,
                    onButtonPressed: searchQuery.isEmpty
                        ? () async {
                            final newProduct = await showDialog<Product>(
                              context: context,
                              builder: (context) => const ProductFormDialog(),
                            );
                            if (newProduct != null) {
                              final repo = ref.read(productRepositoryProvider);
                              await repo.saveProduct(newProduct);
                              ref.invalidate(productsProvider);
                            }
                          }
                        : null,
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: products.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return Card(
                      child: ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.view_in_ar_rounded,
                            color: AppColors.accent,
                            size: 24,
                          ),
                        ),
                        title: Text(
                          product.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          'Unit: ${product.unit}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'Default Rate',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                MoneyText(
                                  amount: product.defaultRate,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(
                                Icons.more_vert,
                                color: AppColors.textSecondary,
                              ),
                              onSelected: (action) async {
                                if (action == 'edit') {
                                  final updated = await showDialog<Product>(
                                    context: context,
                                    builder: (context) =>
                                        ProductFormDialog(product: product),
                                  );
                                  if (updated != null) {
                                    final repo = ref.read(
                                      productRepositoryProvider,
                                    );
                                    await repo.updateProduct(updated);
                                    ref.invalidate(productsProvider);
                                  }
                                } else if (action == 'delete') {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Delete Product?'),
                                      content: Text(
                                        'Are you sure you want to delete ${product.name}? Old invoices will not be affected.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(false),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                AppColors.unpaidRed,
                                          ),
                                          onPressed: () =>
                                              Navigator.of(context).pop(true),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    final repo = ref.read(
                                      productRepositoryProvider,
                                    );
                                    await repo.deleteProduct(product.id);
                                    ref.invalidate(productsProvider);
                                  }
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_outlined, size: 18),
                                      SizedBox(width: 8),
                                      Text('Edit'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                        color: AppColors.unpaidRed,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Delete',
                                        style: TextStyle(
                                          color: AppColors.unpaidRed,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
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
    ),
  );
  }
}
