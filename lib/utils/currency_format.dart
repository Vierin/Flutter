/// Форматирование сумм во вьетнамских донгах (VND) с сокращениями: тысячи → k, миллионы → M.
String formatVnd(double? value) {
  if (value == null || value.isNaN) return '—';
  final v = value.abs();
  if (v >= 1000000) {
    final n = v / 1000000;
    final s = n == n.truncateToDouble() ? n.toStringAsFixed(0) : n.toStringAsFixed(1);
    return '${s}M ₫';
  }
  if (v >= 1000) {
    final n = v / 1000;
    final s = n == n.truncateToDouble() ? n.toStringAsFixed(0) : n.toStringAsFixed(1);
    return '${s}k ₫';
  }
  return '${v.toStringAsFixed(0)} ₫';
}
