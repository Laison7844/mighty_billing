import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'invoice_item.dart';
import 'additional_charge.dart';

enum PaymentStatus {
  paid('PAID'),
  partiallyPaid('PARTIALLY PAID'),
  unpaid('UNPAID');

  final String label;
  const PaymentStatus(this.label);
}

class Invoice {
  final String id;
  final String invoiceNumber;
  final String? customerId;
  final String customerNameSnapshot;
  final String customerPhoneSnapshot;
  final String customerAddressSnapshot;
  final String? customerGstNumberSnapshot;
  final DateTime date;
  final List<InvoiceItem> items;
  final List<AdditionalCharge> additionalCharges;
  final double subtotal;
  final double total;
  final double paidAmount;
  final double balanceDue;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Invoice({
    required this.id,
    required this.invoiceNumber,
    this.customerId,
    required this.customerNameSnapshot,
    this.customerPhoneSnapshot = '',
    this.customerAddressSnapshot = '',
    this.customerGstNumberSnapshot,
    required this.date,
    required this.items,
    required this.additionalCharges,
    required this.subtotal,
    required this.total,
    required this.paidAmount,
    required this.balanceDue,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  PaymentStatus get paymentStatus {
    if (balanceDue <= 0.005) {
      return PaymentStatus.paid;
    } else if (paidAmount > 0.005 && balanceDue > 0.005) {
      return PaymentStatus.partiallyPaid;
    } else {
      return PaymentStatus.unpaid;
    }
  }

  double get additionalChargesTotal {
    return additionalCharges.fold(0.0, (total, item) => total + item.amount);
  }

  Invoice copyWith({
    String? id,
    String? invoiceNumber,
    String? customerId,
    String? customerNameSnapshot,
    String? customerPhoneSnapshot,
    String? customerAddressSnapshot,
    String? customerGstNumberSnapshot,
    bool clearGstSnapshot = false,
    DateTime? date,
    List<InvoiceItem>? items,
    List<AdditionalCharge>? additionalCharges,
    double? subtotal,
    double? total,
    double? paidAmount,
    double? balanceDue,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Invoice(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      customerId: customerId ?? this.customerId,
      customerNameSnapshot: customerNameSnapshot ?? this.customerNameSnapshot,
      customerPhoneSnapshot: customerPhoneSnapshot ?? this.customerPhoneSnapshot,
      customerAddressSnapshot: customerAddressSnapshot ?? this.customerAddressSnapshot,
      customerGstNumberSnapshot: clearGstSnapshot
          ? null
          : (customerGstNumberSnapshot ?? this.customerGstNumberSnapshot),
      date: date ?? this.date,
      items: items ?? this.items,
      additionalCharges: additionalCharges ?? this.additionalCharges,
      subtotal: subtotal ?? this.subtotal,
      total: total ?? this.total,
      paidAmount: paidAmount ?? this.paidAmount,
      balanceDue: balanceDue ?? this.balanceDue,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoiceNumber': invoiceNumber,
      'customerId': customerId,
      'customerNameSnapshot': customerNameSnapshot,
      'customerPhoneSnapshot': customerPhoneSnapshot,
      'customerAddressSnapshot': customerAddressSnapshot,
      if (customerGstNumberSnapshot != null && customerGstNumberSnapshot!.trim().isNotEmpty)
        'customerGstNumberSnapshot': customerGstNumberSnapshot!.trim().toUpperCase(),
      'date': date.toIso8601String(),
      'itemsJson': jsonEncode(items.map((i) => i.toMap()).toList()),
      'chargesJson': jsonEncode(additionalCharges.map((c) => c.toMap()).toList()),
      'subtotal': subtotal,
      'total': total,
      'paidAmount': paidAmount,
      'balanceDue': balanceDue,
      'notes': notes,
      'paymentStatus': paymentStatus.label,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'invoiceNumber': invoiceNumber,
      'customerId': customerId,
      'customerNameSnapshot': customerNameSnapshot,
      'customerPhoneSnapshot': customerPhoneSnapshot,
      'customerAddressSnapshot': customerAddressSnapshot,
      if (customerGstNumberSnapshot != null && customerGstNumberSnapshot!.trim().isNotEmpty)
        'customerGstNumberSnapshot': customerGstNumberSnapshot!.trim().toUpperCase(),
      'date': Timestamp.fromDate(date),
      'items': items.map((i) => i.toMap()).toList(),
      'additionalCharges': additionalCharges.map((c) => c.toMap()).toList(),
      'subtotal': subtotal,
      'total': total,
      'paidAmount': paidAmount,
      'balanceDue': balanceDue,
      'notes': notes,
      'paymentStatus': paymentStatus.label,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory Invoice.fromMap(Map<String, dynamic> map) {
    List<InvoiceItem> parsedItems = [];
    if (map['items'] is List) {
      parsedItems = (map['items'] as List)
          .map((e) => InvoiceItem.fromMap(e as Map<String, dynamic>))
          .toList();
    } else if (map['itemsJson'] != null && map['itemsJson'] is String) {
      final decoded = jsonDecode(map['itemsJson'] as String) as List<dynamic>;
      parsedItems = decoded.map((e) => InvoiceItem.fromMap(e as Map<String, dynamic>)).toList();
    }

    List<AdditionalCharge> parsedCharges = [];
    if (map['additionalCharges'] is List) {
      parsedCharges = (map['additionalCharges'] as List)
          .map((e) => AdditionalCharge.fromMap(e as Map<String, dynamic>))
          .toList();
    } else if (map['chargesJson'] != null && map['chargesJson'] is String) {
      final decoded = jsonDecode(map['chargesJson'] as String) as List<dynamic>;
      parsedCharges = decoded.map((e) => AdditionalCharge.fromMap(e as Map<String, dynamic>)).toList();
    }

    return Invoice(
      id: map['id'] as String,
      invoiceNumber: map['invoiceNumber'] as String,
      customerId: map['customerId'] as String?,
      customerNameSnapshot: map['customerNameSnapshot'] as String,
      customerPhoneSnapshot: (map['customerPhoneSnapshot'] as String?) ?? '',
      customerAddressSnapshot: (map['customerAddressSnapshot'] as String?) ?? '',
      customerGstNumberSnapshot: (map['customerGstNumberSnapshot'] as String?)?.trim(),
      date: map['date'] is Timestamp
          ? (map['date'] as Timestamp).toDate()
          : DateTime.parse(map['date'] as String),
      items: parsedItems,
      additionalCharges: parsedCharges,
      subtotal: (map['subtotal'] as num).toDouble(),
      total: (map['total'] as num).toDouble(),
      paidAmount: (map['paidAmount'] as num).toDouble(),
      balanceDue: (map['balanceDue'] as num).toDouble(),
      notes: (map['notes'] as String?) ?? '',
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.parse(map['updatedAt'] as String),
    );
  }

  factory Invoice.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final map = Map<String, dynamic>.from(data);
    map['id'] = (data['id'] as String?) ?? doc.id;
    return Invoice.fromMap(map);
  }
}
