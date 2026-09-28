import 'package:sqflite/sqflite.dart';
import '../../models/customer.dart';
import '../database/app_database.dart';

class CustomerRepository {
  final AppDatabase dbProvider;

  CustomerRepository({AppDatabase? dbProvider})
      : dbProvider = dbProvider ?? AppDatabase.instance;

  Future<List<Customer>> getAllCustomers({String? searchQuery}) async {
    final db = await dbProvider.database;
    List<Map<String, dynamic>> results;

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final query = '%${searchQuery.trim()}%';
      results = await db.query(
        'customers',
        where: 'name LIKE ? OR phone LIKE ? OR address LIKE ?',
        whereArgs: [query, query, query],
        orderBy: 'name ASC',
      );
    } else {
      results = await db.query('customers', orderBy: 'name ASC');
    }

    return results.map((map) => Customer.fromMap(map)).toList();
  }

  Future<Customer?> getCustomerById(String id) async {
    final db = await dbProvider.database;
    final results = await db.query('customers', where: 'id = ?', whereArgs: [id]);
    if (results.isEmpty) return null;
    return Customer.fromMap(results.first);
  }

  Future<Customer> saveCustomer(Customer customer) async {
    final db = await dbProvider.database;
    await db.insert(
      'customers',
      customer.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return customer;
  }

  Future<void> updateCustomer(Customer customer) async {
    final db = await dbProvider.database;
    await db.update(
      'customers',
      customer.toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  Future<void> deleteCustomer(String id) async {
    final db = await dbProvider.database;
    await db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAllCustomers() async {
    final db = await dbProvider.database;
    await db.delete('customers');
  }
}
