class InvoiceItem {
  final String? productId;
  final String productNameSnapshot;
  final double quantity;
  final String unit;
  final double rate;
  final double amount;

  const InvoiceItem({
    this.productId,
    required this.productNameSnapshot,
    required this.quantity,
    this.unit = 'Nos',
    required this.rate,
    required this.amount,
  });

  InvoiceItem copyWith({
    String? productId,
    String? productNameSnapshot,
    double? quantity,
    String? unit,
    double? rate,
    double? amount,
  }) {
    return InvoiceItem(
      productId: productId ?? this.productId,
      productNameSnapshot: productNameSnapshot ?? this.productNameSnapshot,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      rate: rate ?? this.rate,
      amount: amount ?? this.amount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productNameSnapshot': productNameSnapshot,
      'quantity': quantity,
      'unit': unit,
      'rate': rate,
      'amount': amount,
    };
  }

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      productId: map['productId'] as String?,
      productNameSnapshot: map['productNameSnapshot'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      unit: (map['unit'] as String?) ?? 'Nos',
      rate: (map['rate'] as num).toDouble(),
      amount: (map['amount'] as num).toDouble(),
    );
  }
}
