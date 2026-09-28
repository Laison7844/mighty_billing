import 'package:sqflite/sqflite.dart';
import '../../core/utils/financial_year_util.dart';
import '../../models/invoice.dart';
import '../database/app_database.dart';

enum InvoiceSortOption {
  newest,
  oldest,
  highestAmount,
}

class InvoiceRepository {
  final AppDatabase dbProvider;

  InvoiceRepository({AppDatabase? dbProvider})
      : dbProvider = dbProvider ?? AppDatabase.instance;

  Future<List<Invoice>> getAllInvoices({
    String? searchQuery,
    PaymentStatus? statusFilter,
    InvoiceSortOption sortOption = InvoiceSortOption.newest,
  }) async {
    final db = await dbProvider.database;
    String orderBy;
    switch (sortOption) {
      case InvoiceSortOption.newest:
        orderBy = 'date DESC, createdAt DESC';
        break;
      case InvoiceSortOption.oldest:
        orderBy = 'date ASC, createdAt ASC';
        break;
      case InvoiceSortOption.highestAmount:
        orderBy = 'total DESC';
        break;
    }

    List<Map<String, dynamic>> results;
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = '%${searchQuery.trim()}%';
      results = await db.query(
        'invoices',
        where: 'invoiceNumber LIKE ? OR customerNameSnapshot LIKE ? OR customerPhoneSnapshot LIKE ?',
        whereArgs: [q, q, q],
        orderBy: orderBy,
      );
    } else {
      results = await db.query('invoices', orderBy: orderBy);
    }

    final invoices = results.map((map) => Invoice.fromMap(map)).toList();

    if (statusFilter != null) {
      return invoices.where((inv) => inv.paymentStatus == statusFilter).toList();
    }

    return invoices;
  }

  Future<List<Invoice>> getInvoicesByCustomerId(String customerId) async {
    final db = await dbProvider.database;
    final results = await db.query(
      'invoices',
      where: 'customerId = ?',
      whereArgs: [customerId],
      orderBy: 'date DESC, createdAt DESC',
    );
    return results.map((map) => Invoice.fromMap(map)).toList();
  }

  Future<Invoice?> getInvoiceById(String id) async {
    final db = await dbProvider.database;
    final results = await db.query('invoices', where: 'id = ?', whereArgs: [id]);
    if (results.isEmpty) return null;
    return Invoice.fromMap(results.first);
  }

  Future<Invoice> saveInvoice(Invoice invoice) async {
    final db = await dbProvider.database;
    await db.insert(
      'invoices',
      invoice.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return invoice;
  }

  Future<void> updateInvoice(Invoice invoice) async {
    final db = await dbProvider.database;
    await db.update(
      'invoices',
      invoice.toMap(),
      where: 'id = ?',
      whereArgs: [invoice.id],
    );
  }

  Future<void> deleteInvoice(String id) async {
    final db = await dbProvider.database;
    await db.delete('invoices', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAllInvoices() async {
    final db = await dbProvider.database;
    await db.delete('invoices');
  }

  /// Automatically generates the next unique invoice number for the given financial year and prefix
  Future<String> getNextInvoiceNumber({
    String prefix = 'INV',
    String? financialYear,
    int startingSequence = 1,
  }) async {
    final db = await dbProvider.database;
    final fy = financialYear ?? FinancialYearUtil.getFinancialYear();
    final cleanPrefix = prefix.trim().toUpperCase();
    final searchPattern = '$cleanPrefix/$fy/%';

    final results = await db.query(
      'invoices',
      columns: ['invoiceNumber'],
      where: 'invoiceNumber LIKE ?',
      whereArgs: [searchPattern],
    );

    int maxSeq = startingSequence - 1;
    for (final row in results) {
      final invNum = row['invoiceNumber'] as String? ?? '';
      final parts = invNum.split('/');
      if (parts.length >= 3) {
        final seqPart = int.tryParse(parts.last);
        if (seqPart != null && seqPart > maxSeq) {
          maxSeq = seqPart;
        }
      }
    }

    final nextSeq = maxSeq + 1;
    return FinancialYearUtil.formatInvoiceNumber(
      prefix: cleanPrefix,
      financialYear: fy,
      sequenceNumber: nextSeq,
    );
  }

  /// Dashboard metrics
  Future<Map<String, dynamic>> getDashboardMetrics() async {
    final db = await dbProvider.database;
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day).toIso8601String();
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

    // Total bills count & total outstanding
    final allInvoicesRaw = await db.query('invoices');
    final allInvoices = allInvoicesRaw.map((e) => Invoice.fromMap(e)).toList();

    double totalOutstanding = 0;
    double todaySales = 0;
    int todayBillsCount = 0;

    for (final inv in allInvoices) {
      totalOutstanding += inv.balanceDue;
      final invDateStr = inv.date.toIso8601String();
      if (invDateStr.compareTo(startOfToday) >= 0 && invDateStr.compareTo(endOfToday) <= 0) {
        todaySales += inv.total;
        todayBillsCount++;
      }
    }

    // Recent invoices (up to 5)
    final recentInvoicesRaw = await db.query(
      'invoices',
      orderBy: 'createdAt DESC',
      limit: 5,
    );
    final recentInvoices = recentInvoicesRaw.map((e) => Invoice.fromMap(e)).toList();

    return {
      'totalBills': allInvoices.length,
      'todayBills': todayBillsCount,
      'todaySales': todaySales,
      'totalOutstanding': totalOutstanding,
      'recentInvoices': recentInvoices,
    };
  }
}
