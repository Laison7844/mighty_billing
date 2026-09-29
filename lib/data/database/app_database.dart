import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  AppDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('mighty_billing.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    // If running on desktop platforms (macOS/Windows/Linux), initialize FFI
    if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String path;
    if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
      final appDocDir = await getApplicationDocumentsDirectory();
      path = join(appDocDir.path, 'MightyBilling', filePath);
      final dir = Directory(dirname(path));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    } else {
      final dbPath = await getDatabasesPath();
      path = join(dbPath, filePath);
    }

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onOpen: (db) async {
        // Automatically purge any lingering demo test customers
        await db.delete(
          'customers',
          where: "phone IN ('98470 12345', '94471 56789') OR name IN ('Ringle', 'John')",
        );
        // Automatically purge any lingering demo test products
        await db.delete(
          'products',
          where: "name IN ('4 inch Block', '6 inch Block', '8 inch Block', 'Solid Concrete Block', 'Concrete Paver Block', 'Fly Ash Brick')",
        );
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        address TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        unit TEXT NOT NULL,
        defaultRate REAL NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE invoices (
        id TEXT PRIMARY KEY,
        invoiceNumber TEXT UNIQUE NOT NULL,
        customerId TEXT,
        customerNameSnapshot TEXT NOT NULL,
        customerPhoneSnapshot TEXT,
        customerAddressSnapshot TEXT,
        date TEXT NOT NULL,
        itemsJson TEXT NOT NULL,
        chargesJson TEXT NOT NULL,
        subtotal REAL NOT NULL,
        total REAL NOT NULL,
        paidAmount REAL NOT NULL,
        balanceDue REAL NOT NULL,
        notes TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
