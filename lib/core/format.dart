/// Formato de moneda COP: 18500 -> $18.500
String formatCop(num valor) {
  final entero = valor.abs().round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < entero.length; i++) {
    if (i > 0 && (entero.length - i) % 3 == 0) buf.write('.');
    buf.write(entero[i]);
  }
  return '${valor < 0 ? '-' : ''}\$${buf.toString()}';
}

const _meses = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

/// 11 oct 2026, 4:47 p. m.
String formatFecha(DateTime fecha) {
  final l = fecha.toLocal();
  final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
  final m = l.minute.toString().padLeft(2, '0');
  final sufijo = l.hour >= 12 ? 'p. m.' : 'a. m.';
  return '${l.day} ${_meses[l.month - 1]} ${l.year}, $h:$m $sufijo';
}

/// Excepción con mensaje apto para mostrar al usuario.
class AppException implements Exception {
  AppException(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}
