import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _inrFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static final NumberFormat _inrCompactFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  /// Formats amount to Indian currency format, e.g. ₹3,400.00
  static String format(double amount, {bool showDecimals = true}) {
    if (showDecimals) {
      return _inrFormatter.format(amount);
    }
    return _inrCompactFormatter.format(amount);
  }

  /// Formats number without symbol, e.g. 3,400.00
  static String formatNumber(double amount, {bool showDecimals = true}) {
    if (showDecimals) {
      return NumberFormat('#,##,##0.00', 'en_IN').format(amount);
    }
    return NumberFormat('#,##,##0', 'en_IN').format(amount);
  }
}
