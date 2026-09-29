import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/config/company_config.dart';
import '../../models/product.dart';
import '../database/app_database.dart';

class ProductRepository {
  CollectionReference<Map<String, dynamic>> get _collection =>
      CompanyConfig.productsCollection();

  Future<List<Product>> getAllProducts({String? searchQuery}) async {
    try {
      final snapshot = await _collection.orderBy('name').get();
      final products = snapshot.docs
          .map((doc) => Product.fromFirestore(doc))
          .toList();

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final query = searchQuery.trim().toLowerCase();
        return products.where((p) {
          final nameMatch = p.name.toLowerCase().contains(query);
          final unitMatch = p.unit.toLowerCase().contains(query);
          return nameMatch || unitMatch;
        }).toList();
      }

      return products;
    } catch (e) {
      return [];
    }
  }

  Future<Product?> getProductById(String id) async {
    try {
      final doc = await _collection.doc(id).get();
      if (!doc.exists) return null;
      return Product.fromFirestore(doc);
    } catch (e) {
      return null;
    }
  }

  Future<Product> saveProduct(Product product) async {
    await _collection.doc(product.id).set(
      product.toFirestore(),
      SetOptions(merge: true),
    );
    return product;
  }

  Future<void> updateProduct(Product product) async {
    await _collection.doc(product.id).set(
      product.toFirestore(),
      SetOptions(merge: true),
    );
  }

  Future<void> deleteProduct(String id) async {
    try {
      final db = await AppDatabase.instance.database;
      await db.delete('products', where: 'id = ?', whereArgs: [id]);
    } catch (_) {}
    await _collection.doc(id).delete();
  }

  Future<void> deleteAllProducts() async {
    try {
      final db = await AppDatabase.instance.database;
      await db.delete('products');
    } catch (_) {}
    final snapshot = await _collection.get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
