import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_colors.dart';
import '../../models/product.dart';

class ProductFormDialog extends StatefulWidget {
  final Product? product;

  const ProductFormDialog({super.key, this.product});

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _rateController;
  late String _selectedUnit;

  final List<String> _units = ['Nos', 'Pcs', 'Sq.Ft', 'Trips', 'Bags', 'Ton', 'Kg'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _rateController = TextEditingController(
      text: widget.product != null ? widget.product!.defaultRate.toStringAsFixed(2) : '',
    );
    _selectedUnit = widget.product?.unit ?? 'Nos';
    if (!_units.contains(_selectedUnit)) {
      _units.insert(0, _selectedUnit);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final rate = double.tryParse(_rateController.text.trim()) ?? 0.0;
    final now = DateTime.now();

    final product = Product(
      id: widget.product?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      unit: _selectedUnit,
      defaultRate: rate,
      createdAt: widget.product?.createdAt ?? now,
      updatedAt: now,
    );

    Navigator.of(context).pop(product);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Product' : 'Add New Product'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Product Name *',
                  hintText: 'e.g. 4 inch Block, 6 inch Block',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Product name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: TextFormField(
                      controller: _rateController,
                      decoration: const InputDecoration(
                        labelText: 'Default Rate (₹) *',
                        hintText: 'e.g. 34',
                        prefixText: '₹ ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Rate required';
                        }
                        final parsed = double.tryParse(val.trim());
                        if (parsed == null || parsed < 0) {
                          return 'Invalid rate';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 4,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedUnit,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                      ),
                      items: _units.map((u) {
                        return DropdownMenuItem(value: u, child: Text(u));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedUnit = val;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(isEditing ? 'Save Changes' : 'Add Product'),
        ),
      ],
    );
  }
}
