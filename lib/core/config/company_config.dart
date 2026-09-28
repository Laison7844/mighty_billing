import 'package:cloud_firestore/cloud_firestore.dart';

class CompanyConfig {
  static const String defaultCompanyId = 'mighty';
  static String companyId = defaultCompanyId;

  static DocumentReference<Map<String, dynamic>> companyDoc([FirebaseFirestore? firestore]) {
    final fs = firestore ?? FirebaseFirestore.instance;
    return fs.collection('companies').doc(companyId);
  }

  static CollectionReference<Map<String, dynamic>> customersCollection([FirebaseFirestore? firestore]) {
    return companyDoc(firestore).collection('customers');
  }

  static CollectionReference<Map<String, dynamic>> productsCollection([FirebaseFirestore? firestore]) {
    return companyDoc(firestore).collection('products');
  }

  static CollectionReference<Map<String, dynamic>> invoicesCollection([FirebaseFirestore? firestore]) {
    return companyDoc(firestore).collection('invoices');
  }

  static DocumentReference<Map<String, dynamic>> settingsDoc([FirebaseFirestore? firestore]) {
    return companyDoc(firestore).collection('settings').doc('company');
  }

  static DocumentReference<Map<String, dynamic>> invoiceCounterDoc([FirebaseFirestore? firestore]) {
    return companyDoc(firestore).collection('counters').doc('invoice');
  }
}
