import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/config/company_config.dart';
import '../../models/customer.dart';

class CustomerRepository {
  CollectionReference<Map<String, dynamic>> get _collection =>
      CompanyConfig.customersCollection();

  Future<List<Customer>> getAllCustomers({String? searchQuery}) async {
    try {
      final snapshot = await _collection.orderBy('name').get();
      final customers = snapshot.docs
          .map((doc) => Customer.fromFirestore(doc))
          .toList();

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final query = searchQuery.trim().toLowerCase();
        return customers.where((c) {
          final nameMatch = c.name.toLowerCase().contains(query);
          final phoneMatch = c.phone.toLowerCase().contains(query);
          final addressMatch = c.address.toLowerCase().contains(query);
          final gstMatch = (c.gstNumber ?? '').toLowerCase().contains(query);
          return nameMatch || phoneMatch || addressMatch || gstMatch;
        }).toList();
      }

      return customers;
    } catch (e) {
      // In case of error (e.g. initial offline with empty cache), return empty list or rethrow
      return [];
    }
  }

  Future<Customer?> getCustomerById(String id) async {
    try {
      final doc = await _collection.doc(id).get();
      if (!doc.exists) return null;
      return Customer.fromFirestore(doc);
    } catch (e) {
      return null;
    }
  }

  Future<Customer> saveCustomer(Customer customer) async {
    await _collection.doc(customer.id).set(
      customer.toFirestore(),
      SetOptions(merge: true),
    );
    return customer;
  }

  Future<void> updateCustomer(Customer customer) async {
    await _collection.doc(customer.id).set(
      customer.toFirestore(),
      SetOptions(merge: true),
    );
  }

  Future<void> deleteCustomer(String id) async {
    await _collection.doc(id).delete();
  }

  Future<void> deleteAllCustomers() async {
    final snapshot = await _collection.get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
