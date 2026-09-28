import 'package:flutter_test/flutter_test.dart';
import 'package:billing/core/utils/currency_formatter.dart';
import 'package:billing/core/utils/financial_year_util.dart';
import 'package:billing/models/customer.dart';
import 'package:billing/models/product.dart';
import 'package:billing/models/invoice.dart';
import 'package:billing/models/invoice_item.dart';
import 'package:billing/models/additional_charge.dart';
import 'package:billing/models/company_settings.dart';
import 'package:billing/services/pdf/invoice_pdf_generator.dart';

void main() {
  group('FinancialYearUtil Tests', () {
    test('Calculates Indian financial year correctly for different months', () {
      final sep2026 = DateTime(2026, 9, 26);
      expect(FinancialYearUtil.getFinancialYear(sep2026), '26-27');

      final apr2026 = DateTime(2026, 4, 1);
      expect(FinancialYearUtil.getFinancialYear(apr2026), '26-27');

      final mar2027 = DateTime(2027, 3, 31);
      expect(FinancialYearUtil.getFinancialYear(mar2027), '26-27');

      final apr2027 = DateTime(2027, 4, 1);
      expect(FinancialYearUtil.getFinancialYear(apr2027), '27-28');
    });

    test('Formats invoice number correctly with 4-digit padding', () {
      final invNum = FinancialYearUtil.formatInvoiceNumber(
        prefix: 'INV',
        financialYear: '26-27',
        sequenceNumber: 37,
      );
      expect(invNum, 'INV/26-27/0037');

      final invNum1 = FinancialYearUtil.formatInvoiceNumber(
        prefix: 'MIGHTY',
        financialYear: '26-27',
        sequenceNumber: 1,
      );
      expect(invNum1, 'MIGHTY/26-27/0001');
    });
  });

  group('CurrencyFormatter Tests', () {
    test('Formats Indian Rupees with symbol and decimals', () {
      final formatted = CurrencyFormatter.format(3400.0);
      expect(formatted.contains('3,400'), isTrue);
      expect(formatted.contains('₹'), isTrue);
    });

    test('Formats large amounts with Indian comma groupings', () {
      final formatted = CurrencyFormatter.format(125000.0);
      expect(formatted.contains('1,25,000'), isTrue);
    });
  });

  group('Customer Model & GST Tests', () {
    test('Customer can be created with and without optional GST number', () {
      final now = DateTime.now();
      final customerWithoutGst = Customer(
        id: 'cust-1',
        name: 'Ringle',
        phone: '98470 12345',
        address: 'Trivandrum',
        createdAt: now,
        updatedAt: now,
      );

      expect(customerWithoutGst.gstNumber, isNull);

      final customerWithGst = Customer(
        id: 'cust-2',
        name: 'John Masonry',
        phone: '94471 56789',
        address: 'Kochi',
        gstNumber: '32ABCDE1234F1Z5',
        createdAt: now,
        updatedAt: now,
      );

      expect(customerWithGst.gstNumber, '32ABCDE1234F1Z5');

      final map = customerWithGst.toMap();
      expect(map['gstNumber'], '32ABCDE1234F1Z5');

      final recreated = Customer.fromMap(map);
      expect(recreated.gstNumber, '32ABCDE1234F1Z5');
      expect(recreated.name, 'John Masonry');
    });
  });

  group('Product Model Tests', () {
    test('Product serializes and deserializes correctly', () {
      final now = DateTime.now();
      final product = Product(
        id: 'prod-1',
        name: '6 inch Block',
        unit: 'Nos',
        defaultRate: 42.0,
        createdAt: now,
        updatedAt: now,
      );

      final map = product.toMap();
      expect(map['name'], '6 inch Block');
      expect(map['defaultRate'], 42.0);

      final recreated = Product.fromMap(map);
      expect(recreated.id, 'prod-1');
      expect(recreated.defaultRate, 42.0);
    });
  });

  group('Invoice Model & Status Tests', () {
    final sampleItems = [
      const InvoiceItem(
        productId: 'prod-1',
        productNameSnapshot: '4 inch Block',
        quantity: 100,
        unit: 'Nos',
        rate: 34,
        amount: 3400,
      ),
    ];

    final sampleCharges = [
      const AdditionalCharge(name: 'Vehicle Charge', amount: 300),
      const AdditionalCharge(name: 'Loading Charge', amount: 200),
    ];

    test('PaymentStatus is UNPAID when paid is 0', () {
      final invoice = Invoice(
        id: 'test-1',
        invoiceNumber: 'INV/26-27/0037',
        customerNameSnapshot: 'Ringle',
        customerPhoneSnapshot: '98470 12345',
        customerAddressSnapshot: 'Green Valley Site',
        customerGstNumberSnapshot: '32ABCDE1234F1Z5',
        date: DateTime(2026, 9, 26),
        items: sampleItems,
        additionalCharges: sampleCharges,
        subtotal: 3400,
        total: 3900,
        paidAmount: 0,
        balanceDue: 3900,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(invoice.paymentStatus, PaymentStatus.unpaid);
      expect(invoice.additionalChargesTotal, 500);
      expect(invoice.total, 3900);
      expect(invoice.balanceDue, 3900);
      expect(invoice.customerGstNumberSnapshot, '32ABCDE1234F1Z5');
    });

    test('Invoice preserves GST snapshot independently of customer changes', () {
      final originalInvoice = Invoice(
        id: 'test-snap',
        invoiceNumber: 'INV/26-27/0038',
        customerId: 'cust-1',
        customerNameSnapshot: 'Ringle',
        customerPhoneSnapshot: '98470 12345',
        customerAddressSnapshot: 'Trivandrum',
        customerGstNumberSnapshot: '32ABCDE1234F1Z5',
        date: DateTime(2026, 9, 26),
        items: sampleItems,
        additionalCharges: [],
        subtotal: 3400,
        total: 3400,
        paidAmount: 3400,
        balanceDue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Even if customer changes their GST number later, the invoice snapshot remains constant
      const updatedCustomerGst = '32XXXXX9999X1Z1';
      expect(originalInvoice.customerGstNumberSnapshot, '32ABCDE1234F1Z5');
      expect(originalInvoice.customerGstNumberSnapshot != updatedCustomerGst, isTrue);
    });

    test('PaymentStatus is PARTIALLY PAID when partially paid', () {
      final invoice = Invoice(
        id: 'test-2',
        invoiceNumber: 'INV/26-27/0038',
        customerNameSnapshot: 'John',
        date: DateTime(2026, 9, 26),
        items: sampleItems,
        additionalCharges: sampleCharges,
        subtotal: 3400,
        total: 3900,
        paidAmount: 1500,
        balanceDue: 2400,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(invoice.paymentStatus, PaymentStatus.partiallyPaid);
    });

    test('PaymentStatus is PAID when fully paid', () {
      final invoice = Invoice(
        id: 'test-3',
        invoiceNumber: 'INV/26-27/0039',
        customerNameSnapshot: 'John',
        date: DateTime(2026, 9, 26),
        items: sampleItems,
        additionalCharges: sampleCharges,
        subtotal: 3400,
        total: 3900,
        paidAmount: 3900,
        balanceDue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(invoice.paymentStatus, PaymentStatus.paid);
    });

    test('PDF Generator produces valid PDF with customer GST snapshot', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final invoice = Invoice(
        id: 'test-pdf',
        invoiceNumber: 'INV/26-27/0037',
        customerNameSnapshot: 'Ringle',
        customerPhoneSnapshot: '98470 12345',
        customerAddressSnapshot: 'Green Valley Site, Plot #12',
        customerGstNumberSnapshot: '32ABCDE1234F1Z5',
        date: DateTime(2026, 9, 26),
        items: sampleItems,
        additionalCharges: sampleCharges,
        subtotal: 3400,
        total: 3900,
        paidAmount: 0,
        balanceDue: 3900,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      const settings = CompanySettings(
        companyName: 'MIGHTY',
        companySubtitle: 'HOLLOW BLOCKS & INTERLOCKS',
        phone: '+91 98765 43210',
      );

      final pdfBytes = await InvoicePdfGenerator.generateInvoicePdf(
        invoice: invoice,
        settings: settings,
      );

      expect(pdfBytes.isNotEmpty, isTrue);
      // PDF documents start with '%PDF'
      final header = String.fromCharCodes(pdfBytes.sublist(0, 4));
      expect(header, '%PDF');
    });

    test('PDF Generator produces valid PDF without customer GST snapshot (omits GST row)', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final invoice = Invoice(
        id: 'test-pdf-no-gst',
        invoiceNumber: 'INV/26-27/0038',
        customerNameSnapshot: 'Ringle',
        customerPhoneSnapshot: '98470 12345',
        customerAddressSnapshot: 'Trivandrum',
        customerGstNumberSnapshot: null,
        date: DateTime(2026, 9, 26),
        items: sampleItems,
        additionalCharges: [],
        subtotal: 3400,
        total: 3400,
        paidAmount: 3400,
        balanceDue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      const settings = CompanySettings(
        companyName: 'MIGHTY',
        phone: '+91 98765 43210',
      );

      final pdfBytes = await InvoicePdfGenerator.generateInvoicePdf(
        invoice: invoice,
        settings: settings,
      );

      expect(pdfBytes.isNotEmpty, isTrue);
      final header = String.fromCharCodes(pdfBytes.sublist(0, 4));
      expect(header, '%PDF');
    });
  });
}
