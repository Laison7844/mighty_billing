import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/config/company_config.dart';
import '../../core/utils/financial_year_util.dart';
import '../../models/invoice.dart';

enum InvoiceSortOption {
  newest,
  oldest,
  highestAmount,
}

class InvoiceRepository {
  CollectionReference<Map<String, dynamic>> get _collection =>
      CompanyConfig.invoicesCollection();

  Future<List<Invoice>> getAllInvoices({
    String? searchQuery,
    PaymentStatus? statusFilter,
    InvoiceSortOption sortOption = InvoiceSortOption.newest,
  }) async {
    try {
      final snapshot = await _collection.get();
      List<Invoice> invoices = snapshot.docs
          .map((doc) => Invoice.fromFirestore(doc))
          .toList();

      // Search filter
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
        invoices = invoices.where((inv) {
          final numberMatch = inv.invoiceNumber.toLowerCase().contains(q);
          final nameMatch = inv.customerNameSnapshot.toLowerCase().contains(q);
          final phoneMatch = inv.customerPhoneSnapshot.toLowerCase().contains(q);
          final gstMatch = (inv.customerGstNumberSnapshot ?? '').toLowerCase().contains(q);
          return numberMatch || nameMatch || phoneMatch || gstMatch;
        }).toList();
      }

      // Status filter
      if (statusFilter != null) {
        invoices = invoices.where((inv) => inv.paymentStatus == statusFilter).toList();
      }

      // Sorting
      switch (sortOption) {
        case InvoiceSortOption.newest:
          invoices.sort((a, b) {
            final cmp = b.date.compareTo(a.date);
            if (cmp != 0) return cmp;
            return b.createdAt.compareTo(a.createdAt);
          });
          break;
        case InvoiceSortOption.oldest:
          invoices.sort((a, b) {
            final cmp = a.date.compareTo(b.date);
            if (cmp != 0) return cmp;
            return a.createdAt.compareTo(b.createdAt);
          });
          break;
        case InvoiceSortOption.highestAmount:
          invoices.sort((a, b) => b.total.compareTo(a.total));
          break;
      }

      return invoices;
    } catch (e) {
      return [];
    }
  }

  Future<List<Invoice>> getInvoicesByCustomerId(String customerId) async {
    try {
      final snapshot = await _collection
          .where('customerId', isEqualTo: customerId)
          .get();

      final invoices = snapshot.docs
          .map((doc) => Invoice.fromFirestore(doc))
          .toList();

      invoices.sort((a, b) {
        final cmp = b.date.compareTo(a.date);
        if (cmp != 0) return cmp;
        return b.createdAt.compareTo(a.createdAt);
      });

      return invoices;
    } catch (e) {
      return [];
    }
  }

  Future<Invoice?> getInvoiceById(String id) async {
    try {
      final doc = await _collection.doc(id).get();
      if (!doc.exists) return null;
      return Invoice.fromFirestore(doc);
    } catch (e) {
      return null;
    }
  }

  Future<Invoice> saveInvoice(Invoice invoice) async {
    await _collection.doc(invoice.id).set(
      invoice.toFirestore(),
      SetOptions(merge: true),
    );
    return invoice;
  }

  Future<void> updateInvoice(Invoice invoice) async {
    await _collection.doc(invoice.id).set(
      invoice.toFirestore(),
      SetOptions(merge: true),
    );
  }

  Future<void> deleteInvoice(String id) async {
    await _collection.doc(id).delete();
  }

  Future<void> deleteAllInvoices() async {
    final snapshot = await _collection.get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// Automatically generates the next unique invoice number using a safe Firestore transaction
  Future<String> getNextInvoiceNumber({
    String prefix = 'INV',
    String? financialYear,
    int startingSequence = 1,
  }) async {
    final fy = financialYear ?? FinancialYearUtil.getFinancialYear();
    final cleanPrefix = prefix.trim().toUpperCase();
    final counterRef = CompanyConfig.invoiceCounterDoc();

    int nextSeq = startingSequence;

    try {
      nextSeq = await FirebaseFirestore.instance.runTransaction<int>((transaction) async {
        final snapshot = await transaction.get(counterRef);
        if (!snapshot.exists) {
          final initialSeq = startingSequence;
          transaction.set(counterRef, {
            'currentNumber': initialSeq,
            'financialYear': fy,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          return initialSeq;
        }

        final data = snapshot.data();
        final storedFy = data?['financialYear'] as String? ?? fy;
        final currentNumber = (data?['currentNumber'] as num?)?.toInt() ?? 0;

        int calcSeq;
        if (storedFy != fy) {
          // New financial year - reset counter to starting sequence
          calcSeq = startingSequence;
        } else {
          calcSeq = currentNumber < (startingSequence - 1)
              ? startingSequence
              : currentNumber + 1;
        }

        transaction.set(counterRef, {
          'currentNumber': calcSeq,
          'financialYear': fy,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        return calcSeq;
      });
    } catch (e) {
      // Offline or network fallback: inspect cached counter or highest invoice in cache
      try {
        final doc = await counterRef.get(const GetOptions(source: Source.cache));
        int currentNumber = 0;
        if (doc.exists) {
          currentNumber = (doc.data()?['currentNumber'] as num?)?.toInt() ?? 0;
        }
        nextSeq = currentNumber < (startingSequence - 1)
            ? startingSequence
            : currentNumber + 1;
        // Attempt local cache update
        await counterRef.set({
          'currentNumber': nextSeq,
          'financialYear': fy,
          'updatedAt': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true));
      } catch (_) {
        nextSeq = startingSequence;
      }
    }

    return FinancialYearUtil.formatInvoiceNumber(
      prefix: cleanPrefix,
      financialYear: fy,
      sequenceNumber: nextSeq,
    );
  }

  /// Dashboard metrics
  Future<Map<String, dynamic>> getDashboardMetrics() async {
    final allInvoices = await getAllInvoices();
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);

    double totalOutstanding = 0;
    double todaySales = 0;
    int todayBillsCount = 0;

    for (final inv in allInvoices) {
      totalOutstanding += inv.balanceDue;
      if (inv.date.isAfter(startOfToday.subtract(const Duration(seconds: 1))) &&
          inv.date.isBefore(endOfToday.add(const Duration(seconds: 1)))) {
        todaySales += inv.total;
        todayBillsCount++;
      }
    }

    // Sort newest first for recent invoices
    final sortedInvoices = List<Invoice>.from(allInvoices)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final recentInvoices = sortedInvoices.take(5).toList();

    return {
      'totalBills': allInvoices.length,
      'todayBills': todayBillsCount,
      'todaySales': todaySales,
      'totalOutstanding': totalOutstanding,
      'recentInvoices': recentInvoices,
    };
  }
}
