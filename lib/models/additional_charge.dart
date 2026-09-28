class AdditionalCharge {
  final String name;
  final double amount;

  const AdditionalCharge({
    required this.name,
    required this.amount,
  });

  AdditionalCharge copyWith({
    String? name,
    double? amount,
  }) {
    return AdditionalCharge(
      name: name ?? this.name,
      amount: amount ?? this.amount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'amount': amount,
    };
  }

  factory AdditionalCharge.fromMap(Map<String, dynamic> map) {
    return AdditionalCharge(
      name: map['name'] as String,
      amount: (map['amount'] as num).toDouble(),
    );
  }
}
