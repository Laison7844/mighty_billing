class FinancialYearUtil {
  /// Returns financial year string, e.g. "26-27" for date between April 2026 and March 2027
  static String getFinancialYear([DateTime? date]) {
    final d = date ?? DateTime.now();
    int startYear;
    int endYear;

    if (d.month >= 4) {
      startYear = d.year;
      endYear = d.year + 1;
    } else {
      startYear = d.year - 1;
      endYear = d.year;
    }

    final startSuffix = (startYear % 100).toString().padLeft(2, '0');
    final endSuffix = (endYear % 100).toString().padLeft(2, '0');

    return '$startSuffix-$endSuffix';
  }

  /// Generates a standardized invoice number, e.g. "INV/26-27/0001"
  static String formatInvoiceNumber({
    required String prefix,
    required String financialYear,
    required int sequenceNumber,
  }) {
    final cleanPrefix = prefix.trim().toUpperCase();
    final paddedSeq = sequenceNumber.toString().padLeft(4, '0');
    return '$cleanPrefix/$financialYear/$paddedSeq';
  }
}
