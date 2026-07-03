import 'package:intl/intl.dart';

final _currencyFormatter = NumberFormat.currency(
  locale: 'pt_BR',
  symbol: 'R\$',
);

final _monthFormatter = DateFormat('MMMM yyyy', 'pt_BR');
final _dateFormatter = DateFormat('dd/MM/yyyy', 'pt_BR');

String formatCurrency(double value) => _currencyFormatter.format(value);

String formatMonth(DateTime date) => _monthFormatter.format(date);

String formatDate(DateTime date) => _dateFormatter.format(date);