import 'package:intl/intl.dart';

class IQDFormatter {
  static final _formatter = NumberFormat.decimalPattern('ar');

  static String format(num value) {
    final v = value.round();
    return '${_formatter.format(v)} د.ع';
  }
}

