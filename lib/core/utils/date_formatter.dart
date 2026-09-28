import 'package:intl/intl.dart';

class DateFormatter {
  static final DateFormat _invoiceDateFormat = DateFormat('dd MMM yyyy');
  static final DateFormat _shortDateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _timeFormat = DateFormat('hh:mm a');

  static String formatInvoiceDate(DateTime date) {
    return _invoiceDateFormat.format(date);
  }

  static String formatShortDate(DateTime date) {
    return _shortDateFormat.format(date);
  }

  static String formatDateTime(DateTime date) {
    return '${_invoiceDateFormat.format(date)}, ${_timeFormat.format(date)}';
  }
}
