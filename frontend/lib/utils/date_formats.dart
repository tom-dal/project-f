import 'package:intl/intl.dart';

// USER PREFERENCE: Centralized date/time formats (Italian style dd/MM/yyyy)
class AppDateFormats {
  static final DateFormat date = DateFormat('dd/MM/yyyy');
  static final DateFormat dateTime = DateFormat('dd/MM/yyyy HH:mm');

  static String formatDate(DateTime? d, {String empty = '-'}) => d == null ? empty : date.format(d);
  static String formatDateTime(DateTime? d, {String empty = '-'}) => d == null ? empty : dateTime.format(d);
}

