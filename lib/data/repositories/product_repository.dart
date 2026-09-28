import 'package:sqflite/sqflite.dart';
import '../../models/product.dart';
import '../database/app_database.dart';

class ProductRepository {
  final AppDatabase dbProvider;

  ProductRepository({AppDatabase? dbProvider})
      : dbProvider = dbProvider ?? AppDatabase.instance;

  Future<List<Product>> getAllProducts({String? searchQuery}) async {
    final db = await dbProvider.database;
    List<Map<String, dynamic>> results;

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final query = '%${searchQuery.trim()}%';
      results = await db.query(
        'products',
        where: 'name LIKE ? OR unit LIKE ?',
        whereArgs: [query, query],
        orderBy: 'name ASC',
      );
    } else {
      results = await db.query('products', orderBy: 'name ASC');
    }

    return results.map((map) => Product.fromMap(map)).toList();
  }

  Future<Product?> getProductById(String id) async {
    final db = await dbProvider.database;
    final results = await db.query('products', where: 'id = ?', whereArgs: [id]);
    if (results.isEmpty) return null;
    return Product.fromMap(results.first);
  }

  Future<Product> saveProduct(Product product) async {
    final db = await dbProvider.database;
    await db.insert(
      'products',
      product.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return product;
  }

  Future<void> updateProduct(Product product) async {
    final db = await dbProvider.database;
    await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<void> deleteProduct(String id) async {
    final db = await dbProvider.database;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }
}
