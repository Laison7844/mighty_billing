import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/company_config.dart';
import '../../core/utils/financial_year_util.dart';
import '../../data/database/app_database.dart';
import '../../models/company_settings.dart';
import '../../models/customer.dart';
import '../../models/invoice.dart';
import '../../models/product.dart';

class FirebaseMigrationService {
  static const String _kMigrationCompletedKey = 'firebaseMigrationCompleted';

  static Future<void> migrateIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isCompleted = prefs.getBool(_kMigrationCompletedKey) ?? false;
      if (isCompleted) {
        debugPrint('[Migration] Firebase migration already completed.');
        return;
      }

      debugPrint('[Migration] Starting local SQLite to Firestore migration...');

      // 1. Read existing local SQLite database
      final db = await AppDatabase.instance.database;

      // 2. Migrate Customers
      try {
        final localCustomersRaw = await db.query('customers');
        final customerCollection = CompanyConfig.customersCollection();
        final batch = FirebaseFirestore.instance.batch();

        for (final row in localCustomersRaw) {
          final customer = Customer.fromMap(row);
          final docRef = customerCollection.doc(customer.id);
          batch.set(docRef, customer.toFirestore(), SetOptions(merge: true));
        }
        if (localCustomersRaw.isNotEmpty) {
          await batch.commit();
          debugPrint('[Migration] Migrated ${localCustomersRaw.length} customers to Firestore.');
        }
      } catch (e) {
        debugPrint('[Migration] Error migrating customers: $e');
      }

      // 3. Migrate Products
      try {
        final localProductsRaw = await db.query('products');
        final productCollection = CompanyConfig.productsCollection();

        if (localProductsRaw.isNotEmpty) {
          final batch = FirebaseFirestore.instance.batch();
          for (final row in localProductsRaw) {
            final product = Product.fromMap(row);
            final docRef = productCollection.doc(product.id);
            batch.set(docRef, product.toFirestore(), SetOptions(merge: true));
          }
          await batch.commit();
          debugPrint('[Migration] Migrated ${localProductsRaw.length} products to Firestore.');
        }
      } catch (e) {
        debugPrint('[Migration] Error migrating products: $e');
      }

      // 4. Migrate Invoices & determine counter
      try {
        final localInvoicesRaw = await db.query('invoices');
        final invoiceCollection = CompanyConfig.invoicesCollection();
        int maxSequence = 0;
        final currentFy = FinancialYearUtil.getFinancialYear();

        if (localInvoicesRaw.isNotEmpty) {
          final batch = FirebaseFirestore.instance.batch();
          for (final row in localInvoicesRaw) {
            final invoice = Invoice.fromMap(row);
            final docRef = invoiceCollection.doc(invoice.id);
            batch.set(docRef, invoice.toFirestore(), SetOptions(merge: true));

            // Track highest sequence
            final parts = invoice.invoiceNumber.split('/');
            if (parts.length >= 3) {
              final fy = parts[1];
              if (fy == currentFy) {
                final seq = int.tryParse(parts.last) ?? 0;
                if (seq > maxSequence) maxSequence = seq;
              }
            }
          }
          await batch.commit();
          debugPrint('[Migration] Migrated ${localInvoicesRaw.length} invoices to Firestore.');
        }

        // Initialize or update invoice counter in Firestore
        final counterDoc = CompanyConfig.invoiceCounterDoc();
        final counterSnap = await counterDoc.get();
        if (!counterSnap.exists && maxSequence > 0) {
          await counterDoc.set({
            'currentNumber': maxSequence,
            'financialYear': currentFy,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (e) {
        debugPrint('[Migration] Error migrating invoices: $e');
      }

      // 5. Migrate Company Settings to Firestore
      try {
        final settingsDoc = CompanyConfig.settingsDoc();
        final settingsSnap = await settingsDoc.get();
        if (!settingsSnap.exists) {
          const defaultSettings = CompanySettings();
          await settingsDoc.set(defaultSettings.toFirestore());
        }
      } catch (e) {
        debugPrint('[Migration] Error migrating company settings: $e');
      }

      // 6. Mark migration as completed
      await prefs.setBool(_kMigrationCompletedKey, true);
      debugPrint('[Migration] Local SQLite to Firestore migration completed successfully.');
    } catch (e) {
      debugPrint('[Migration] Migration failed with error: $e');
    }
  }

  /// Permanently removes demo/seed test data (masonry catalog and sample customers)
  /// from both local SQLite and Firestore.
  static Future<void> purgeTestData() async {
    try {
      debugPrint('[Cleanup] Purging demo/seed test data...');

      // 1. Purge from local SQLite
      try {
        final db = await AppDatabase.instance.database;
        await db.delete(
          'customers',
          where: "phone IN ('98470 12345', '94471 56789') OR name IN ('Ringle', 'John')",
        );
        await db.delete(
          'products',
          where: "name IN ('4 inch Block', '6 inch Block', '8 inch Block', 'Solid Concrete Block', 'Concrete Paver Block', 'Fly Ash Brick')",
        );
      } catch (e) {
        debugPrint('[Cleanup] Local SQLite cleanup note: $e');
      }

      // 2. Purge test products from Firestore
      try {
        final productCollection = CompanyConfig.productsCollection();
        const testProductNames = {
          '4 inch Block',
          '6 inch Block',
          '8 inch Block',
          'Solid Concrete Block',
          'Concrete Paver Block',
          'Fly Ash Brick',
        };
        final snapshot = await productCollection.get();
        final batch = FirebaseFirestore.instance.batch();
        int deletedProducts = 0;
        for (final doc in snapshot.docs) {
          final data = doc.data();
          if (testProductNames.contains(data['name'])) {
            batch.delete(doc.reference);
            deletedProducts++;
          }
        }
        if (deletedProducts > 0) {
          await batch.commit();
          debugPrint('[Cleanup] Purged $deletedProducts test products from Firestore.');
        }
      } catch (e) {
        debugPrint('[Cleanup] Firestore product cleanup note: $e');
      }

      // 3. Purge test customers from Firestore
      try {
        final customerCollection = CompanyConfig.customersCollection();
        const testCustomerPhones = {'98470 12345', '94471 56789'};
        const testCustomerNames = {'Ringle', 'John'};
        final snapshot = await customerCollection.get();
        final batch = FirebaseFirestore.instance.batch();
        int deletedCustomers = 0;
        for (final doc in snapshot.docs) {
          final data = doc.data();
          if (testCustomerPhones.contains(data['phone']) ||
              testCustomerNames.contains(data['name'])) {
            batch.delete(doc.reference);
            deletedCustomers++;
          }
        }
        if (deletedCustomers > 0) {
          await batch.commit();
          debugPrint('[Cleanup] Purged $deletedCustomers test customers from Firestore.');
        }
      } catch (e) {
        debugPrint('[Cleanup] Firestore customer cleanup note: $e');
      }
    } catch (e) {
      debugPrint('[Cleanup] Purge test data error: $e');
    }
  }
}
