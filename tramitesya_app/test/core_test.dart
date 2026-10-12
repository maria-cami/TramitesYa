import 'package:flutter_test/flutter_test.dart';
import 'package:tramitesya_app/core/format.dart';
import 'package:tramitesya_app/core/validators.dart';

void main() {
  group('Validators.password (HU01)', () {
    test('rechaza contraseñas que no cumplen la política', () {
      expect(Validators.password(''), isNotNull);
      expect(Validators.password('Ab1'), isNotNull); // muy corta
      expect(Validators.password('abcdefg1'), isNotNull); // sin mayúscula
      expect(Validators.password('Abcdefgh'), isNotNull); // sin número
    });

    test('acepta una contraseña válida', () {
      expect(Validators.password('Abcdefg1'), isNull);
    });
  });

  group('Validators.email / telefono', () {
    test('email', () {
      expect(Validators.email('camila@correo.com'), isNull);
      expect(Validators.email('camila@'), isNotNull);
      expect(Validators.email(''), isNotNull);
    });

    test('teléfono', () {
      expect(Validators.telefono('+57 300 123 4567'), isNull);
      expect(Validators.telefono('3001234567'), isNull);
      expect(Validators.telefono('123'), isNotNull);
    });
  });

  group('Validators.largo (HU10)', () {
    test('descripción entre 10 y 500 caracteres', () {
      String? v(String? t) => Validators.largo(t, campo: 'La descripción', min: 10, max: 500);
      expect(v(''), isNotNull);
      expect(v('corta'), isNotNull);
      expect(v('Recoger unos medicamentos'), isNull);
      expect(v('a' * 501), isNotNull);
    });

    test('campo opcional vacío es válido', () {
      expect(Validators.largo('', campo: 'Las notas', max: 300, obligatorio: false), isNull);
    });
  });

  group('formatCop / formatFecha', () {
    test('agrupa miles con punto', () {
      expect(formatCop(0), r'$0');
      expect(formatCop(950), r'$950');
      expect(formatCop(18500), r'$18.500');
      expect(formatCop(1250000), r'$1.250.000');
    });

    test('formatFecha usa horario de 12 horas', () {
      expect(formatFecha(DateTime(2026, 10, 11, 16, 47)), '11 oct 2026, 4:47 p. m.');
      expect(formatFecha(DateTime(2026, 1, 5, 0, 5)), '5 ene 2026, 12:05 a. m.');
    });
  });
}
