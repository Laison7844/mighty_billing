import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
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
        } else {
          // If no products in local database, check if Firestore has products
          final snapshot = await productCollection.limit(1).get();
          if (snapshot.docs.isEmpty) {
            // Seed default catalog
            final now = DateTime.now();
            const uuid = Uuid();
            final defaultProducts = [
              Product(id: uuid.v4(), name: '4 inch Block', unit: 'Nos', defaultRate: 34.0, createdAt: now, updatedAt: now),
              Product(id: uuid.v4(), name: '6 inch Block', unit: 'Nos', defaultRate: 42.0, createdAt: now, updatedAt: now),
              Product(id: uuid.v4(), name: '8 inch Block', unit: 'Nos', defaultRate: 48.0, createdAt: now, updatedAt: now),
              Product(id: uuid.v4(), name: 'Solid Concrete Block', unit: 'Nos', defaultRate: 38.0, createdAt: now, updatedAt: now),
              Product(id: uuid.v4(), name: 'Concrete Paver Block', unit: 'Sq.Ft', defaultRate: 55.0, createdAt: now, updatedAt: now),
              Product(id: uuid.v4(), name: 'Fly Ash Brick', unit: 'Nos', defaultRate: 8.5, createdAt: now, updatedAt: now),
            ];
            final batch = FirebaseFirestore.instance.batch();
            for (final p in defaultProducts) {
              batch.set(productCollection.doc(p.id), p.toFirestore());
            }
            await batch.commit();
            debugPrint('[Migration] Seeded default products to Firestore.');
          }
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
}
