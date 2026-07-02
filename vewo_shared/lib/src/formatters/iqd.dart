import 'package:intl/intl.dart';

class IQDFormatter {
  // المطلوب في التطبيق: فواصل 5,000,000 (أرقام لاتينية).
  static final _formatter = NumberFormat.decimalPattern('en');

  static String format(num value) {
    final v = value.round();
    return '${_formatter.format(v)} د.ع';
  }
}

